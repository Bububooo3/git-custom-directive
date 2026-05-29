--!native
--!optimize 2
local HttpService = game:GetService("HttpService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Selection = game:GetService("Selection")
local Functions = {}
local Keywords
repeat
	Keywords = require("./Keywords")
	task.wait()
until Keywords ~= nil

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
				Url = `https://api.github.com/repos/{repository}/contents/{path}/?ref={branch}`,
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

function Functions.makeFile(myFileData, parent)
	local sourceCode = Functions.from_base64(myFileData.content)

	local types = {0, 0, 0} -- s, c, m

	for _, word in Keywords.s do
		local gSafeWord = word:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
		local _, count = string.gsub(sourceCode, gSafeWord, "")
		types[1] += count
	end

	for _, word in Keywords.c do
		local gSafeWord = word:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
		local _, count = string.gsub(sourceCode, gSafeWord, "")
		types[2] += count
	end

	for _, word in Keywords.m do
		local gSafeWord = word:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
		local _, count = string.gsub(sourceCode, gSafeWord, "")
		types[3] += count
	end

	local scriptInstance

	if types[1] > types[2] and types[1] > types[3] then
		scriptInstance = Instance.new("Script")
	elseif types[2] > types[1] and types[2] > types[3] then
		scriptInstance = Instance.new("LocalScript")
	elseif types[3] > types[1] and types[3] > types[2] then
		scriptInstance = Instance.new("ModuleScript")
	elseif types[1] == types[2] then
		warn(`(git-pull) File guessing failed for file {myFileData.name}. Falling back to ClassName: Script`)
		scriptInstance = Instance.new("Script")
	elseif types[2] == types[3] then
		warn(`(git-pull) File guessing failed for file {myFileData.name}. Falling back to ClassName: ModuleScript`)
		scriptInstance = Instance.new("ModuleScript")
	else -- types[3] == types[1]
		warn(`(git-pull) File guessing failed for file {myFileData.name}. Falling back to ClassName: ModuleScript`)
		scriptInstance = Instance.new("ModuleScript")
	end
		
	scriptInstance.Name = myFileData.name:gsub("%.lua$", ""):gsub("%.luau$", "")
	
	scriptInstance.Source = sourceCode
	scriptInstance.Parent = parent
	Selection:Set({scriptInstance})
end

function Functions.createStructure(parent: any, repository, name, filePath, headers, branch) : nil
	local new_directiories: {Folder} = {}
	local contents = Functions.getRepoContents(repository, name, filePath, headers, branch)

	if not contents then return end

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
	elseif contents[1] and contents[1].type == "dir" or contents[1].type == "file" then -- it's a directory
		for _, fileData in pairs(contents) do
			if fileData.type == "file" and (fileData.name:match("%.lua$") or fileData.name:match("%.luau$")) and fileData and fileData.content then
				Functions.makeFile(fileData, parent)

			elseif fileData.type == "dir" then
				local notService = not(game:FindFirstChild(fileData.name))

				local folder: any

				if notService then
					folder = Instance.new("Folder")
					folder.Name, folder.Parent = fileData.name, parent
					table.insert(new_directiories, folder)
				else
					folder = game[fileData.name]
				end
				
				local subContents = Functions.getRepoContents(repository, name, fileData.path, headers, branch)

				if subContents then
					Functions.createStructure(folder, repository, name, fileData.path, headers, branch)
				end
			else
				warn(`(git-pull) Invalid file type for file {name}`)
				return
			end
		end
	end
	
	-- Parent scripts properly after the fact
	for _, folder in pairs(new_directiories) do	
		for _, v in pairs(folder.Parent:GetChildren()) do
			if not(v:IsA("BaseScript")) then continue end
			if v.Name ~= folder.Name then continue end
			
			for _, item in pairs(folder:GetChildren()) do
				item.Parent = v
			end
			
			folder:Destroy()
		end
	end
	
	return
end

return Functions