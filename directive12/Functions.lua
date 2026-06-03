--$MODULE

--!native
--!optimize 2

local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local Functions = {}
local Keywords
repeat
	Keywords = require("./Keywords")
	task.wait()
until Keywords ~= nil

function Functions.getFullNameFormatted(object: Instance, limit: Instance?)
	local result = object.Name
	object = object.Parent or limit

	while object and limit and object ~= limit do
		result = object.Name .. "/" .. result
		object = object.Parent or limit
	end

	return result
end

function Functions.pushScript(object: Instance, headers, url, msg, branch)
	local src: string = object.Source
	local name = object.Name
	local mySHA
	
	-- Get SHA
	local success1, result = pcall(function()
		return HttpService:RequestAsync({
			Url = url..`/{object.Name}.lua?ref={branch}`,
			Method = "GET",
			Headers = headers
		})
	end)

	if success1 and result.Success then
		local temp = HttpService:JSONDecode(result.Body)
		mySHA = temp.sha
	end
	-- End of getting SHA

	-- SHA guard
	if not mySHA then
		warn(`(git-push) Unable to obtain remote SHA for file {object.Name}`)
	end
	-- End of SHA guard

	if not src:find("--$MODULE") or src:find("--$SERVER") or src:find("--$CLIENT") then
		if object:IsA("ModuleScript") then
			src = `--$MODULE\n{src}`

		elseif object:IsA("Script") then
			src = `--$SERVER\n{src}`

		elseif object:IsA("LocalScript") then
			src = `--$CLIENT\n{src}`

		end
	end

	local success4, result4 = pcall(function()
		return HttpService:RequestAsync({
			Url = url..`/{name}.lua`,
			Method = "PUT",
			Headers = headers,
			Body = HttpService:JSONEncode({
				message = msg or ((mySHA) and `Updated {name}` or `Created {name}`),
				content = Functions.to_base64(src),
				branch = branch,
				sha = mySHA
			})
		})
	end)

	if success4 and result4.Success then
		print(`(git-push) Pushed {name} successfully`)
	elseif success4 and not result4.Success then
		warn(`(git-push) Failed to push {name}: ` .. result4.Body)
	elseif not success4 then
		warn(`(git-push) Failed to push {name}: ` .. tostring(result4)) -- result4 is the error message when pcall fails
	end	

	if success4 then
		print(`(git-push) HTTP {result4.StatusCode}: {result4.Body}`)
	end
end

function Functions.pushContainer(parent: Instance, headers, url, msg, branch)
	for _, child in pairs(parent:GetChildren()) do
		print(child)
		
		if child:IsA("BaseScript") then
			Functions.pushScript(child, headers, url, msg, branch)			
		end

		if #child:GetChildren() > 0 then
			local myURL = `{url}/{child.Name}`

			Functions.pushContainer(
				child,
				headers,
				myURL,
				msg,
				branch
			)
		end
	end
end

----> Convert data from base 10 to base 64
function Functions.to_base64(data: any) : string -- (XDeltaXen) - https://devforum.roblox.com/t/base64-encoding-and-decoding-in-lua/1719860
	local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	return ((data:gsub('.', function(x) 
		local r,b='',x:byte()
		for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
		return r;
	end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
		if (#x < 6) then return '' end
		local c=0
		for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
		return b:sub(c+1,c+1)
	end)..({ '', '==', '=' })[#data%3+1])
end

----> Convert data from base 64 to base 10
function Functions.from_base64(data: any) : string -- (XDeltaXen) - https://devforum.roblox.com/t/base64-encoding-and-decoding-in-lua/1719860
	local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	data = string.gsub(data, '[^'..b..'=]', '')
	return (data:gsub('.', function(x)
		if (x == '=') then return '' end
		local r,f='',(b:find(x)-1)
		for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
		return r;
	end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
		if (#x ~= 8) then return '' end
		local c=0
		for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
		return string.char(c)
	end))
end

----> Return the contents of a repository
function Functions.getRepoContents(repository: string, name: string, path: string, headers, branch: string): {} | nil
	local success1, result1 = pcall(function()
		return HttpService:RequestAsync({
			Url = `https://api.github.com/repos/{repository}/contents/{path}?ref={branch}`,
			Method = "GET",
			Headers = headers
		})
	end)

	if success1 and not result1.Success then
		warn(`(git-pull) Failed to fetch repository contents for file {name}: `.. result1.Body)
		return
	elseif not success1 then
		warn(`(git-pull) Failed to fetch repository contents for file {name}: (no data)`)
		return
	end

	return HttpService:JSONDecode(result1.Body)
end

local function stripNoise(source: string): string
	return source
		:gsub('"[^"\n]*"', '""')       -- remove string contents (keep quotes as spacers)
		:gsub("'[^'\n]*'", "''")       -- remove single-quoted string contents
		:gsub("%-%-%[%[.-%]%]", "")    -- remove block comments
		:gsub("%-%-[^\n]*", "")        -- remove line comments
end

local function countKeywords(source: string, keywordTable: {string}, typeIndex: number, types: {number})
	for _, word in ipairs(keywordTable) do
		local gSafeWord = word:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
		local _, count = source:gsub(gSafeWord, "")
		types[typeIndex] += count
	end
end

function Functions.makeFile(myFileData, parent)
	local sourceCode = Functions.from_base64(myFileData.content)
	local scriptInstance
	local types = {0,0,0}
	
	if sourceCode:find("--$MODULE", 1, true) then
		types[3] = math.huge
	elseif sourceCode:find("--$SERVER", 1, true) then
		types[1] = math.huge
	elseif sourceCode:find("--$CLIENT", 1, true) then
		types[2] = math.huge
	else
		local cleaned = stripNoise(sourceCode)
		
		countKeywords(cleaned, Keywords.s, 1, types)
		countKeywords(cleaned, Keywords.c, 2, types)
		countKeywords(cleaned, Keywords.m, 3, types)
	end
	
	local className
	if types[1] > types[2] and types[1] > types[3] then
		className = "Script"
		
	elseif types[2] > types[1] and types[2] > types[3] then
		className = "LocalScript"
		
	elseif types[3] > types[1] and types[3] > types[2] then
		className = "ModuleScript"
		
	else
		className = "ModuleScript"
		warn(`(git-pull) File guessing failed for {myFileData.name}. Falling back to ModuleScript`)
		warn(`(Server: {types[1]} | Client: {types[2]} | Module: {types[3]})`)
	end

	scriptInstance = Instance.new(className)
	scriptInstance.Name = myFileData.name:gsub("%.lua[u]?$", "")
	scriptInstance.Source = sourceCode
	scriptInstance.Parent = parent
	Selection:Set({scriptInstance})
end

function Functions.createStructure(parent: any, repository, name, filePath, headers, branch) : {Folder}
	local new_directories: {Folder} = {}
	local contents = Functions.getRepoContents(repository, name, filePath, headers, branch)

	if not contents then return {} end

	if not contents[1] then -- it's a file
		if contents.type == "file" and (contents.name:match("%.lua$") or contents.name:match("%.luau$")) then
			if contents and contents.content then
				Functions.makeFile(contents, parent)
			else
				warn(`(git-pull) Contents not found for file {name}`)
			end
		else
			-- It's not a lua or luau file
		end
	elseif contents[1] and (contents[1].type == "dir" or contents[1].type == "file") then -- it's a directory
		for _, fileData in pairs(contents) do			
			if fileData.type == "file" and (fileData.name:match("%.lua$") or fileData.name:match("%.luau$")) and fileData and fileData.content then
				Functions.makeFile(fileData, parent)

			elseif fileData.type == "file" and (fileData.name:match("%.lua$") or fileData.name:match("%.luau$")) then
				local fileContents = Functions.getRepoContents(repository, name, fileData.path, headers, branch)

				if fileContents and fileContents.content then
					Functions.makeFile(fileContents, parent)
				end

			elseif fileData.type == "dir" then
				local notService = not(game:FindFirstChild(fileData.name))

				local folder: any

				if notService then
					folder = Instance.new("Folder")
					folder.Name, folder.Parent = fileData.name, parent
					table.insert(new_directories, folder)
				else
					folder = game[fileData.name]
				end

				local add = Functions.createStructure(folder, repository, name, fileData.path, headers, branch)

				for _, v in pairs(add) do
					table.insert(new_directories, v)
				end

				table.clear(add)
			else
				warn(`(git-pull) Invalid file type for file {fileData.name or fileData.path or "(UNKNOWN)"}`)
				continue
			end
		end
	end

	return new_directories
end

return Functions