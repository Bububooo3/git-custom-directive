-- Modified from GitSync 1.12.45 by Roller_Bott
---------------------------------------------------
-- GLOBALS
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Functions = require("./Functions")
local Interactions = {}

---------------------------------------------------
-- INITIALIZATION
local plugin

function Interactions.Init(pluginVar)
	plugin = pluginVar
end

---------------------------------------------------
-- FUNCTION DECLARATIONS
----> Push selected scripts to specified repository & branch
--[[
	[=[
		git-config = [ // This is global config (act as back-ups if failure occurs also)
			token: [TOKEN];
			repository: [REPO];
			username: [USERNAME];
			target-directory: [GITHUB PATH];
			branch: [BRANCH];
			output-enabled: [OUTPUT ENABLED];
			commit-message: [COMMIT MESSAGE];
		];

		git-push = [
			<config> // this is quick-config for local changes/setup
				token: [TOKEN];
				repository: [REPO];
				path: [GITHUB PATH];
				branch: [BRANCH];
				output-enabled: [OUTPUT ENABLED];
				commit-message: [COMMIT MESSAGE];
			</config>

			<files>
				workspace.Script: {
					name: "Example";

					token: "12345678910";
					repository: "username/reponame";
					path: "";
					branch: "main";
					output-enabled: false;
					commit-message: "We did it!";
				};

				workspace.Folder: { // In the parser it will identify & report scripts automatically so that data is still {BaseScript}
					name: "Example";

					token: "12345678910";
					repository: "username/reponame";
					path: "";
					branch: "main";
					output-enabled: false;
					commit-message: "We did it!";
				};
			</files>
		];

		git-pull = [
			<config>
				token: [TOKEN];
				repository: [REPO];
				path: [GITHUB PATH];
				branch: [BRANCH];
				output-enabled: [OUTPUT ENABLED];
			</config>

			<files>
				workspace.Script: {
					token: "12345678910";
					repository: "username/reponame";
					path: "";
					branch: "main";
					output-enabled: false;
				};

				workspace.Folder: {
					token: "12345678910";
					repository: "username/reponame";
					path: "";
					branch: "main";
					output-enabled: false;
				};
			</files>
		];
	]=]
]]

type GitConfigData = {
	token: string | nil;
	repository: string | nil;
	path: string | nil;
	branch: string | nil;
	message: string | nil;
	base: string;
}

type GitDirectiveData = {
	config: GitConfigData,

	files: { -- [script absolute file path from game]: {upload data}
		[string]: {
			name: string | nil;
			token: string | nil;
			repository: string | nil;
			path: string | nil;
			branch: string | nil;
			message: string | nil;
		}
	}
}

local gitConfigGlobal: GitConfigData = {base='main'}
local baseURL = "https://api.github.com/repos/%s/contents/%s"

function gitPush(data: GitDirectiveData)
	-- post parsing

	local gitConfigLocal = data.config

	for path, file in pairs(data.files) do
		local split = path:split(".") -- {game, Workspace, ModelName, PartName, ScriptName}

		local name = file.name or split[#split] -- will have issues if there are stars in the instance names
		local repository = file.repository or gitConfigLocal.repository or gitConfigGlobal.repository or nil
		local token = file.token or gitConfigLocal.token or gitConfigGlobal.token or nil
		local filePath = file.path or gitConfigLocal.path or gitConfigGlobal.path or ""
		local branch = file.branch or gitConfigLocal.branch or gitConfigGlobal.branch or "main"
		local msg = file.message or gitConfigLocal.message or gitConfigGlobal.message or `Updated {name}`

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

		if issues > 0 then return end
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

		if not fileObject:IsA("BaseScript") then 
			warn(`(git-push) Invalid instance for file {name}`)
			return
		end
		-- End of finding real script instance

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
		if not mySHA then
			warn(`(git-push) Initial attempt to retrieve SHA failed for file {name}`)
			warn(`(git-push) Attempting to create new branch from base branch for file {name}`)

			local success2, result2 = pcall(function()
			    return HttpService:RequestAsync({
			        Url = `https://api.github.com/repos/{repository}/git/refs/heads/{gitConfigGlobal.base}`,
			        Method = "GET",
			        Headers = headers
			    })
			end)

			if success2 and result2.Success then
			    mySHA = HttpService:JSONDecode(result2.Body).object.sha 
			else
			    warn(`(git-push) Failed to retrieve base SHA for file {name}`)
			end

			local requestBody = HttpService:JSONEncode({
				ref = `refs/heads/{branch}`,
				sha = mySHA
			})

			local success3, result3 = pcall(function()
				return HttpService:RequestAsync({
					Url = `https://api.github.com/repos/{repository}/git/refs`,
					Method = "POST",
					Headers = headers,
					Body = requestBody
				})
			end)

			if success3 and not result3.Success then
				warn(`(git-push) Failed to create branch for file {name}: `.. result3.Body)
				mySHA = nil
			elseif not success3 then
				warn(`(git-push) Failed to create branch for file {name}: (no data)`)
				mySHA = nil
			end
		end
		-- End of getting backup SHA

		-- SHA guard
		if not mySHA then
			warn(`(git-push) Unable to obtain remote SHA for file {name}`)
		end
		-- End of SHA guard

		-- Finally try and push the stuff
		local success4, result4 = pcall(function()
				return HttpService:RequestAsync({
					Url = url,
					Method = "PUT",
					Headers = headers,
					Body = HttpService:JSONEncode({
						message = msg;
						content = Functions.to_base64(fileObject.Source);
						branch = branch;
						sha = mySHA
				})
			})
		end)

		if success4 and not result4.Success then
			warn(`(git-push) Failed to push file {name}: `.. result4.Body)
		elseif not success4 then
			warn(`(git-push) Failed to push file {name}: (no data)`)
		end
		-- End of finally tryna push the stuff
	end
end

----> Pull entire repository from GitHub and import it to Studio
function Interactions.pullFromGitHub(pullButton)

	ChangeHistoryService:SetWaypoint("Before GitHub Pull")	

	local contents = Functions.getRepoContents("", pullButton)
	if contents then
		--local rootFolder = Instance.new("Folder")
		--local directory = string.split(plugin:GetSetting(Gitsync.Settings.REPOSITORY), "/")
		--rootFolder.Name = directory[2]
		--rootFolder.Parent = workspace
		--print(workspace contents, pullButton)
		Functions.createStructure(workspace, contents, pullButton)
	else
		return
	end

	ChangeHistoryService:SetWaypoint("After GitHub Pull")	
	return
end

----> Delete file
function Interactions.deleteFile(filePath, sha)
	local HttpService = game:GetService("HttpService")
	local url = "https://api.github.com/repos/".. plugin:GetSetting(Gitsync.Settings.REPOSITORY) .. "/contents/" .. filePath

	local requestBody = HttpService:JSONEncode({
		message = "Deleted " .. filePath,
		sha = sha,
		branch = plugin:GetSetting(Gitsync.Settings.BRANCH)
	})

	local headers = {
		["Authorization"] = "token " .. plugin:GetSetting(Gitsync.Settings.TOKEN),
		["Accept"] = "application/vnd.github.v3+json"
	}

	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "DELETE",
			Headers = headers,
			Body = requestBody
		})
	end)

	if response.Success then
		if plugin:GetSetting(Gitsync.Settings.OUTPUTENABLED) then
			print("Successfully deleted " .. filePath)
		end
		return true
	else
		warn("Failed to delete file: " .. response.Body)
		return false
	end
end

----> Retrieves and returns a list of branches in the repository
function Interactions.listBranches() : {string}
	local url = "https://api.github.com/repos/".. plugin:GetSetting(Gitsync.Settings.REPOSITORY) .. "/branches"
	local headers = { ["Authorization"] = "token " .. plugin:GetSetting(Gitsync.Settings.TOKEN) }

	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "GET",
			Headers = headers
		})
	end)

	if response.Success then
		local branches = game:GetService("HttpService"):JSONDecode(response.Body)
		if plugin:GetSetting(Gitsync.Settings.OUTPUTENABLED) then print("Refreshed branch list: ", branches) end
		return branches
	else
		warn("Failed to list branches: " .. response.Body)
		return {}
	end
end

----> Get information (sha) about the latest commit on the specified branch
function Interactions.getLatestCommitSHA()
	local HttpService = game:GetService("HttpService")
	local url = "https://api.github.com/repos/" .. plugin:GetSetting(Gitsync.Settings.REPOSITORY) .. "/branches/" .. plugin:GetSetting(Gitsync.Settings.BRANCH)

	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "GET",
			Headers = {
				["Authorization"] = "token " .. plugin:GetSetting(Gitsync.Settings.TOKEN),
				["Accept"] = "application/vnd.github.v3+json"
			}
		})
	end)
	
	local data = HttpService:JSONDecode(response.Body)
	--assert(response.Success, "Failed to get latest commit SHA:"..response.Body)
	--print(data)
	if not response.Success then
		warn("Failed to get latest commit SHA:"..response.Body)
		warn("Attempting to use branch \"main\" as SHA")
		local url = "https://api.github.com/repos/" .. plugin:GetSetting(Gitsync.Settings.REPOSITORY) .. "/branches/main"

		success, response = pcall(function()
			return HttpService:RequestAsync({
				Url = url,
				Method = "GET",
				Headers = {
					["Authorization"] = "token " .. plugin:GetSetting(Gitsync.Settings.TOKEN),
					["Accept"] = "application/vnd.github.v3+json"
				}
			})
		end)
		
		if not response.Success then
			warn("Failed to get latest commit SHA using branch \"main\": "..response.Body)
			warn("Attempting to make initial commit")
			
			
		end
	end
	
	if data then return data.commit.sha end
end

----> Create a new branch based on the specified commit
function Interactions.createBranch(branchName, baseSha)
	local HttpService = game:GetService("HttpService")
	local url = "https://api.github.com/repos/".. plugin:GetSetting(Gitsync.Settings.REPOSITORY) .. "/git/refs"

	local requestBody = HttpService:JSONEncode({
		ref = "refs/heads/" .. branchName,
		sha = baseSha
	})

	local headers = {
		["Authorization"] = "token " .. plugin:GetSetting(Gitsync.Settings.TOKEN),
		["Accept"] = "application/vnd.github.v3+json"
	}

	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "POST",
			Headers = headers,
			Body = requestBody
		})
	end)

	if response.Success then
		if plugin:GetSetting(Gitsync.Settings.OUTPUTENABLED) then
			print("Successfully created branch: " .. branchName)
		end
		return true
	else
		warn("Failed to create branch: " .. response.Body)
		return nil
	end
end

return Interactions