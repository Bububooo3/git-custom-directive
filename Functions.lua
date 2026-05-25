-- Modified from GitSync 1.12.45 by Roller_Bott
--!optimize 2
---------------------------------------------------
-- GLOBALS
local HttpService = game:GetService("HttpService")
local Functions, entries, Connections = {}, 0, {} :: {RBXScriptConnection}

---------------------------------------------------
-- INITIALIZATION
local plugin

function Functions.Init(pluginVar)
	plugin = pluginVar
end

---------------------------------------------------
-- FUNCTION DECLARATIONS
----> Disconnect connections
function Functions.Disconnect(target: any)
	for tag, cxn: RBXScriptConnection in Connections do
		task.wait()
		if not (tostring(tag) == tostring(target)) then return end
		cxn:Disconnect()
		Connections[tag] = nil
	end
end

----> Get absolute path of object using slashes instead of periods
function Functions.getFullNameFormatted(object: Instance) --> Modified from Roblox docs
	local result = object.Name
	object = object.Parent
	while object and object ~= game do
		result = object.Name .. "/" .. result
		object = object.Parent
	end
	return result
end

----> Get path of script instance (up to Services)
function Functions.getScriptPath(scriptFile: BaseScript)	
	return Functions.getFullNameFormatted(scriptFile) .. ".lua"
end

----> Return the contents of a repository
function Functions.getRepoContents(path: string)
	local url = "https://api.github.com/repos/" .. plugin:GetSetting(Gitsync.Settings.REPOSITORY) .. "/contents/" .. (path or "") .."?ref="..plugin:GetSetting(Gitsync.Settings.BRANCH)
	local headers = {
		["Authorization"] = "token " .. plugin:GetSetting(Gitsync.Settings.TOKEN),
		["Accept"] = "application/vnd.github.v3+json"
	}

	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "GET",
			Headers = headers
		})
	end)

	if response.Success then
		return HttpService:JSONDecode(response.Body)
	else
		warn("Failed to fetch repository contents.")
		--print(pullButton)
		if pullButton then pullButton.ImageLabel.ImageColor3 = Gitsync.Colors.Red end
		return nil
	end
end

----> Create & return a rectangular button in repository viewer
function Functions.createEntry(name: string, parentFrame: Frame, isFolder: bool) : TextLabel
	local entry = script.templatefileindicator:Clone()

	entry.template.Text = name
	entry.Name = name
	entry.LayoutOrder = entries

	if isFolder then
		entry.template.Text = "<b>"..name.."</b>"
		entry.template.TextColor3 = Gitsync.Colors.Blue
	end

	entry.LayoutOrder = entries
	entry.Visible = true
	entry.Parent = parentFrame
	entry.ZIndex = parentFrame.ZIndex + 1
	entries += 2

	return entry
end

----> Populate explorer window (repository viewer) with entries
function Functions.populateExplorer(parentFrame: Frame, path: string) : nil
	for i, v in parentFrame:GetChildren() do task.wait(); if not v:IsA("UIListLayout") then v:Destroy() end end

	local contents = Functions.getRepoContents(path)

	if not contents then return end

	for _, item in ipairs(contents) do
		task.wait()
		local isFolder = (item.type == "dir")
		local entry = Functions.createEntry(item.name, parentFrame, isFolder)

		if isFolder then
			entry.MouseButton1Click:Connect(function()
				local widgetInfo = DockWidgetPluginGuiInfo.new(
					Enum.InitialDockState.Float, false, false, 300, 200, 300, 200
				)

				local explorer_widget = plugin:CreateDockWidgetPluginGui("GitHubSyncExplorer - "..item.name..tostring(Random.new():NextNumber(-100000*11.29422, 999999*12.29435)), widgetInfo)
				explorer_widget.Title = "Git Explorer - "..item.name

				table.insert(Gitsync.ActiveExplorerWidgets, explorer_widget)

				local explorer_frame = script.Parent.ExplorerWindow:Clone()
				explorer_frame.Parent = explorer_widget
				explorer_frame.Size = UDim2.fromScale(1,1)
				explorer_frame.Visible = true
				explorer_widget.Enabled = true

				Functions.populateExplorer(explorer_frame.ScrollingFrame, item.path)
			end)

		else
			entry.MouseButton1Click:Connect(function()		
				local widgetInfo = DockWidgetPluginGuiInfo.new(
					Enum.InitialDockState.Float, false, false, 300, 200, 400, 300
				)
				local explorer_widget = plugin:CreateDockWidgetPluginGui("GitHubSyncExplorer - "..item.name..tostring(Random.new():NextNumber(-100000*10.29432, 999999*10.29432)), widgetInfo)
				explorer_widget.Title = "GitSync File Explorer - "..item.name
				local text = script.Parent.CodeViewer:Clone()
				text.TextBox.Text = Functions.from_base64(HttpService:JSONDecode((HttpService:GetAsync(item.url, true, {["Authorization"] = "token " .. plugin:GetSetting(Gitsync.Settings.TOKEN),["Accept"] = "application/vnd.github.v3+json"}))).content)
				text.Parent = explorer_widget

				explorer_widget.Enabled = true
			end)
		end
	end
end

----> Generate a folder instance structure (directory) in parent by recursively searching repository directory
function Functions.createStructure(parent: any, contents: any, pullButton: GuiButton) : nil
	local new_directiories: {Folder} = {}
	local tOE = plugin:GetSetting(Gitsync.Settings.OUTPUTENABLED)
	
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
			if subContents then Functions.createStructure(folder, subContents, pullButton) end

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
				if pullButton then pullButton.ImageLabel.ImageColor3 = Gitsync.Colors.Green end
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

----> Retrieves latest commit data of specified file path
function Functions.getFileSHA(filePath: string) : string | nil
	local HttpService = game:GetService("HttpService")
	local url = "https://api.github.com/repos/" .. plugin:GetSetting(Gitsync.Settings.REPOSITORY) .. "/contents/" .. filePath.."?ref="..plugin:GetSetting(Gitsync.Settings.BRANCH)

	local headers = {
		["Authorization"] = "token " .. plugin:GetSetting(Gitsync.Settings.TOKEN),
		["Accept"] = "application/vnd.github.v3+json"
	}

	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "GET",
			Headers = headers
		})
	end)

	if response.Success then
		local data = HttpService:JSONDecode(response.Body)
		return data.sha -- Update
	else
		return nil -- Make new file
	end
end

----> Recursive search a directory and document scripts found
function Functions.scanFolder(folder: Instance, path: string) : boolean
	for _, obj in ipairs(folder:GetChildren()) do
		task.wait()
		if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
			scriptsSeen[obj.Name] = {["Source"] = obj.Source, ["Class"] = obj.ClassName, ["Object"] = obj}
		end

		if #obj:GetChildren() > 0 then
			Functions.scanFolder(obj, path .. obj.Name .. "/")
		end
	end

	return true
end

----> Get scripts selected by developer and recursively search folders that are descendants of the selected instances
function Functions.getSelectedScripts() : {BaseScript}
	local selected = Selection:Get()
	scriptsSeen = {}

	for _, obj in ipairs(selected) do
		task.wait()
		if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
			scriptsSeen[obj.Name] = {["Source"] = obj.Source, ["Class"] = obj.ClassName, ["Object"] = obj}
		end

		if #obj:GetChildren() > 0 then
			Functions.scanFolder(obj, obj.Name .. "/")
		end
	end

	return scriptsSeen
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

--[[ MODULE DOESNT WORK RN CAUSES CATASTROPHIC ERRORS (Properties Module)
----> Build a table of the selected Instances
function Functions.make_table(root: Instance, t: {})
	if not t then t = {} end
	if not t.Name then t.Name = root.Name end
	if not t.ClassName then t.ClassName = root.ClassName end

	for i, v in root:GetChildren() do
		task.wait()
		local name = v.Name
		local interval = 0

		while t[name] do
			task.wait()
			interval += 1
			name = v.Name .. interval
		end

		t[name] = {Children={}}
		t[name].Name = name
-----------
TODO
- Figure out how to merge current pushing/pulling with json pushing/pulling
- Get script sources for table creation
-----------

		if GetProperties[v.ClassName] then
			t[name]["ClassName"] = v.ClassName

			for property, value in GetProperties[v.ClassName] do
				task.wait()
				if not pcall(function()
						t[name][property] = v[property] or nil
					end) then continue end
			end
		elseif v.Parent == game then
			t[name]["ClassName"] = string.gsub(v.Name, " ", "")
			t[name]["Service"] = true
		else
			t[name]["ClassName"] = string.gsub(v.Name, " ", "")
		end
		if #v:GetChildren() > 0 then
			Functions.make_table(v, t[name]["Children"])
		end

	end

	return t
end

----> Transcribe a table of selected Instances
function Functions.write_table(root: Instance, t: {})	
	if type(t) ~= "table" then return end
	local new_file

	if t["Service"] then
		new_file = Instance.new("Folder", root)
		new_file:SetAttribute("ClassName", t["ClassName"])
	else
		local success, result = pcall(function() new_file = Instance.new(t.ClassName, root) end)

		if not success then
			new_file = Instance.new("Folder", root)
			new_file:SetAttribute("ClassName", t["ClassName"])
		end
	end

	new_file.Name = t.Name or t.ClassName or "nil"

	if GetProperties[t.ClassName] then
		for property, value in GetProperties[t.ClassName] do
			task.wait()
			if property == "Parent" then continue end
			if not pcall(function()
					new_file[property] = t[property] or nil
				end) then continue end
		end
	end

	if not t["Children"] then
		for i, v in t do
			task.wait()
			Functions.write_table(new_file, v)
		end
	else
		for i, v in t["Children"] do
			task.wait()
			Functions.write_table(new_file, v)
		end
	end
end
]]

return Functions
---------------------------------------------------