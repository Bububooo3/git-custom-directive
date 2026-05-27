--!native
--!optimize 2
local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local Functions = {}

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
	local firstLine = sourceCode:match("^(.-)\n") --TODO
	local scriptType = firstLine:match("%-%- @ScriptType: (.+)") or "Script"
	local scriptInstance = Instance.new(scriptType)
		
	scriptInstance.Name = myFileData.name:gsub("%.lua$", ""):gsub("%.luau$", "")
	scriptInstance.Name = scriptInstance.Name
	
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
				local sourceCode = Functions.from_base64(contents.content)
				local firstLine = sourceCode:match("^(.-)\n")
				local scriptType = firstLine:match("%-%- @ScriptType: (.+)") or "Script"
				local scriptInstance = Instance.new(scriptType)

				scriptInstance.Name = contents.name:gsub("%.lua$", ""):gsub("%.luau$", "")
				scriptInstance.Name = scriptInstance.Name

				scriptInstance.Source = sourceCode
				scriptInstance.Parent = parent
				Selection:Set({scriptInstance})
			end
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