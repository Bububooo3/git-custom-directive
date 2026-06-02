--!native
--!optimize 2

-- ============================================================
--  LEXER
-- ============================================================

local TokenType = {
	LONG_OPEN    = "LONG_OPEN",      -- [=[
	LONG_CLOSE   = "LONG_CLOSE",     -- ]=]
	BLOCK_OPEN   = "BLOCK_OPEN",     -- [
	BLOCK_CLOSE  = "BLOCK_CLOSE",    -- ]
	CURLY_OPEN   = "CURLY_OPEN",     -- {
	CURLY_CLOSE  = "CURLY_CLOSE",    -- }
	TAG_OPEN     = "TAG_OPEN",       -- <config> | <files>
	TAG_CLOSE    = "TAG_CLOSE",      -- </config> | </files>
	KEYWORD      = "KEYWORD",        -- git-config | git-push | git-pull
	EQUALS       = "EQUALS",         -- =
	COLON        = "COLON",          -- :
	SEMICOLON    = "SEMICOLON",      -- ;
	STRING       = "STRING",         -- "..."
	IDENT        = "IDENT",          -- bare word / path / placeholder
}

local KEYWORDS = {
	["git-config"] = true,
	["git-push"]   = true,
	["git-pull"]   = true,
}

local function lex(src: string): {{type: string, value: string?}}
	local tokens = {}
	local i = 1
	local len = #src

	local function peek(offset: number?): string
		return src:sub(i + (offset or 0), i + (offset or 0))
	end

	local function consume(n: number?): string
		local s = src:sub(i, i + (n or 1) - 1)
		i += (n or 1)
		return s
	end

	local function emit(t: string, v: string?)
		table.insert(tokens, {type = t, value = v})
	end

	while i <= len do
		-- Strip line comments
		if peek() == "/" and peek(1) == "/" then
			while i <= len and peek() ~= "\n" do
				i += 1
			end
			continue
		end

		-- Long bracket open [=[
		if peek() == "[" and peek(1) == "=" and peek(2) == "[" then
			consume(3)
			emit(TokenType.LONG_OPEN)
			continue
		end

		-- Long bracket close ]=]
		if peek() == "]" and peek(1) == "=" and peek(2) == "]" then
			consume(3)
			emit(TokenType.LONG_CLOSE)
			continue
		end

		-- Quoted string
		if peek() == '"' then
			consume(1) -- opening quote
			local start = i
			while i <= len and peek() ~= '"' do
				if peek() == "\\" then i += 1 end -- skip escaped char
				i += 1
			end
			local value = src:sub(start, i - 1)
			consume(1) -- closing quote
			emit(TokenType.STRING, value)
			continue
		end

		-- XML-style tags <config> </config> <files> </files>
		if peek() == "<" then
			local j = i + 1
			while j <= len and src:sub(j, j) ~= ">" do
				j += 1
			end
			local inner = src:sub(i + 1, j - 1) -- contents between < >
			i = j + 1

			local isClose = inner:sub(1, 1) == "/"
			local tagName = isClose and inner:sub(2) or inner
			tagName = tagName:lower():match("^%s*(.-)%s*$") -- trim

			if tagName == "config" or tagName == "files" then
				emit(isClose and TokenType.TAG_CLOSE or TokenType.TAG_OPEN, tagName)
			else
				warn(`(git-parse) Unknown tag: <{inner}>`)
			end
			continue
		end

		-- Single-char tokens
		local ch = peek()
		if ch == "[" then consume(1); emit(TokenType.BLOCK_OPEN);  continue end
		if ch == "]" then consume(1); emit(TokenType.BLOCK_CLOSE); continue end
		if ch == "{" then consume(1); emit(TokenType.CURLY_OPEN);  continue end
		if ch == "}" then consume(1); emit(TokenType.CURLY_CLOSE); continue end
		if ch == "=" then consume(1); emit(TokenType.EQUALS);      continue end
		if ch == ":" then consume(1); emit(TokenType.COLON);       continue end
		if ch == ";" then consume(1); emit(TokenType.SEMICOLON);   continue end

		-- Whitespace
		if ch == " " or ch == "\t" or ch == "\n" or ch == "\r" then
			i += 1
			continue
		end

		-- Bare identifier / keyword / placeholder
		local start = i
		while i <= len do
			local c = src:sub(i, i)
			if c == " " or c == "\t" or c == "\n" or c == "\r"
				or c == "=" or c == ":" or c == ";"
				or c == "{" or c == "}" or c == "[" or c == "]"
				or c == "<" or c == ">" or c == '"' or c == "/"
			then
				break
			end
			i += 1
		end
		local word = src:sub(start, i - 1)

		if KEYWORDS[word] then
			emit(TokenType.KEYWORD, word)
		else
			emit(TokenType.IDENT, word)
		end
	end

	return tokens
end

-- ============================================================
--  PARSER
-- ============================================================

local CONFIG_KEYS = {
	["token"]          = "token",
	["repository"]     = "repository",
	["path"]           = "path",
	["branch"]         = "branch",
	["commit-message"] = "message",
	["base"]           = "base",
}

local FILE_KEYS = {
	["token"]          = "token",
	["repository"]     = "repository",
	["path"]           = "path",
	["branch"]         = "branch",
	["commit-message"] = "message",
	["name"]           = "name",
}

-- Returns nil if value is a placeholder [WORD]
local function resolveValue(token: {type: string, value: string?}): string?
	if token.type == TokenType.STRING then
		return token.value
	end
	-- IDENT: check for placeholder pattern [WORD]
	local v = token.value or ""
	if v:match("^%[.+%]$") then
		return nil -- placeholder, treat as absent
	end
	return v
end

local function parse(tokens: {{type: string, value: string?}})
	local i = 1
	local len = #tokens

	local result = {
		config = {},
		push   = { config = {}, files = {} },
		pull   = { config = {}, files = {} },
	}

	local function peek(offset: number?): {type: string, value: string?}?
		return tokens[i + (offset or 0)]
	end

	local function consume(): {type: string, value: string?}?
		local t = tokens[i]
		i += 1
		return t
	end

	local function expect(ttype: string, context: string): {type: string, value: string?}?
		local t = peek()
		if not t or t.type ~= ttype then
			warn(`(git-parse) Expected {ttype} {context}, got {t and t.type or "EOF"} ("{t and t.value or ""}")`)
			return nil
		end
		return consume()
	end

	-- Consume an optional semicolon
	local function eatSemicolon()
        local e = peek()

		if e and e.type == TokenType.SEMICOLON then
			consume()
		end
	end

	-- Parse a key: value; pair into a target table using a key map
	local function parseKV(target: {}, keyMap: {[string]: string}, directiveName: string)
		local keyToken = consume() -- already consumed the key IDENT outside
		local key = keyToken and keyToken.value or ""

		if not expect(TokenType.COLON, `after key "{key}"`) then return end

		local valToken = peek()
		if not valToken or (valToken.type ~= TokenType.STRING and valToken.type ~= TokenType.IDENT) then
			warn(`(git-parse) Missing value for key "{key}" in {directiveName}`)
			eatSemicolon()
			return
		end
		consume()

		local mappedKey = keyMap[key]
		if not mappedKey then
			warn(`(git-parse) Unknown key "{key}" in {directiveName}, ignoring`)
			eatSemicolon()
			return
		end

		local value = resolveValue(valToken)
		target[mappedKey] = value

		eatSemicolon()
	end

	-- Parse <config> ... </config> into target config table
	local function parseConfigBlock(target: {}, directiveName: string)
		-- TAG_OPEN "config" already consumed by caller
		while i <= len do
			local t = peek()
			if not t then break end

			if t.type == TokenType.TAG_CLOSE and t.value == "config" then
				consume()
				break
			end

			if t.type == TokenType.IDENT then
				parseKV(target, CONFIG_KEYS, directiveName .. " <config>")
			else
				consume() -- skip unexpected token
			end
		end
	end

	-- Parse a single file entry { ... }; into a table
	local function parseFileEntry(directiveName: string): {}
		-- CURLY_OPEN already consumed by caller
		local entry = {}
		while i <= len do
			local t = peek()
			if not t then break end

			if t.type == TokenType.CURLY_CLOSE then
				consume()
				eatSemicolon()
				break
			end

			if t.type == TokenType.IDENT then
				parseKV(entry, FILE_KEYS, directiveName .. " <files>")
			else
				consume()
			end
		end
		return entry
	end

	-- Parse <files> ... </files>
	local function parseFilesBlock(target: {}, directiveName: string)
		-- TAG_OPEN "files" already consumed by caller
		while i <= len do
			local t = peek()
			if not t then break end

			if t.type == TokenType.TAG_CLOSE and t.value == "files" then
				consume()
				break
			end

			-- Expect: IDENT (file path) : { ... };
			if t.type == TokenType.IDENT then
				local pathToken = consume()
				local filePath = pathToken.value or ""

				if not expect(TokenType.COLON, `after file path "{filePath}"`) then
					-- try to recover
					continue
				end

				if not expect(TokenType.CURLY_OPEN, `opening file entry for "{filePath}"`) then
					continue
				end

				target[filePath] = parseFileEntry(directiveName)
			else
				consume()
			end
		end
	end

	-- Parse a directive body [ <config>? <files>? ];
	local function parseDirectiveBody(directive: string)
		-- BLOCK_OPEN already consumed by caller
		local configTarget, filesTarget, allowFiles

		if directive == "git-config" then
			configTarget = result.config
			allowFiles   = false
		elseif directive == "git-push" then
			configTarget = result.push.config
			filesTarget  = result.push.files
			allowFiles   = true
		elseif directive == "git-pull" then
			configTarget = result.pull.config
			filesTarget  = result.pull.files
			allowFiles   = true
		end

		while i <= len do
			local t = peek()
			if not t then break end

			if t.type == TokenType.BLOCK_CLOSE then
				consume()
				eatSemicolon()
				break
			end

			if t.type == TokenType.TAG_OPEN then
				consume()
				if t.value == "config" then
					parseConfigBlock(configTarget, directive)
				elseif t.value == "files" then
					if allowFiles then
						parseFilesBlock(filesTarget, directive)
					else
						warn(`(git-parse) {directive} does not support <files>, ignoring`)
						-- consume until tag close
						while i <= len do
							local inner = consume()
							if inner and inner.type == TokenType.TAG_CLOSE and inner.value == "files" then break end
						end
					end
				end
				continue
			end

			-- git-config body: allow bare key: value; pairs without a <config> wrapper
			if t.type == TokenType.IDENT and directive == "git-config" then
				parseKV(configTarget, CONFIG_KEYS, directive)
				continue
			end

			consume() -- skip unexpected
		end
	end

	-- Top-level: look for [=[ ... ]=]
	while i <= len do
		local t = peek()
		if not t then break end

		if t.type == TokenType.LONG_OPEN then
			consume()

			-- Inside long block: look for directives
			while i <= len do
				local inner = peek()
				if not inner then break end

				if inner.type == TokenType.LONG_CLOSE then
					consume()
					break
				end

				if inner.type == TokenType.KEYWORD then
					local directive = inner.value
					consume()

					if not expect(TokenType.EQUALS, `after directive "{directive}"`) then
						continue
					end

					if not expect(TokenType.BLOCK_OPEN, `after "=" in directive "{directive}"`) then
						continue
					end

					parseDirectiveBody(directive)
				else
					consume() -- skip non-directive tokens at top level
				end
			end
		else
			consume()
		end
	end

	return result
end

-- ============================================================
--  PUBLIC
-- ============================================================

local Parser = {}

function Parser.parse(src: string)
	local tokens = lex(src)
	return parse(tokens)
end

return Parser