local HttpService = game:GetService("HttpService")
local Functions = {}

----> Return the contents of a repository
function Functions.getRepoContents(repository, name, path, headers, branch)
	local url = "https://api.github.com/repos/" .. plugin:GetSetting(Gitsync.Settings.REPOSITORY) .. "/contents/" .. (path or "") .."?ref="..plugin:GetSetting(Gitsync.Settings.BRANCH)

	local url = baseURL:format(repository, path)..`?ref={branch}`
	local headers = {
		["Authorization"] = `token {token}`,
		["Accept"] = "application/vnd.github.v3+json"
	}

	local success1, result1 = pcall(function()
			return HttpService:RequestAsync({
				Url = url,
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

function Functions.createStructure(parent: any, contents: any) : nil
	local new_directiories: {Folder} = {}
	
	for _, item in pairs(contents) do
		local notService = not(game:FindFirstChild(item.name))
		if item.type == "dir" then
			if tOE then if notService then print("dir") else print("service") end end

			local folder: any

			if notService then
				folder = Instance.new("Folder")
				folder.Name, folder.Parent = item.name, parent
				table.insert(new_directiories, folder)
			else folder = game[item.name] end

			local subContents = Functions.getRepoContents(item.path)
			if subContents then Functions.createStructure(folder, subContents) end

		elseif item.type == "file" and (item.name:match("%.lua$") or item.name:match("%.luau$")) then

			local fileData = Functions.getRepoContents(item.path)
			if fileData and fileData.content then
				local sourceCode = Functions.from_base64(fileData.content)

				local firstLine = sourceCode:match("^(.-)\n")
				local scriptType = firstLine:match("%-%- @ScriptType: (.+)") or "Script"
				local scriptInstance = Instance.new(scriptType)

				scriptInstance.Name = item.name:gsub("%.lua$", "")
				scriptInstance.Name = scriptInstance.Name:gsub("%.luau$", "")
				scriptInstance.Source = Functions.clipMetadata(sourceCode)
				scriptInstance.Parent = parent
				Selection:Set({scriptInstance})
				if tOE then print("Created new script: " .. scriptInstance.Name .. " (" .. scriptType .. ")") end
			end
		end
	end
	
	-- Put the files in their folders
	for _, folder in pairs(new_directiories) do	
		for _, v in pairs(folder.Parent:GetChildren()) do
			if not(v:IsA("ModuleScript") or v:IsA("Script") or v:IsA("LocalScript")) then continue end
			if v.Name ~= folder.Name then continue end
			
			for _, item in pairs(folder:GetChildren()) do
				item.Parent = v
			end
			
			folder:Destroy()
		end
	end
	
	return
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



return Functions