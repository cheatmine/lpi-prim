--[[
	Prim API for LPI
	made by fastest.me

	Made for simplifying and utilizing F3X SyncAPI
	Source code: https://github.com/cheatmine/lpi-prim/
]]

-- Don't make another instance of Prim
if getgenv().Prim then
	return getgenv().Prim
end

--/ Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

--/ Utility
export type F3X = {
	Tool: Tool,
	Handle: BasePart,
	SyncAPI: RemoteFunction
}

local function getChar(plr: Player?): Model?
	return (plr or Player).Character
end
local function getHumanoid(plr: Player?): Humanoid
	return getChar(plr):FindFirstChild("Humanoid")
end
local function getF3X(): F3X
	local char = getChar()
	assert(char, "Missing character")
	local tool = char:FindFirstChild("F3X") or
		Player.Backpack:FindFirstChild("F3X")
	assert(tool, "No F3X tool present")
	getHumanoid():EquipTool(tool)

	return {
		Tool = tool,
		Handle = tool:FindFirstChild("Handle"),
		SyncAPI = Handle["SyncAPl"]["ServerEndPoint"..utf8.char(0x200C)]
	} :: F3X
end

--/ Part changes
local F3X: F3X = nil
local queue: {[BasePart]: {[string]: any}} = {}
local finishedChanges = Instance.new("BindableEvent", game:GetService("CoreGui"))
finishedChanges.Name = "PrimAPI_FinishedChanges"
local function addToQueue(part: BasePart, changes: {[string]: any})
	assert(typeof(part) == "Instance", "part argument must be a BasePart")
	assert(part:IsA("BasePart"), "part argument must be a BasePart")
	assert(part.Locked, "cannot make changes to a locked BasePart")
	queue[part] = changes
end
local function clearQueue()
	queue = {}
end

RunService.Heartbeat:Connect(function()
	local changes = {}
	for part, properties in queue do
		local surf = {}
		for key, value in properties do
			local bypasskey = key
			if #key == 4 or #key == 8 or #key == 16 then
				bypasskey ..= "\0."
			else
				bypasskey ..= "\0"
			end
			surf[bypasskey] = value
		end
		table.insert({
			Part = part,
			Surfaces = surf
		})
	end
	clearQueue()
	if #changes > 0 then
		getF3X().SyncAPI:InvokeServer("SyncSurface", changes)
	end
	finishedChanges:Fire(#changes)
end)

--/ Functions
local Prim = {}

--/ Utility
Prim.GetCharacter = getChar
Prim.GetHumanoid = getHumanoid

--/ Vulnerability utilization
Prim.QueuePartChangeAsync = addToQueue
Prim.WaitForQueueFinish = function(): number
	return finishedChanges:Wait()
end
Prim.QueuePartChange = function(part: BasePart, changes: {[string]: any}): number
	addToQueue(part, changes)
	return Prim.WaitForQueueFinish()
end

Prim.DestroyInstances = function(ins: {Instance})
	local F3X: F3X = getF3X()
	F3X.SyncAPI:InvokeServer("UndoRemove", ins)
end
Prim.DestroyInstance = function(ins: Instance)
	Prim.DestroyInstances({ins})
end
Prim.DestroyPartsAsync = function(ins: {BasePart})
	for _, v in ins do
		assert(typeof(v) == "Instance", "Instance argument should be a table of BasePart.")
		assert(v:IsA("BasePart"), "Cannot destroy a non-part instance. Use DestroyInstances() insead.")
		assert(v.Locked, "Cannot destroy a locked part. Use DestroyInstances() instead.")
		Prim.QueuePartChangeAsync(v, {Parent = nil})
	end
end
Prim.DestroyPartAsync = function(ins: BasePart)
	assert(typeof(v) == "Instance", "Instance argument should be a BasePart.")
	Prim.DestroyPartsAsync({ins})
end

Prim.DestroyF3XHandle = function()
	local F3X: F3X = getF3X()
	Prim.DestroyInstance(F3X.Handle)
end

--/ Regular SyncAPI calls
Prim.RecolorHandle = function(color: BrickColor)
	local F3X: F3X = getF3X()
	assert(F3X.Handle, "No F3X handle to be colored.")
	F3X.SyncAPI:InvokeServer("RecolorHandle", color)
end

Prim.Move = function(data: {{Part: BasePart, CFrame: CFrame?, Anchored: boolean?}})
	local F3X: F3X = getF3X()
	assert(type(data) == "table", "Move data must be a table of these elements {Part: BasePart, CFrame: CFrame?, Anchored: boolean?}")
	F3X.SyncAPI:InvokeServer("SyncMove", data)
end
Prim.Resize = function(data: {{Part: BasePart, Size: Vector3?, CFrame: CFrame?, Anchored: boolean?}})
	local F3X: F3X = getF3X()
	assert(type(data) == "table", "Resize data must be a table of these elements {Part: BasePart, Size: Vector3?, CFrame: CFrame?, Anchored: boolean?}")
	F3X.SyncAPI:InvokeServer("SyncResize", data)
end
Prim.Rotate = Prim.Move

Prim.Color = function(data: {{Part: BasePart, Color: Color3}})
	local F3X: F3X = getF3X()
	assert(type(data) == "table", "Color data must be a table of these elements {Part: BasePart, Color: Color3}")
	F3X.SyncAPI:InvokeServer("SyncColor", data)
end

--/ Direct access to SyncAPI, Handle, Tool
Prim.GetF3X = getF3X

getgenv().Prim = Prim -- Expose the API
return Prim