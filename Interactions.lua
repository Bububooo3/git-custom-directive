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
				directory: [GITHUB PATH];
				branch: [BRANCH];
				output-enabled: [OUTPUT ENABLED];
				commit-message: [COMMIT MESSAGE];
			</config>

			<files>
				script: {
					name: "Example";

					token: "12345678910";
					repository: "username/reponame";
					directory: ""; --<prefixes: ./, /, nothing>
					branch: "main";
					output-enabled: false;
					commit-message: "We did it!";
				};
			</files>
		];
	]=]
]]

type GitConfigData = {
	token: string | nil;
	repository: string | nil;
	directory: string | nil;
	branch: string | nil;
	message: string | nil;
}

type GitDirectiveData = {
	config: GitConfigData,

	files: { -- [script absolute file path from game]: {upload data}
		[string]: {
			name: string | nil;
			token: string | nil;
			repository: string | nil;
			directory: string | nil;
			branch: string | nil;
			message: string | nil;
		}
	}
}

local gitConfigGlobal: GitConfigData = {}
local baseURL = "https://api.github.com/repos/%s/contents/%s"

function gitPush(data: GitDirectiveData)
	-- post parsing

	local gitConfigLocal = data.config

	for path, file in pairs(data.files) do
		local split = path:split(".") -- {game, workspace, ModelName, PartName, ScriptName}

		local name = file.name or split[#split]
		local repository = file.repository or gitConfigLocal.repository or gitConfigGlobal.repository or nil
		local token = file.token or gitConfigLocal.token or gitConfigGlobal.token or nil
		local directory = file.directory or gitConfigLocal.directory or gitConfigGlobal.directory or ""
		local branch = file.branch or gitConfigLocal.branch or gitConfigGlobal.branch or "main"
		local msg = file.message or gitConfigLocal.message or gitConfigGlobal.message or `Updated {name}`


		-- Guards
		local issues = 0
		if not repository then
			warn(`No repository specified for file {name}`)
			issues += 1
		end

		if not token then
			warn(`No token specified for file {name}`)
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
			warn(`Invalid file path for file {name}`)
		end

		for i, t in ipairs(split) do
			fileObject = fileObject[t] or nil
		end

		-- End of finding real script instance


		local url = baseURL:format(repository, directory)

		local body = {
			message = msg;
			content = Functions.to_base64()
		}
	end
end

function Interactions.pushToGitHub(src: {BaseScript}, repo, targetLocation, srcLocation, branchFlag, outputFlag, messageFlag, nameFlag)
	local scripts = src
	local url = "https://api.github.com/repos/" ..repo .. "/contents/"

	ChangeHistoryService:SetWaypoint("Before GitHub Push")

	for name, data in pairs(scripts) do
		task.wait()
		local filePath = Functions.getScriptPath(data.Object)
		local fileUrl = url .. filePath
		
		local requestBody = {
			message = "Updated " .. filePath,
			content = Functions.to_base64(data.Source),
			branch = branchFlag or "main",
			sha = Functions.getFileSHA(filePath) or Interactions.getLatestCommitSHA()
		}

		local headers = {
			["Authorization"] = "token " .. plugin:GetSetting(Gitsync.Settings.TOKEN),
			["Accept"] = "application/vnd.github.v3+json"
		}

		local success, response = pcall(function()
			return HttpService:RequestAsync({
				Url = fileUrl,
				Method = "PUT",
				Headers = headers,
				Body = HttpService:JSONEncode(requestBody)
			})
		end)

		if response.Success then
			if plugin:GetSetting(Gitsync.Settings.OUTPUTENABLED) then print("Pushed: ", filePath) end
			pushButton.ImageLabel.ImageColor3 = Gitsync.Colors.Green
		else
			warn("Failed to push: ", filePath)
			warn("Response: ", response.Body)
			pushButton.ImageLabel.ImageColor3 = Gitsync.Colors.Red
		end

		ChangeHistoryService:SetWaypoint("After GitHub Push")
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