--!native
--!optimize 2

--[[

    function self:StudioClosedUpdate()
        
        data.UpdateType = "StudioClosed"
        self:UpdateCompiler()
    end
    
    function self:PluginClosedUpdate()
        
        data.UpdateType = "WidgetClosed"
        self:UpdateCompiler()
    end
    
    function self:UserForceUpdate()
        
        data.UpdateType = "ForcedUpdate"
        self:UpdateCompiler()
    end
    
    function self:UserTabUpdate()
        
        data.UpdateType = "TabChange"
        self:UpdateCompiler()
    end

]]


local Types = require("./Types")
local Functions = require("./Functions")

local gitConfigGlobal: Types.GitConfigData = {base='main'}
local baseURL = "https://api.github.com/repos/%s/contents/%s"
local HttpService = game:GetService("HttpService")

local main = {}

function main.gitPush(data: Types.GitDirectiveData)
	-- post parsing

	local gitConfigLocal = data.config

	for path, file in pairs(data.files) do
		local split = path:split(".") -- {game, Workspace, ModelName, PartName, ScriptName}

		local name = file.name or split[#split] -- will have issues if there are periods in the instance names
		local repository = file.repository or gitConfigLocal.repository or gitConfigGlobal.repository or nil
		local token = file.token or gitConfigLocal.token or gitConfigGlobal.token or nil
		local filePath = file.path or gitConfigLocal.path or gitConfigGlobal.path or "" -- path should have no / at start or end when delivered
		local branch = file.branch or gitConfigLocal.branch or gitConfigGlobal.branch or "main"
		local msg = file.message or gitConfigLocal.message or gitConfigGlobal.message or nil

		local url = baseURL:format(repository, filePath)
		local headers = {
			["Authorization"] = `token {token}`,
			["Accept"] = "application/vnd.github.v3+json"
		}

		-- Guards
		local issues = 0
		if not repository then
			warn(`(git-push) No repository specified for file {name}`)
			issues += 1
		end

		if not token then
			warn(`(git-push) No token specified for file {name}`)
			issues += 1
		end

		if issues > 0 then continue end
		-- End of Guards

		-- Find real script instance
		local root = split[1]
		local fileObject

		if root == "game" then
			fileObject = game
			table.remove(split, 1)
		elseif root == "script" then
			fileObject = script
		elseif game:FindFirstChild(root) then
			fileObject = game
		else
			warn(`(git-push) Invalid path for file {name}`)
		end

		for i, t in ipairs(split) do
			fileObject = fileObject[t] or nil
		end

		-- local isContainer = not fileObject:IsA("BaseScript")

		if not fileObject:IsA("Instance") then 
			warn(`(git-push) Invalid class for file {name}`)
			continue
		end
		-- End of finding real script instance or "folder" (container)

		-- Get SHA
		local mySHA = nil

		local success1, result = pcall(function()
			return HttpService:RequestAsync({
				Url = url..`?ref={branch}`,
				Method = "GET",
				Headers = headers
			})
		end)

		if success1 and result.Success then
			local temp = HttpService:JSONDecode(result.Body)
			mySHA = temp.sha
		end
		-- End of getting SHA
		
		-- Getting backup SHA
		-- if not mySHA then
		-- 	warn(`(git-push) Initial attempt to retrieve SHA failed for file {name}`)
		-- 	warn(`(git-push) Attempting to create new branch from base branch for file {name}`)

		-- 	local success2, result2 = pcall(function()
		-- 		return HttpService:RequestAsync({
		-- 			Url = `https://api.github.com/repos/{repository}/git/refs/heads/{gitConfigGlobal.base}`,
		-- 			Method = "GET",
		-- 			Headers = headers
		-- 		})
		-- 	end)

		-- 	if success2 and result2.Success then
		-- 		mySHA = HttpService:JSONDecode(result2.Body).object.sha 
		-- 	else
		-- 		warn(`(git-push) Failed to retrieve base SHA for file {name}`)
		-- 	end

		-- 	local requestBody = HttpService:JSONEncode({
		-- 		ref = `refs/heads/{branch}`,
		-- 		sha = mySHA
		-- 	})
			
		-- 	local success3, result3 = pcall(function()
		-- 		return HttpService:RequestAsync({
		-- 			Url = `https://api.github.com/repos/{repository}/git/refs`,
		-- 			Method = "POST",
		-- 			Headers = headers,
		-- 			Body = requestBody
		-- 		})
		-- 	end)

		-- 	if success3 and not result3.Success then
		-- 		warn(`(git-push) Failed to create branch for file {name}: `.. result3.Body)
		-- 		mySHA = nil
		-- 	elseif not success3 then
		-- 		warn(`(git-push) Failed to create branch for file {name}: (no data)`)
		-- 		mySHA = nil
		-- 	end
		-- end
		-- End of getting backup SHA

		-- SHA guard
		if not mySHA then
			warn(`(git-push) Unable to obtain remote SHA for file {name}`) -- so its a new file probably
		end
		-- End of SHA guard

		-- Finally try and push the stuff
		if fileObject:IsA("BaseScript") then
			local success4, result4 = pcall(function()
					return HttpService:RequestAsync({
						Url = url..`/{name}.lua`,
						Method = "PUT",
						Headers = headers,
						Body = HttpService:JSONEncode({
							message = msg or ((mySHA) and `Updated {name}` or `Created {name}`),
							content = Functions.to_base64(fileObject.Source),
							branch = branch,
							sha = mySHA
					})
				})
			end)

			if success4 and not result4.Success then
				warn(`(git-push) Failed to push file {name}: `.. result4.Body)
			elseif not success4 then
				warn(`(git-push) Failed to push file {name}: (no data)`)
			end			
		end

		if #fileObject:GetChildren() > 0 then
			local myURL = `{url}/{fileObject.Name}`
			
			Functions.pushContainer(
				fileObject,
				headers,
				myURL,
				msg,
				branch
			)
		end
		-- End of finally tryna push the stuff
	end
end
--[[



]]
function main.gitPull(data: Types.GitDirectiveData)
	-- also post parsing

	local gitConfigLocal = data.config

	for path, file in pairs(data.files) do
		-- INITIALIZATION
		local split = path:split(".") -- {game, Workspace, ModelName, PartName, ScriptName}

		local name = file.name or split[#split] -- will have issues if there are periods in the instance names
		local repository = file.repository or gitConfigLocal.repository or gitConfigGlobal.repository or nil
		local token = file.token or gitConfigLocal.token or gitConfigGlobal.token or nil
		local filePath = file.path or gitConfigLocal.path or gitConfigGlobal.path or ""
		local branch = file.branch or gitConfigLocal.branch or gitConfigGlobal.branch or "main"

		local headers = {
			["Authorization"] = `token {token}`,
			["Accept"] = "application/vnd.github.v3+json"
		}

		-- Guards
		local issues = 0
		if not repository then
			warn(`(git-pull) No repository specified for file {name}`)
			issues += 1
		end

		if not token then
			warn(`(git-pull) No token specified for file {name}`)
			issues += 1
		end

		if issues > 0 then continue end
		-- End of Guards
		-- END OF INITIALIZATION

		-- Find real instance referenced
		local root = split[1]
		local fileObject

		if root == "game" then
			fileObject = game
			table.remove(split, 1)
		elseif root == "script" then
			fileObject = script
		elseif game:FindFirstChild(root) then
			fileObject = game
		else
			warn(`(git-pull) Invalid path for file {name}`)
		end

		for i, t in ipairs(split) do
			fileObject = fileObject[t] or nil
		end

		if not fileObject:IsA("Instance") then
			warn(`(git-pull) Invalid parent class for file {name}`)
			continue
		end
		-- End of finding real script instance

		-- Do the actual getting
		Functions.createStructure(fileObject, repository, name, filePath, headers, branch)
		-- End of doing the actual getting
	end
end

return main