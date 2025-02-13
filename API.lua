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

--/ LPI Protection
task.spawn(function()
	_G.LPI_SECURITY_SCOPE = "Prim";
	loadstring(game:HttpGet("https://github.com/cheatmine/lpi/raw/main/security"))()
end)

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
	if not char:FindFirstChild("F3X") then
		getHumanoid():EquipTool(tool)
	end
	local SyncAPI = tool:FindFirstChild("SyncAPI") or tool:FindFirstChild("SyncAPl")
	SyncAPI = SyncAPI:FindFirstChild("ServerEndpoint") or SyncAPI:FindFirstChild("ServerEndPoint"..utf8.char(0x200C))

	return {
		Tool = tool,
		Handle = tool:FindFirstChild("Handle"),
		SyncAPI = SyncAPI
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
	assert(not part.Locked, "cannot make changes to a locked BasePart")
	queue[part] = changes
end
local function clearQueue()
	queue = {}
end

local function doChangesQueue()
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
		table.insert(changes, {
			Part = part,
			Surfaces = surf
		})
	end
	clearQueue()
	if #changes > 0 then
		getF3X().SyncAPI:InvokeServer("SyncSurface", changes)
	end
	finishedChanges:Fire(#changes)
end

--/ Asset streaming
local stream = {}

local function startStreaming(parts: {BasePart}, properties: {string})
	assert(type(parts) == "table", "Parts argument should be a table of BasePart")
	assert(type(properties) == "table", "Properties argument should be a table of string")
	for _, part in parts do
		assert(typeof(part) == "Instance", "Parts table content should be of BasePart")
		assert(part:IsA("BasePart"), "Parts table content should be of BasePart")
		stream[part] = properties
	end
end

local function stopStreaming(parts: {BasePart})
	assert(type(parts) == "table", "Parts argument should be a table of BasePart")
	for _, part in parts do
		assert(typeof(part) == "Instance", "Parts table content should be of BasePart")
		assert(part:IsA("BasePart"), "Parts table content should be of BasePart")
		stream[part] = nil
	end
end

--/ Heartbeat job
RunService.Heartbeat:Connect(function()
	for part, properties in stream do
		if properties == nil then continue end
		local proptable = {}
		for _, property in properties do
			proptable[property] = part[property]
		end
		addToQueue(part, proptable)
	end

	doChangesQueue()
end)

--/ Functions
local Prim = {}

--/ Utility
Prim.GetCharacter = getChar
Prim.GetHumanoid = getHumanoid

--/ Vulnerability utilization & asset streaming
Prim.QueuePartChangeAsync = addToQueue
Prim.WaitForQueueFinish = function(): number
	return finishedChanges.Event:Wait()
end
Prim.QueuePartChange = function(part: BasePart, changes: {[string]: any}): number
	addToQueue(part, changes)
	return Prim.WaitForQueueFinish()
end

Prim.StartStreaming = startStreaming
Prim.StopStreaming = stopStreaming
Prim.GetStreamed = function(): {[BasePart]: {string}}
	return stream
end
Prim.IsStreamed = function(part: BasePart): (boolean, {string})
	return (not not stream[part]), stream[part]
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
		assert(not v.Locked, "Cannot destroy a locked part. Use DestroyInstances() instead.")
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

Prim.Weld = function(p0: BasePart, p1: BasePart): {Weld}
	local F3X: F3X = getF3X()
	-- if none are locked, or p0 is locked
	if (p0.Locked and not p1.Locked) or (not p0.Locked and not p1.Locked) then
		return F3X.SyncAPI:InvokeServer("CreateWelds", {p1}, p0)
	-- if p1 is locked
	elseif not p0.Locked and p1.Locked then
		return F3X.SyncAPI:InvokeServer("CreateWelds", {p0}, p1)
	-- if both are locked
	else
		error("Cannot weld two locked parts")
	end
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

Prim.CreateDecorations = function(data: {{Part: BasePart, DecorationType: string}})
	local F3X: F3X = getF3X()
	assert(type(data) == "table", "Decoration data must be a table of these elements {Part: BasePart, DecorationType: Decoration} (see docs for more info)")
	F3X.SyncAPI:InvokeServer("CreateDecorations", data)
end
Prim.EditDecorations = function(data: {{Part: BasePart, DecorationType: string, [string]: any}})
	local F3X: F3X = getF3X()
	assert(type(data) == "table", "Decoration data must be a table of these elements {Part: BasePart, DecorationType: Decoration, ...DecorationProperties} (see docs for more info)")
	F3X.SyncAPI:InvokeServer("SyncDecorations", data)
end

Prim.CreateFire = function(parts: {BasePart}, properties: {[BasePart]: {[string]: any}}?)
	local F3X: F3X = getF3X()
	assert(type(data) == "table", "Parts argument must be a table of BasePart")
	local ct = {}
	for i, v in parts do
		assert(typeof(v) == "Instance", "Table elements must be BasePart")
		assert(v:IsA("BasePart"), "Table elements must be BasePart")
		local ft = {Part = v, DecorationType = "Fire"}
		if properties then
			for i, v in properties[v] do
				ft[i] = v
			end
		end
		table.insert(ct, ft)
	end
	F3X.SyncAPI:InvokeServer("CreateDecorations", ct)
	if properties then
		F3X.SyncAPI:InvokeServer("SyncDecorations", ct)
	end
end
Prim.EditFire = function(parts: {BasePart}, properties: {[BasePart]: {[string]: any}})
	local F3X: F3X = getF3X()
	assert(type(data) == "table", "Parts argument must be a table of BasePart")
	assert(type(properties) == "table", "Properties argument must be a FireDecoration (see docs for more info)")
	local ct = {}
	for i, v in parts do
		assert(typeof(v) == "Instance", "Parts table elements must be BasePart")
		assert(v:IsA("BasePart"), "Parts table elements must be BasePart")
		local ft = {Part = v, DecorationType = "Fire"}
		for property, value in properties[v] do
			ft[property] = value
		end
		table.insert(ct, ft)
	end
	F3X.SyncAPI:InvokeServer("SyncDecorations", ct)
end

Prim.CreateTextures = function(parts: {BasePart}, face: Enum.NormalId, texturetype: string, texture: string)
	local F3X: F3X = getF3X()
	local ct = {}
	for i, v in parts do
		table.insert(ct, {Part = v, Face = face, TextureType = texturetype, Texture = texture})
	end
	F3X.SyncAPI:InvokeServer("CreateTextures", ct)
	F3X.SyncAPI:InvokeServer("SyncTexture", ct)
end

Prim.CreatePart = function(pos: CFrame, shapeid: number?): {BasePart}
	local shape = ({
		"Normal", "Truss", "Wedge", "Corner", "Cylinder", "Ball", "Seat", "Vehicle Seat", "Spawn"
	})[shapeid or 1]
	local F3X: F3X = getF3X()
	return F3X.SyncAPI:InvokeServer("CreatePart", shape, pos)
end

Prim.CloneParts = function(parts: {BasePart}): {BasePart}
	local F3X: F3X = getF3X()
	return F3X.SyncAPI:InvokeServer("Clone", parts)
end
Prim.ClonePart = function(part: BasePart): BasePart
	return Prim.CloneParts({part})
end

--/ Direct access to SyncAPI, Handle, Tool
Prim.GetF3X = getF3X

getgenv().Prim = Prim -- Expose the API
return Prim
