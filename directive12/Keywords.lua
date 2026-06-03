--$MODULE

--!native
--!optimize 2

local server = {
	"FireClient",
	"FireAllClients",
	"InvokeClient",
	"OnServerEvent",
	"OnServerInvoke",

	"DataStoreService",
	"HttpService",
	"MessagingService",
	"MemoryStoreService",
	"MarketplaceService",
	"BadgeService",
	"GroupService",
	"AssetService",
	"TeleportService",
	"PhysicsService",

	"ServerStorage",
	"ServerScriptService",

	"game:BindToClose",
	":SetNetworkOwner",
	":GetNetworkOwner",

	"PlayerAdded",
	"PlayerRemoving",
	"CharacterAutoLoads",
}

local client = {
	".LocalPlayer",
	"LocalPlayer.PlayerGui",
	"LocalPlayer.Backpack",
	"LocalPlayer.Character",
	"CharacterAdded",

	"FireServer",
	"InvokeServer",
	"OnClientEvent",
	"OnClientInvoke",

	"UserInputService",
	"ContextActionService",
	"InputBegan",
	"InputEnded",
	"InputChanged",
	"GetKeysPressed",
	"IsKeyDown",
	"TouchTap",
	"TouchSwipe",

	"GuiService",
	"TextChatService",
	"StarterGui",
	"ScreenGui",
	"BillboardGui",
	"SurfaceGui",
	"PlayerGui",
	"PlayerScripts",

	"RenderStepped",
	"CurrentCamera",
	"CFrame.new",

	"ReplicatedFirst",

	"VRService",
	"HapticService",
}

local module = {
	"setmetatable",
	"getmetatable",
	"rawget",
	"rawset",
	"rawequal",
	"rawlen",

	"__add",
	"__sub",
	"__mul",
	"__div",
	"__mod",
	"__pow",
	"__unm", 
	"__idiv",

	"__band",
	"__bor", 
	"__bxor",
	"__bnot",
	"__shl", 
	"__shr", 

	"__eq",
	"__lt",
	"__le",

	"__concat",
	"__len",
	"__tostring",

	"__index",
	"__newindex",
	"__call",
	"__gc",
	"__close",
	"__mode",
	"__metatable",

	"return {",
	"return self",
	".__index =",
	":new(",
	".new(",
}

return {
	s = server,
	c = client,
	m = module
}