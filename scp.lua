return function(Library, Window)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

local Libraries = ReplicatedStorage:FindFirstChild("Libraries")
local Network = Libraries and Libraries:FindFirstChild("Network")
local Channel = Network and Network:FindFirstChild("Channel")
local ShootEvent = Channel and Channel:FindFirstChild("tool/shoot")
local AttackEvent = Channel and Channel:FindFirstChild("tool/attack")
local SoundEvent = Channel and Channel:FindFirstChild("tool/sound")
local RoleEvent = Channel and Channel:FindFirstChild("core/role")

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function GetScreenSize()
	local guiInset = GuiService:GetGuiInset()
	local size = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
			or Vector2.new(1024, 750)
	return Vector2.new(size.X, size.Y - guiInset.Y), guiInset
end

local function GetScale()
	local sz = GetScreenSize()
	if IS_MOBILE then
		return math.clamp(sz.X / 772, 0.452, 0.786)
	else
		return math.clamp(sz.X / 1870, 0.555, 0.895)
	end
end

local MAX_RANGE = 271
local MELEE_RANGE = 8
local SHOOT_CD = 0.087
local MELEE_CD = 0.150
local MELEE_INTERVAL = 0.035
local MAX_SHOOTS_PER_FRAME = 2
local autoShoot = false
local autoMelee = false
local rayEnabled = false
local drawCircle = false
local attackEscapedD = false
local espEnabled = false
local funMode = false
local silentMode = false
local invincibleCheck = true
local drawBeams = false

local FOUNDATION = { scientist = true, security = true, mtf = true, director = true }
local CHAOS = { chaos_insurgency = true, rogue_agent = true, traitor = true, renegade = true }
local DCLASS = { d_class = true, escaped_d = true, escaped_d_class = true }

local WL = {}
local function isWL(p) return p and WL[p.Name] or false end
local function addWL(n) if n and n ~= "" then WL[n] = true end end

local myRole = nil
local function GetRole(p) return p and p:GetAttribute("Role") or nil end
local function UpdateMyRole()
	local r = GetRole(player)
	if r ~= myRole then myRole = r end
end
UpdateMyRole()
player:GetAttributeChangedSignal("Role"):Connect(UpdateMyRole)

local function IsEnemy(p)
	if not p or p == player then return false end
	if isWL(p) then return false end
	local tr = GetRole(p)
	if not tr or tr == "" then return false end
	if tr == "anomaly" or myRole == "anomaly" then return true end
	if tr == myRole then return false end

	if FOUNDATION[myRole] then
		if CHAOS[tr] then return true end
		if DCLASS[tr] then return attackEscapedD and (tr ~= "d_class") or false end
		return false
	end
	if CHAOS[myRole] then
		if FOUNDATION[tr] then return true end
		if DCLASS[tr] then return true end
		return false
	end
	if DCLASS[myRole] then
		return FOUNDATION[tr] and true or false
	end
	return false
end

local function GetTagWrapper(p)
	if not p or not p.Character then return nil end
	local hrp = p.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local tag = hrp:FindFirstChild("Tag")
	return tag and tag:FindFirstChild("Wrapper") or nil
end

local function IsHostile(p)
	local w = GetTagWrapper(p)
	if not w then return false end
	local h = w:FindFirstChild("Hostile")
	if not h then return false end
	return h.Visible == true
end

local function IsEscaped(p)
	local w = GetTagWrapper(p)
	if not w then return false end
	local e = w:FindFirstChild("Escaped")
	if not e then return false end
	return e.Visible == true
end

local invincibleUntil = setmetatable({}, { __mode = "k" })

local function CheckForceFieldExists(p)
	if not p then return false end

	local wsModel = Workspace:FindFirstChild(p.Name)
	if wsModel then
		local ff = wsModel:FindFirstChild("Forcefield")
		if ff then return true end
		ff = wsModel:FindFirstChild("ForceField")
		if ff then return true end
		for _, child in ipairs(wsModel:GetChildren()) do
			if child:IsA("ForceField") then return true end
			local ff2 = child:FindFirstChild("Forcefield")
			if ff2 then return true end
			ff2 = child:FindFirstChild("ForceField")
			if ff2 then return true end
		end
	end

	if p.Character then
		local ff = p.Character:FindFirstChild("Forcefield")
		if ff then return true end
		ff = p.Character:FindFirstChild("ForceField")
		if ff then return true end
		for _, desc in ipairs(p.Character:GetDescendants()) do
			if desc.Name == "Forcefield" or desc.Name == "ForceField" then
				if desc:IsA("ForceField") or desc:IsA("BasePart") or desc:IsA("Folder") then
					return true
				end
			end
		end
	end

	return false
end

local function MarkInvincible(p)
	invincibleUntil[p] = tick() + 5.0
end

local function ClearInvincible(p)
	invincibleUntil[p] = nil
end

local function IsInvincibleCached(p)
	if not invincibleCheck then return false end
	if invincibleUntil[p] and tick() < invincibleUntil[p] then
		return true
	end
	return false
end

task.spawn(function()
	while true do
		task.wait(1.0)
		if not invincibleCheck then
			invincibleUntil = setmetatable({}, { __mode = "k" })
			continue
		end

		for _, p in ipairs(Players:GetPlayers()) do
			if p == player then continue end
			local hasFF = CheckForceFieldExists(p)
			if hasFF then
				MarkInvincible(p)
			else
				if invincibleUntil[p] then
					ClearInvincible(p)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	ClearInvincible(p)
end)

local MeleeNames = { "knife", "crowbar", "tomahawk", "hammer", "bat", "sword", "axe", "machete", "fists", "combat", "blade", "spear", "dagger" }
local RangedNames = { "glock", "beretta", "mp5", "ak47", "hk416", "spas-12", "awm", "m249", "deagle", "uzi", "rifle", "shotgun", "pistol" }
local function IsMelee(n) n=(n or ""):lower() for _,k in ipairs(MeleeNames) do if n:find(k) then return true end end return false end
local function IsRanged(n) n=(n or ""):lower() for _,k in ipairs(RangedNames) do if n:find(k) then return true end end return false end
local function IsShotgun(n) n=(n or ""):lower() return n:find("spas") or n:find("shotgun") or false end

local WepList, WepNames = {}, {}
local function ExtractID(tool)
	for _,c in ipairs(tool:GetDescendants()) do if c:IsA("StringValue") and c.Value and #c.Value==36 then return c.Value end end
	for _,v in pairs(tool:GetAttributes()) do if type(v)=="string" and #v==36 then return v end end
	return #tool.Name==36 and tool.Name or nil
end

local currentWeaponName = "无"
local currentWeaponID = "无"

local function ScanWeapons()
	local ids, names = {}, {}
	local function AddTool(t)
		local id = ExtractID(t)
		if id then ids[id]=true; names[id]=(t:GetAttribute("Name") or t.Name):lower() end
	end
	local bp = player:FindFirstChild("Backpack")
	if bp then for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then AddTool(t) end end end
	if player.Character then for _,t in ipairs(player.Character:GetChildren()) do if t:IsA("Tool") then AddTool(t) end end end
	WepList={}; WepNames={}
	for id in pairs(ids) do table.insert(WepList, id); WepNames[id]=names[id] end
	if player.Character then
		for _,t in ipairs(player.Character:GetChildren()) do
			if t:IsA("Tool") then
				currentWeaponName = t:GetAttribute("Name") or t.Name
				currentWeaponID = ExtractID(t) or "?"
				return #WepList
			end
		end
	end
	currentWeaponName = "无"; currentWeaponID = "无"
	return #WepList
end

local function GetEquippedTool()
	if player.Character then
		for _, c in ipairs(player.Character:GetChildren()) do
			if c:IsA("Tool") then
				return c
			end
		end
	end
	return nil
end

local function GetEquippedWeaponName()
	local tool = GetEquippedTool()
	if not tool then return nil end
	return (tool:GetAttribute("Name") or tool.Name):lower()
end

local function HasRanged()

	local equipped = GetEquippedWeaponName()
	if equipped and IsRanged(equipped) then
		return true, IsShotgun(equipped)
	end

	for _,id in ipairs(WepList) do
		if IsRanged(WepNames[id]) then
			return true, IsShotgun(WepNames[id])
		end
	end
	return false, false
end

local function HasMelee()
	local equipped = GetEquippedWeaponName()
	if equipped and IsMelee(equipped) then return true end
	for _,id in ipairs(WepList) do if IsMelee(WepNames[id]) then return true end end return false
end

local function HookChar(char)
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then ScanWeapons() end
	end)
	char.ChildRemoved:Connect(function(c)
		if c:IsA("Tool") then ScanWeapons() end
	end)
end

local bp = player:FindFirstChild("Backpack")
if bp then
	bp.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then ScanWeapons() end
	end)
end

player.CharacterAdded:Connect(function(char)
	HookChar(char)
	ScanWeapons()
	task.spawn(function()
		task.wait(0.1)
		ScanWeapons()
		if drawCircle then pcall(CreateCircle) end
	end)
end)

if player.Character then
	HookChar(player.Character)
	ScanWeapons()
end

local ignoreCache = { list = {}, char = nil, backpack = nil, dirty = true }

local function MarkIgnoreDirty()
	ignoreCache.dirty = true
end

local function BuildIgnore()
	if not ignoreCache.dirty then
		return ignoreCache.list
	end

	local ig = ignoreCache.list
	table.clear(ig)

	local char = player.Character
	if char then
		if ignoreCache.char ~= char then
			ignoreCache.char = char
			char.DescendantAdded:Connect(MarkIgnoreDirty)
			char.DescendantRemoving:Connect(MarkIgnoreDirty)
		end
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then
				table.insert(ig, p)
			end
		end
	end

	local bp2 = player:FindFirstChild("Backpack")
	if bp2 then
		if ignoreCache.backpack ~= bp2 then
			ignoreCache.backpack = bp2
			bp2.ChildAdded:Connect(MarkIgnoreDirty)
			bp2.ChildRemoved:Connect(MarkIgnoreDirty)
		end
		for _, t in ipairs(bp2:GetChildren()) do
			if t:IsA("Tool") then
				table.insert(ig, t)
				for _, c in ipairs(t:GetDescendants()) do
					if c:IsA("BasePart") then
						table.insert(ig, c)
					end
				end
			end
		end
	end

	ignoreCache.dirty = false
	return ig
end

player.CharacterAdded:Connect(MarkIgnoreDirty)

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.IgnoreWater = true

local function HasLineOfSight(from, char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	losParams.FilterDescendantsInstances = BuildIgnore()
	local dir = (hrp.Position - from).Unit
	local dist = (hrp.Position - from).Magnitude
	local result = Workspace:Raycast(from, dir * dist, losParams)
	if not result then return true end
	return char:IsAncestorOf(result.Instance) or result.Instance:FindFirstAncestorOfClass("Model") == char
end

local function GetEnemies()
	local out, hrp = {}, player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return out end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and not isWL(p) and p.Character then
			local ph = p.Character:FindFirstChild("HumanoidRootPart")
			local hu = p.Character:FindFirstChildOfClass("Humanoid")
			if ph and hu and hu.Health > 0 then
				if invincibleCheck and IsInvincibleCached(p) then continue end
				local d = (ph.Position - hrp.Position).Magnitude
				if d <= MAX_RANGE then
					local enemy = IsEnemy(p)
					if not enemy and not DCLASS[myRole] and IsHostile(p) then enemy = true end
					if not enemy and not DCLASS[myRole] and IsEscaped(p) then enemy = true end
					if enemy and (not rayEnabled or HasLineOfSight(hrp.Position, p.Character)) then
						table.insert(out, { player = p, char = p.Character, hrp = ph, dist = d })
					end
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.dist < b.dist end)
	return out
end

local function GetMeleeTargets()
	local out, hrp = {}, player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return out end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and not isWL(p) and p.Character then
			local ph = p.Character:FindFirstChild("HumanoidRootPart")
			local hu = p.Character:FindFirstChildOfClass("Humanoid")
			if ph and hu and hu.Health > 0 and (ph.Position - hrp.Position).Magnitude <= MELEE_RANGE then
				if invincibleCheck and IsInvincibleCached(p) then continue end
				local enemy = IsEnemy(p)
				if not enemy and not DCLASS[myRole] and IsHostile(p) then enemy = true end
				if not enemy and not DCLASS[myRole] and IsEscaped(p) then enemy = true end
				if enemy then table.insert(out, { player = p, char = p.Character, hrp = ph }) end
			end
		end
	end
	return out
end

local BEAM_COLOR = Color3.fromRGB(255, 183, 197)
local BEAM_LIFETIME = 0.5
local MAX_ACTIVE_BEAMS = 30
local MAX_POOL_SIZE = 60
local activeBeams = {}
local beamPool = {}
local beamSpawnCount = 0

local function GetBeamPart()

	if #beamPool > 0 then
		local p = table.remove(beamPool)
		if p and not p.Parent then
			return p
		elseif p then

			pcall(function() p:Destroy() end)
		end
	end

	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = BEAM_COLOR
	p.Size = Vector3.new(0.06, 0.06, 1)
	return p
end

local function RecycleBeamPart(p)
	beamSpawnCount = math.max(0, beamSpawnCount - 1)
	if p and p.Parent then
		p.Parent = nil
	end

	if #beamPool >= MAX_POOL_SIZE then
		pcall(function() p:Destroy() end)
		return
	end
	p.Transparency = 0.1
	table.insert(beamPool, p)
end

local function CleanDeadBeams()
	local cleaned = 0
	for i = #activeBeams, 1, -1 do
		local beam = activeBeams[i]
		if not beam or not beam.Parent then
			table.remove(activeBeams, i)
			cleaned = cleaned + 1
		end
	end
	return cleaned
end

local function DrawBulletTrail(from, to)
	if not drawBeams then return end

	if #activeBeams >= MAX_ACTIVE_BEAMS then return end
	if beamSpawnCount >= MAX_ACTIVE_BEAMS * 2 then return end

	local dir = to - from
	local dist = dir.Magnitude
	if dist < 0.5 then return end

	local part = GetBeamPart()
	part.CFrame = CFrame.new((from + to) / 2, to)
	part.Size = Vector3.new(0.06, 0.06, dist)
	part.Material = Enum.Material.Neon
	part.Color = BEAM_COLOR
	part.Transparency = 0.1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = Workspace

	table.insert(activeBeams, part)
	beamSpawnCount = beamSpawnCount + 1

	task.spawn(function()
		task.wait(BEAM_LIFETIME)
		RecycleBeamPart(part)
		for i = #activeBeams, 1, -1 do
			if activeBeams[i] == part then
				table.remove(activeBeams, i)
				break
			end
		end
	end)
end

local CircleParts = {}
local circleValid = false
local MAX_CIRCLE_PARTS = 22

local function DestroyCircle()
	for _, p in ipairs(CircleParts) do
		pcall(function()
			if p and p.Parent then p:Destroy() end
		end)
	end
	table.clear(CircleParts)
	circleValid = false
end

local function CreateCircle()

	DestroyCircle()

	if not drawCircle then return end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	for i = 1, MAX_CIRCLE_PARTS do
		local a = (i / MAX_CIRCLE_PARTS) * math.pi * 2
		local pt = Instance.new("Part")
		pt.Anchored = true; pt.CanCollide = false; pt.CastShadow = false
		pt.Material = Enum.Material.Neon; pt.Color = Color3.fromRGB(231, 235, 241); pt.Transparency = 0.547
		pt.Size = Vector3.new(0.077, 0.007, 0.072)
		pt.CFrame = CFrame.new(hrp.Position + Vector3.new(math.cos(a) * MELEE_RANGE, -0.009, math.sin(a) * MELEE_RANGE))
		pt.Parent = Workspace
		table.insert(CircleParts, pt)
	end
	circleValid = true
end

local function UpdateCircle()
	if not drawCircle then DestroyCircle(); return end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then DestroyCircle(); return end

	if not circleValid or #CircleParts ~= MAX_CIRCLE_PARTS then
		CreateCircle()
		return
	end
	for i, pt in ipairs(CircleParts) do

		if not pt or not pt.Parent then
			circleValid = false
			CreateCircle()
			return
		end
		local a = (i / #CircleParts) * math.pi * 2
		pt.CFrame = CFrame.new(hrp.Position + Vector3.new(math.cos(a) * MELEE_RANGE, -0.010, math.sin(a) * MELEE_RANGE))
	end
end

local function GetMuzzlePos(id)
	local cam = Workspace:FindFirstChild("Camera")
	if not cam then return nil end
	local w = cam:FindFirstChild(id)
	local pts = w and w:FindFirstChild("Points")
	local m = pts and pts:FindFirstChild("Muzzle")
	return m and m.WorldPosition or nil
end

local function BuildShotData(org, aim, hitPart, spread)
	spread = spread or Vector3.zero
	local aimPos = aim + spread
	local dir = (aimPos - org).Unit * 8300
	return {
		normal = Vector3.new(0, 1, 0),
		direction = dir,
		origin = org,
		instance = hitPart,
		points = {},
		position = aimPos
	}
end

local function FireRanged(tgt)
	if funMode then
		if SoundEvent then
			for _, id in ipairs(WepList) do
				if IsRanged(WepNames[id]) then
					pcall(function() SoundEvent:FireServer(id, "FIRE") end)
				end
			end
		end
		return
	end

	local head = tgt.char:FindFirstChild("Head")
	local aim = (head or tgt.hrp).Position
	local org = nil
	local wepIsShotgun = false
	for _, id in ipairs(WepList) do
		if IsRanged(WepNames[id]) then
			if IsShotgun(WepNames[id]) then wepIsShotgun = true end
			if not org then org = GetMuzzlePos(id) end
		end
	end
	if not org then
		local h = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		org = h and (h.Position + Vector3.new(math.random(-50, 50) / 10, math.random(-28, 48) / 10, math.random(-60, 60) / 10)) or aim + Vector3.new(0, 2.376, 0)
	end

	if drawBeams then
		DrawBulletTrail(org, aim)
	end

	local shots = {}
	local pelletCount = wepIsShotgun and 8 or 1

	for i = 1, pelletCount do
		local spread = Vector3.zero
		if wepIsShotgun and i > 1 then
			spread = Vector3.new(
					math.random(-15, 15) / 100,
					math.random(-10, 10) / 100,
					math.random(-15, 15) / 100
				)
		end
		table.insert(shots, BuildShotData(org, aim, head or tgt.hrp, spread))
	end

	if ShootEvent then
		for _, id in ipairs(WepList) do
			if IsRanged(WepNames[id]) then
				pcall(function() ShootEvent:FireServer(id, shots) end)
				if not silentMode and SoundEvent then
					pcall(function() SoundEvent:FireServer(id, "FIRE") end)
				end
			end
		end
	end
end

local meleeInProgress = false

local function FireMelee(tgts)
	if #tgts == 0 then return end
	if meleeInProgress then return end
	meleeInProgress = true

	task.spawn(function()
		local cam = Workspace:FindFirstChild("Camera")
		if not cam then meleeInProgress = false; return end

		local meleeIDs = {}
		for _, id in ipairs(WepList) do
			if IsMelee(WepNames[id]) then
				table.insert(meleeIDs, id)
			end
		end

		if #meleeIDs == 0 then
			meleeInProgress = false
			return
		end

		local maxTargets = math.min(#tgts, 3)

		for _, id in ipairs(meleeIDs) do
			local cw = cam:FindFirstChild(id)
			if not cw then
				task.wait(0.015)
				cw = cam:FindFirstChild(id)
			end

			if cw and AttackEvent then
				for ti = 1, maxTargets do
					local tgt = tgts[ti]
					if tgt and tgt.char and tgt.char.Parent then
						pcall(function()
							AttackEvent:FireServer(id, { tgt.char, cw })
						end)
						if ti < maxTargets then
							task.wait(0.010)
						end
					end
				end
			end

			if id ~= meleeIDs[#meleeIDs] then
				task.wait(MELEE_INTERVAL)
			end
		end

		meleeInProgress = false
	end)
end

local RoleNames = {
	scientist = "科学家", security = "安保", mtf = "机动特遣队", director = "主管",
	d_class = "D级人员", escaped_d = "逃脱D级", escaped_d_class = "逃脱D级",
	chaos_insurgency = "混沌分裂者", rogue_agent = "叛变特工",
	traitor = "叛徒", renegade = "反叛者", anomaly = "异常实体",
}
local RoleColors = {
	scientist = Color3.fromRGB(97, 162, 204),
	security = Color3.fromRGB(170, 175, 185),
	mtf = Color3.fromRGB(52, 110, 218),
	director = Color3.fromRGB(108, 197, 109),
	d_class = Color3.fromRGB(255, 175, 40),
	escaped_d = Color3.fromRGB(255, 175, 40),
	escaped_d_class = Color3.fromRGB(255, 175, 40),
	chaos_insurgency = Color3.fromRGB(220, 180, 30),
	rogue_agent = Color3.fromRGB(220, 180, 30),
	traitor = Color3.fromRGB(220, 180, 30),
	renegade = Color3.fromRGB(220, 180, 30),
	anomaly = Color3.fromRGB(121, 119, 124),
	Default = Color3.fromRGB(162, 165, 173),
}

local ESP = {}
local charPartsCache = setmetatable({}, { __mode = "kv" })

local allConnections = {}

local function TrackConnection(conn)
	table.insert(allConnections, conn)
	return conn
end

local function GetCharParts(char)
	local cached = charPartsCache[char]
	if cached then

		local valid = true
		for i = 1, math.min(#cached, 3) do
			if not cached[i] or not cached[i].Parent then
				valid = false
				break
			end
		end
		if valid then
			return cached
		end

		charPartsCache[char] = nil
	end
	local parts = {}
	for _, part in ipairs(char:GetDescendants()) do
		if not part:IsA("BasePart") then continue end
		if part.Name == "HumanoidRootPart" then continue end
		local parent = part.Parent
		if parent and parent:IsA("Accessory") then continue end
		if part.Transparency >= 0.936 then continue end
		table.insert(parts, part)
	end
	charPartsCache[char] = parts
	return parts
end

local function CleanESP(p)
	if ESP[p] then
		pcall(function()
			if ESP[p].sg and ESP[p].sg.Parent then ESP[p].sg:Destroy() end
		end)

		if ESP[p].connections then
			for _, conn in ipairs(ESP[p].connections) do
				pcall(function() conn:Disconnect() end)
			end
		end
		ESP[p] = nil
	end
	if p.Character then
		charPartsCache[p.Character] = nil
	end
	ClearInvincible(p)
end

local function MakeESP(p)
	if p == player or ESP[p] then return end

	local charConns = {}

	table.insert(charConns, TrackConnection(p.CharacterAdded:Connect(function(char)
		charPartsCache[char] = nil
		task.wait(0.3)
		CleanESP(p)
		task.spawn(function() MakeESP(p) end)
	end)))

	table.insert(charConns, TrackConnection(p.CharacterRemoving:Connect(function(char)
		charPartsCache[char] = nil
		CleanESP(p)
	end)))

	task.spawn(function()
		local char = p.Character or p.CharacterAdded:Wait()
		local hrp = char:WaitForChild("HumanoidRootPart", 5)
		local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
		if not hrp or not hum then return end

		if ESP[p] then return end

		local sg = Instance.new("ScreenGui")
		sg.Name = "ESP_" .. p.Name
		sg.ResetOnSpawn = false; sg.Enabled = true
		sg.IgnoreGuiInset = true; sg.DisplayOrder = 109
		sg.Parent = player:WaitForChild("PlayerGui")

		local box = Instance.new("Frame")
		box.Name = "Box"; box.BackgroundTransparency = 1; box.BorderSizePixel = 0; box.Parent = sg

		local stroke = Instance.new("UIStroke"); stroke.Thickness = 2; stroke.Parent = box

		local grad = Instance.new("UIGradient")
		grad.Rotation = 94; grad.Parent = stroke

		local hpBg = Instance.new("Frame")
		hpBg.Name = "HpBg"; hpBg.Size = UDim2.new(0, 4, 1, 0)
		hpBg.Position = UDim2.new(1, 3, 0, 0)
		hpBg.BackgroundColor3 = Color3.fromRGB(49, 51, 56); hpBg.BackgroundTransparency = 0.269; hpBg.BorderSizePixel = 0; hpBg.Parent = box
		Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 2)

		local hpFill = Instance.new("Frame")
		hpFill.Name = "HpFill"; hpFill.AnchorPoint = Vector2.new(0.5, 1)
		hpFill.Size = UDim2.new(1, 0, 1, 0); hpFill.Position = UDim2.new(0.5, 0, 1, 0)
		hpFill.BackgroundColor3 = Color3.fromRGB(32, 164, 56); hpFill.BorderSizePixel = 0; hpFill.Parent = hpBg
		Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 2)

		local distL = Instance.new("TextLabel")
		distL.Name = "Dist"; distL.BackgroundTransparency = 1
		distL.Size = UDim2.new(1, 0, 0, 14)
		distL.Position = UDim2.new(0, 0, 1, 2)
		distL.TextColor3 = Color3.fromRGB(204, 210, 216); distL.Font = Enum.Font.GothamBold
		distL.TextSize = 10; distL.TextXAlignment = Enum.TextXAlignment.Left; distL.Text = ""; distL.Parent = box

		local espData = { sg = sg, Box = box, Stroke = stroke, Grad = grad, HpBg = hpBg, HpFill = hpFill, Dist = distL, Hum = hum, Char = char, HRP = hrp, connections = {} }
		ESP[p] = espData

		table.insert(espData.connections, TrackConnection(hum.HealthChanged:Connect(function(hp)
			if not hpFill or not hpFill.Parent then return end
			local isInv = IsInvincibleCached(p)
			if isInv then
				hpFill.Size = UDim2.new(1, 0, 1, 0)
				hpFill.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
				hpFill.BackgroundTransparency = 0
			else
				local r = math.clamp(hp / math.max(hum.MaxHealth, 1), 0, 1)
				hpFill.Size = UDim2.new(1, 0, r, 0)
				hpFill.BackgroundColor3 = r > 0.463 and Color3.fromRGB(28, 146, 62) or r > 0.263 and Color3.fromRGB(198, 144, 39) or Color3.fromRGB(202, 46, 46)
				hpFill.BackgroundTransparency = 0
			end
		end)))

		table.insert(espData.connections, TrackConnection(hum.Died:Connect(function()
			CleanESP(p)
		end)))

		table.insert(espData.connections, TrackConnection(char.ChildAdded:Connect(function()
			charPartsCache[char] = nil
		end)))

		table.insert(espData.connections, TrackConnection(char.ChildRemoved:Connect(function()
			charPartsCache[char] = nil
		end)))

		for _, c in ipairs(charConns) do
			table.insert(espData.connections, c)
		end
	end)
end

for _, p in ipairs(Players:GetPlayers()) do task.spawn(function() pcall(MakeESP, p) end) end
TrackConnection(Players.PlayerAdded:Connect(function(p) task.wait(0.3); pcall(MakeESP, p) end))
TrackConnection(Players.PlayerRemoving:Connect(function(p) pcall(CleanESP, p) end))

local function ComputeBoundingBox(char, cam)
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local any = false
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local head = char:FindFirstChild("Head")
	if not hrp then return nil end

	local points = { hrp.Position }
	if head then table.insert(points, head.Position) end
	table.insert(points, hrp.Position + Vector3.new(0, 3.5, 0))
	table.insert(points, hrp.Position - Vector3.new(0, 2.5, 0))

	local rightVec = cam.CFrame.RightVector * 1.2
	table.insert(points, hrp.Position + rightVec)
	table.insert(points, hrp.Position - rightVec)

	for _, v in ipairs(points) do
		local sp, onScreen = cam:WorldToViewportPoint(v)
		if onScreen then
			any = true
			if sp.X < minX then minX = sp.X end
			if sp.Y < minY then minY = sp.Y end
			if sp.X > maxX then maxX = sp.X end
			if sp.Y > maxY then maxY = sp.Y end
		end
	end

	if not any then return nil end
	return minX, minY, maxX, maxY
end

local ESP_FRAME_BUDGET = 3

RunService.RenderStepped:Connect(function()
	if not espEnabled then
		for p, d in pairs(ESP) do if d.sg then d.sg.Enabled = false end end
		return
	end

	local cam = Workspace.CurrentCamera
	if not cam then return end

	local sw = cam.ViewportSize.X
	local sh = cam.ViewportSize.Y
	local margin = 2
	local cf = cam.CFrame
	local camPos = cf.Position

	for p, d in pairs(ESP) do

		if not d.sg or not d.sg.Parent then CleanESP(p); continue end
		if not d.Char or not d.Char.Parent then CleanESP(p); continue end
		if not d.HRP or not d.HRP.Parent then CleanESP(p); continue end

		local hrp = d.HRP
		local hrpPos = hrp.Position

		local sp1, onScreen1 = cam:WorldToViewportPoint(hrpPos)
		if not onScreen1 or sp1.Z > 1 then
			d.sg.Enabled = false
			d.Box.Visible = false
			if d.Dist then d.Dist.Visible = false end
			continue
		end

		local distFromCam = (camPos - hrpPos).Magnitude
		if distFromCam > 2000 then
			d.sg.Enabled = false
			d.Box.Visible = false
			if d.Dist then d.Dist.Visible = false end
			continue
		end

		d.sg.Enabled = true
		if d.Dist then d.Dist.Visible = true end

		local head = d.Char:FindFirstChild("Head")

		local topPos = hrpPos + Vector3.new(0, 3.5, 0)
		local bottomPos = hrpPos - Vector3.new(0, 2.5, 0)

		local sp2 = cam:WorldToViewportPoint(topPos)
		local sp3 = cam:WorldToViewportPoint(bottomPos)

		local rightOffset = cam.CFrame.RightVector * 1.2
		local spR = cam:WorldToViewportPoint(hrpPos + rightOffset)
		local spL = cam:WorldToViewportPoint(hrpPos - rightOffset)

		local minX = math.min(sp1.X, sp2.X, sp3.X, spR.X, spL.X)
		local maxX = math.max(sp1.X, sp2.X, sp3.X, spR.X, spL.X)
		local minY = math.min(sp1.Y, sp2.Y, sp3.Y)
		local maxY = math.max(sp1.Y, sp2.Y, sp3.Y)

		minX = math.max(0, minX - margin)
		minY = math.max(0, minY - margin)
		maxX = math.min(sw, maxX + margin)
		maxY = math.min(sh, maxY + margin)
		local w, h = maxX - minX, maxY - minY

		if w < 4 or h < 4 or minX >= sw or maxX <= 0 or minY >= sh or maxY <= 0 then
			d.Box.Visible = false
			if d.Dist then d.Dist.Visible = false end
		else
			d.Box.Visible = true
			d.Box.Position = UDim2.new(0, minX, 0, minY)
			d.Box.Size = UDim2.new(0, w, 0, h)

			if math.floor(tick() * 20) ~= d._lastColorTick then
				d._lastColorTick = math.floor(tick() * 20)

				local role = GetRole(p)
				local col = RoleColors[role] or RoleColors.Default
				d.Stroke.Color = col

				local dim = Color3.new(0, 0, 0)
				d.Grad.Color = ColorSequence.new {
					ColorSequenceKeypoint.new(0, col),
					ColorSequenceKeypoint.new(0.35, col:Lerp(dim, 0.20)),
					ColorSequenceKeypoint.new(0.70, col:Lerp(dim, 0.45)),
					ColorSequenceKeypoint.new(1, col:Lerp(dim, 0.70)),
				}

				local isInv = IsInvincibleCached(p)
				if isInv then
					d.HpFill.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
					d.HpFill.BackgroundTransparency = 0
					d.HpFill.Size = UDim2.new(1, 0, 1, 0)
				else
					local hp = d.Hum and d.Hum.Health or 0
					local maxHp = d.Hum and d.Hum.MaxHealth or 100
					local r = math.clamp(hp / math.max(maxHp, 1), 0, 1)
					d.HpFill.Size = UDim2.new(1, 0, r, 0)
					d.HpFill.BackgroundTransparency = 0
					d.HpFill.BackgroundColor3 = r > 0.463 and Color3.fromRGB(28, 146, 62)
							or r > 0.263 and Color3.new(198, 144, 39)
							or Color3.fromRGB(202, 46, 46)
				end

				local dist = (camPos - hrpPos).Magnitude
				d.Dist.Text = string.format("%.0fm", dist)
			end
		end
	end
end)

local DoorSys = {
	Enabled = false,
	Range = 12,
	Parts = {},
	Orig = {},
}

local DOOR_SCAN_INTERVAL = 0.1
local DOOR_CLEAN_INTERVAL = 3.0

local function ScanDoors()
	local map = Workspace:FindFirstChild("Map")
	if not map then return 0 end
	local doors = map:FindFirstChild("Doors")
	if not doors then return 0 end

	local c = 0
	local DEPTH_LIMIT = 5
	local function Rec(o, depth)
		if depth > DEPTH_LIMIT then return end
		if o:IsA("BasePart") and not DoorSys.Parts[o] then
			DoorSys.Parts[o] = true
			DoorSys.Orig[o] = o.CanCollide
			c = c + 1
		end
		if c > 1000 then return end
		for _, ch in ipairs(o:GetChildren()) do
			Rec(ch, depth + 1)
		end
	end
	Rec(doors, 0)
	return c
end

local function CleanDeadDoors()
	local deadKeys = {}
	for pt in pairs(DoorSys.Parts) do
		if not pt or not pt.Parent then
			table.insert(deadKeys, pt)
		end
	end
	for _, pt in ipairs(deadKeys) do
		DoorSys.Parts[pt] = nil
		DoorSys.Orig[pt] = nil
	end
	return #deadKeys
end

local function RemoveNearbyDoors()
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return 0 end
	local px, py, pz = hrp.Position.X, hrp.Position.Y, hrp.Position.Z
	local rangeSq = DoorSys.Range * DoorSys.Range
	local count = 0
	for pt in pairs(DoorSys.Parts) do
		if pt and pt.Parent then
			local dx, dy, dz = pt.Position.X - px, pt.Position.Y - py, pt.Position.Z - pz
			if dx * dx + dy * dy + dz * dz <= rangeSq then
				if DoorSys.Orig[pt] == nil then
					DoorSys.Orig[pt] = pt.CanCollide
				end
				if pt.CanCollide then
					pt.CanCollide = false
					count = count + 1
				end
			else
				local orig = DoorSys.Orig[pt]
				if orig ~= nil and pt.CanCollide ~= orig then
					pt.CanCollide = orig
				end
			end
		else
			DoorSys.Parts[pt] = nil
			DoorSys.Orig[pt] = nil
		end
	end
	return count
end

local function RestoreAllDoors()
	local count = 0
	for pt in pairs(DoorSys.Parts) do
		if pt and pt.Parent then
			local orig = DoorSys.Orig[pt]
			if orig ~= nil and pt.CanCollide ~= orig then
				pt.CanCollide = orig
				count = count + 1
			end
		end
	end
	DoorSys.Parts = {}
	DoorSys.Orig = {}
	return count
end

local DoorCount = ScanDoors()

task.spawn(function()
	local lastClean = 0
	while true do
		task.wait(DOOR_SCAN_INTERVAL)
		if DoorSys.Enabled then
			RemoveNearbyDoors()
		else
			for pt in pairs(DoorSys.Parts) do
				if pt and pt.Parent then
					local orig = DoorSys.Orig[pt]
					if orig ~= nil and pt.CanCollide ~= orig then
						pt.CanCollide = orig
					end
				end
			end
		end

		local now = tick()
		if now - lastClean > DOOR_CLEAN_INTERVAL then
			lastClean = now
			local cleaned = CleanDeadDoors()
			if cleaned > 0 then
				DoorCount = 0
				for _ in pairs(DoorSys.Parts) do DoorCount = DoorCount + 1 end
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(30)
		if DoorSys.Enabled then
			local newCount = ScanDoors()
			if newCount > DoorCount then
				DoorCount = newCount
			end
		end
	end
end)

local autoFarm = false
local farmRunning = false

local SPAWN_CHECK_POS = Vector3.new(1223.6483154296875, 176.08985900878906, -1192.4896240234375)
local SPAWN_RADIUS = 50
local FARM_TELEPORT = Vector3.new(1208.21240234375, 133.37843322753906, -677.5913696289062)

local FARM_DELAY_BEFORE_TP = 3.0
local FARM_TP_COOLDOWN = 0.5
local FARM_KEY_HOLD = 0.08
local FARM_KEY_GAP = 0.05
local FARM_AFTER_KEYS = 0.3
local FARM_CHECK_INTERVAL = 0.2
local FARM_ESCAPE_TIMEOUT = 10.0
local FARM_DEATH_DELAY = 1.0
local FARM_REBIRTH_WAIT = 2.0
local FARM_MAX_RETRY = 30

local function GetMyHRP()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart") or nil
end
local function GetMyHumanoid()
	return player.Character and player.Character:FindFirstChildOfClass("Humanoid") or nil
end
local function KillMySelf()
	local hum = GetMyHumanoid()
	if not hum then return false end
	pcall(function() hum.Health = 0 end)
	return true
end
local function SelectDClass()
	if RoleEvent then
		pcall(function() RoleEvent:FireServer("d_class") end)
	end
end
local function TeleportTo(pos)
	local hrp = GetMyHRP()
	if not hrp then return false end
	hrp.CFrame = CFrame.new(pos)
	return true
end
local function IsNearSpawnPoint()
	local hrp = GetMyHRP()
	if not hrp then return false end
	return (hrp.Position - SPAWN_CHECK_POS).Magnitude < SPAWN_RADIUS
end

local function PressKey(keyCode, times)
	times = times or 1
	for i = 1, times do
		pcall(function()
			VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
		end)
		task.wait(FARM_KEY_HOLD)
		pcall(function()
			VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
		end)
		if i < times then task.wait(FARM_KEY_GAP) end
	end
end

local PathfindingService = game:GetService("PathfindingService")
local FARM_MOVE_TIMEOUT = 8.0
local FARM_MOVE_REACH_DISTANCE = 4.0

local function MoveToPosition(targetPos)
	local hum = GetMyHumanoid()
	local hrp = GetMyHRP()
	if not hum or not hrp then return false end

	if hum.Health <= 0 then return false end
	if hum.Sit then hum.Sit = false end
	if hum.PlatformStand then hum.PlatformStand = false end

	local direction = (targetPos - hrp.Position)
	direction = Vector3.new(direction.X, 0, direction.Z)
	local distance = direction.Magnitude

	if distance < FARM_MOVE_REACH_DISTANCE then
		return true
	end

	local path
	local success, err = pcall(function()
		path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			AgentMaxSlope = 45,
		})
		path:ComputeAsync(hrp.Position, targetPos)
	end)

	if not success or not path or path.Status ~= Enum.PathStatus.Success then

		local moveDir = direction.Unit
		local stepSize = 5
		local totalMoved = 0
		local start = tick()

		while totalMoved < distance and (tick() - start) < FARM_MOVE_TIMEOUT do
			if not autoFarm then return false end

			local hum2 = GetMyHumanoid()
			local hrp2 = GetMyHRP()
			if not hum2 or not hrp2 or hum2.Health <= 0 then return false end

			local stepTarget = hrp2.Position + moveDir * math.min(stepSize, distance - totalMoved)
			hum2:MoveTo(stepTarget)

			local stepStart = tick()
			while (tick() - stepStart) < 1.5 do
				if not autoFarm then return false end
				local hrp3 = GetMyHRP()
				if not hrp3 then break end
				local distToStep = (hrp3.Position - stepTarget).Magnitude
				if distToStep < FARM_MOVE_REACH_DISTANCE then break end
				task.wait(0.05)
			end

			local newHrp = GetMyHRP()
			if newHrp then
				totalMoved = totalMoved + stepSize

				if (newHrp.Position - hrp.Position).Magnitude < 0.5 then
					break
				end
			end
		end
		return true
	end

	local waypoints = path:GetWaypoints()
	if #waypoints == 0 then

		local moveDir = direction.Unit
		hum:Move(moveDir)
		task.wait(0.5)
		hum:Move(Vector3.zero)
		return true
	end

	local start = tick()
	for i, wp in ipairs(waypoints) do
		if not autoFarm then return false end

		local hum2 = GetMyHumanoid()
		local hrp2 = GetMyHRP()
		if not hum2 or not hrp2 or hum2.Health <= 0 then return false end

		if (tick() - start) > FARM_MOVE_TIMEOUT then break end

		hum2:MoveTo(wp.Position)

		local wpStart = tick()
		while (tick() - wpStart) < 2.0 do
			if not autoFarm then return false end
			local hrp3 = GetMyHRP()
			if not hrp3 then break end
			local dist = (hrp3.Position - wp.Position).Magnitude
			if dist < FARM_MOVE_REACH_DISTANCE then break end
			task.wait(0.05)
		end

		if i == #waypoints then break end
	end

	hum:Move(Vector3.zero)
	return true
end

local function MoveForwardBackward(forwardDist, backwardDist)
	local hrp = GetMyHRP()
	local hum = GetMyHumanoid()
	if not hrp or not hum then return end

	task.wait(0.3)

	hrp = GetMyHRP()
	hum = GetMyHumanoid()
	if not hrp or not hum or hum.Health <= 0 then return end

	if hum.Sit then hum.Sit = false end
	if hum.PlatformStand then hum.PlatformStand = false end

	local cf = hrp.CFrame
	local lookDir = cf.LookVector
	lookDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit

	if forwardDist and forwardDist > 0 then
		local targetPos = hrp.Position + lookDir * forwardDist
		MoveToPosition(targetPos)
	end

	task.wait(0.2)

	if backwardDist and backwardDist > 0 then
		hrp = GetMyHRP()
		hum = GetMyHumanoid()
		if hrp and hum and hum.Health > 0 then
			local targetPos = hrp.Position - lookDir * backwardDist
			MoveToPosition(targetPos)
		end
	end

	hum = GetMyHumanoid()
	if hum then hum:Move(Vector3.zero) end
end

local function WaitForDeath(timeout)
	timeout = timeout or 8
	local start = tick()
	while player.Character and (tick() - start) < timeout do
		task.wait(0.1)
	end
	task.wait(0.8)
	return true
end

local function WaitForCharacter(timeout)
	timeout = timeout or 15
	local start = tick()
	local char = player.Character
	while not char and (tick() - start) < timeout do
		task.wait(0.1)
		char = player.Character
	end
	if not char then return false end

	local hrp = nil
	local hrpWait = 0
	while not hrp and hrpWait < 8 do
		task.wait(0.1)
		hrpWait = hrpWait + 0.1
		hrp = char:FindFirstChild("HumanoidRootPart")
	end
	if not hrp then return false end

	local hum = nil
	local humWait = 0
	while not hum and humWait < 8 do
		task.wait(0.1)
		humWait = humWait + 0.1
		hum = char:FindFirstChildOfClass("Humanoid")
	end
	if not hum then return false end

	local healthWait = 0
	while hum.Health <= 0 and healthWait < 8 do
		task.wait(0.1)
		healthWait = healthWait + 0.1
	end
	if hum.Health <= 0 then return false end

	return true
end

local function WaitForRole(timeout)
	timeout = timeout or 12
	local start = tick()
	while (tick() - start) < timeout do
		if myRole and myRole ~= "" then
			return myRole
		end
		task.wait(0.2)
	end
	return nil
end

local function FullRespawnAsDClass()
	local MAX_TIME = 30
	local start = tick()

	local hum = GetMyHumanoid()
	if hum and hum.Health > 0 then
		pcall(function() hum.Health = 0 end)
	end

	local deathWait = 0
	while player.Character and deathWait < 10 do
		task.wait(0.1)
		deathWait = deathWait + 0.1
	end
	task.wait(0.8)

	if (tick() - start) > MAX_TIME then return false end

	SelectDClass()

	local char = nil
	local charWait = 0
	while not char and charWait < 15 do
		task.wait(0.2)
		charWait = charWait + 0.2
		char = player.Character
	end
	if not char then return false end

	if (tick() - start) > MAX_TIME then return false end

	local charOk = WaitForCharacter(15)
	if not charOk then return false end

	if (tick() - start) > MAX_TIME then return false end

	local role = WaitForRole(15)
	if role ~= "d_class" then
		SelectDClass()
		task.wait(1.0)
		role = myRole
	end
	if role ~= "d_class" then return false end

	task.wait(1.0)

	return true
end

local function CheckSelfEscaped()
	return IsEscaped(player)
end

local function FarmLoop()
	if farmRunning then return end
	farmRunning = true

	local retryCount = 0

	while autoFarm do
		if not IsNearSpawnPoint() then
			retryCount = retryCount + 1
			if retryCount > FARM_MAX_RETRY then break end
			local ok = FullRespawnAsDClass()
			if not ok then
				task.wait(2.0)
			else
				retryCount = 0
			end
			continue
		end

		local char = player.Character
		local hum = GetMyHumanoid()
		local alive = hum and hum.Health > 0
		local hasRole = myRole and myRole ~= ""

		if not alive or not hasRole then
			retryCount = retryCount + 1
			if retryCount > FARM_MAX_RETRY then break end
			local ok = FullRespawnAsDClass()
			if not ok then task.wait(2.0) else retryCount = 0 end
			continue
		end

		if myRole ~= "d_class" then
			KillMySelf()
			task.wait(FARM_REBIRTH_WAIT)
			continue
		end

		retryCount = 0

		if CheckSelfEscaped() then
			task.wait(FARM_DEATH_DELAY)
			KillMySelf()
			task.wait(FARM_REBIRTH_WAIT)
			continue
		end

		task.wait(FARM_DELAY_BEFORE_TP)

		hum = GetMyHumanoid()
		if not hum or hum.Health <= 0 then
			task.wait(FARM_REBIRTH_WAIT)
			continue
		end
		if CheckSelfEscaped() then
			task.wait(FARM_DEATH_DELAY)
			KillMySelf()
			task.wait(FARM_REBIRTH_WAIT)
			continue
		end

		local tpOk = TeleportTo(FARM_TELEPORT)
		if not tpOk then
			task.wait(0.5)
			continue
		end

		task.wait(0.5)

		local hrp = GetMyHRP()
		local hum = GetMyHumanoid()
		if not hrp or not hum or hum.Health <= 0 then
			task.wait(0.5)
			continue
		end

		if hum.Sit then hum.Sit = false end
		if hum.PlatformStand then hum.PlatformStand = false end

		task.wait(FARM_TP_COOLDOWN)

		MoveForwardBackward(6, 4)
		task.wait(FARM_AFTER_KEYS)

		local checkStart = tick()
		local escaped = false
		while (tick() - checkStart) < FARM_ESCAPE_TIMEOUT do
			hum = GetMyHumanoid()
			if not hum or hum.Health <= 0 then
				task.wait(FARM_REBIRTH_WAIT)
				break
			end
			if CheckSelfEscaped() then
				escaped = true
				break
			end
			task.wait(FARM_CHECK_INTERVAL)
		end

		if escaped then
			task.wait(FARM_DEATH_DELAY)
			KillMySelf()
			task.wait(FARM_REBIRTH_WAIT)
		else
			KillMySelf()
			task.wait(FARM_REBIRTH_WAIT)
		end
	end

	farmRunning = false
end

ScanWeapons()
local LastShoot, LastMelee = 0, 0
local shootCountThisFrame = 0

local FRAME_BUDGET_MS = 4

RunService.Heartbeat:Connect(function()
	local frameStart = tick()
	shootCountThisFrame = 0

	if autoFarm and farmRunning then
		pcall(UpdateCircle)
		return
	end

	if autoMelee and HasMelee() and (tick() - LastMelee) >= MELEE_CD then

		if (tick() - frameStart) * 1000 < FRAME_BUDGET_MS then
			local t = GetMeleeTargets()
			if #t > 0 then
				FireMelee(t)
				LastMelee = tick()
			end
		end
	end

	if autoShoot and (tick() - LastShoot) >= SHOOT_CD and shootCountThisFrame < MAX_SHOOTS_PER_FRAME then

		if (tick() - frameStart) * 1000 < FRAME_BUDGET_MS then
			local hasR, isSG = HasRanged()
			if hasR then
				local e = GetEnemies()
				if #e > 0 then
					FireRanged(e[1])
					LastShoot = tick()
					shootCountThisFrame = shootCountThisFrame + 1
				end
			end
		end
	end

	pcall(UpdateCircle)
end)
for _, p in ipairs(Players:GetPlayers()) do
	p.CharacterAdded:Connect(function()
		charPartsCache[p.Character] = nil
	end)
	p.CharacterRemoving:Connect(function()
		if p.Character then
			charPartsCache[p.Character] = nil
		end
	end)
end
Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(function()
		charPartsCache[p.Character] = nil
	end)
	p.CharacterRemoving:Connect(function()
		if p.Character then
			charPartsCache[p.Character] = nil
		end
	end)
end)

local function Unload()
	autoFarm = false
	autoShoot = false
	espEnabled = false

	for _, conn in ipairs(allConnections) do
		pcall(function() conn:Disconnect() end)
	end
	allConnections = {}

	pcall(function()
		local pg = player:FindFirstChild("PlayerGui")
		if pg then
			local sg = pg:FindFirstChild("SCPAnomalySite")
			if sg then sg:Destroy() end
		end
	end)

	for p in pairs(ESP) do CleanESP(p) end
	ESP = {}

	RestoreAllDoors()

	pcall(DestroyCircle)

	for _, b in ipairs(activeBeams) do
		if b and b.Parent then pcall(function() b:Destroy() end) end
	end
	activeBeams = {}
	for _, p in ipairs(beamPool) do
		if p and p.Parent then pcall(function() p:Destroy() end) end
	end
	beamPool = {}
	beamSpawnCount = 0

	ignoreCache = { list = {}, char = nil, backpack = nil, dirty = true }
	charPartsCache = setmetatable({}, { __mode = "kv" })
	DoorSys.Parts = {}
	DoorSys.Orig = {}
	invincibleUntil = setmetatable({}, { __mode = "k" })
	meleeInProgress = false

	for _, p in ipairs(CircleParts) do
		pcall(function()
			if p and p.Parent then p:Destroy() end
		end)
	end
	CircleParts = {}

end
local CombatTab = Window:AddTab("战斗", "crosshair")
local cL = CombatTab:AddLeftGroupbox("自动功能", "power")
local cR = CombatTab:AddRightGroupbox("参数", "sliders-horizontal")
cL:AddToggle("scpShoot", { Text = "自动射击", Default = false, Callback = function(v) autoShoot = v end })
cL:AddToggle("scpMelee", { Text = "自动近战", Default = false, Callback = function(v) autoMelee = v end })
cL:AddToggle("scpRay", { Text = "视线检测", Default = false, Callback = function(v) rayEnabled = v end })
cL:AddToggle("scpBeam", { Text = "弹道特效", Default = false, Callback = function(v) drawBeams = v end })
cL:AddToggle("scpCircle", { Text = "脚底圆圈", Default = false, Callback = function(v) drawCircle = v; if not v then pcall(DestroyCircle) end end })
cL:AddToggle("scpEscD", { Text = "攻击逃脱D级", Default = false, Callback = function(v) attackEscapedD = v end })
cL:AddToggle("scpInv", { Text = "无敌检测", Default = true, Callback = function(v) invincibleCheck = v end })
cR:AddSlider("scpRange", { Text = "射击距离", Default = MAX_RANGE, Min = 50, Max = 2000, Rounding = 0, Suffix = " studs", Callback = function(v) MAX_RANGE = v end })
cR:AddSlider("scpMeleeR", { Text = "近战范围", Default = MELEE_RANGE, Min = 2, Max = 20, Rounding = 0, Callback = function(v) MELEE_RANGE = v; pcall(DestroyCircle); if drawCircle then pcall(CreateCircle) end end })
cR:AddSlider("scpCd", { Text = "射击冷却", Default = SHOOT_CD, Min = 0.012, Max = 1, Rounding = 3, Suffix = " s", Callback = function(v) SHOOT_CD = v end })
cR:AddButton({ Text = "立即扫描武器", Func = function() pcall(ScanWeapons); Library:Notify("已扫描武器", 3) end })
local EspTab = Window:AddTab("透视", "eye")
local eL = EspTab:AddLeftGroupbox("ESP", "eye")
eL:AddToggle("scpEsp", {
	Text = "ESP透视",
	Default = false,
	Callback = function(v)
		espEnabled = v
		if v then
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= player then
					task.spawn(function() pcall(MakeESP, p) end)
				end
			end
		else
			for p in pairs(ESP) do
				pcall(CleanESP, p)
			end
		end
	end,
})
local FunTab = Window:AddTab("娱乐", "smile")
local fL = FunTab:AddLeftGroupbox("娱乐功能", "zap")
local fR = FunTab:AddRightGroupbox("刷钱", "dollar-sign")
fL:AddToggle("scpFun", { Text = "娱乐模式", Default = false, Callback = function(v) funMode = v end })
fL:AddToggle("scpSilent", { Text = "静默模式", Default = false, Callback = function(v) silentMode = v end })
fL:AddToggle("scpDoor", { Text = "穿门", Default = false, Callback = function(v) DoorSys.Enabled = v; if not v then pcall(RestoreAllDoors) end end })
fR:AddToggle("scpFarm", { Text = "自动刷钱", Default = false, Callback = function(v) autoFarm = v; if v and not farmRunning then task.spawn(FarmLoop) end end })
fR:AddButton({ Text = "全量卸载", Func = function() pcall(Unload); Library:Notify("已卸载", 3) end })
local WlTab = Window:AddTab("白名单", "shield")
local wL = WlTab:AddLeftGroupbox("白名单管理", "user")
wL:AddInput("scpWl", { Text = "添加白名单", Default = "", Placeholder = "输入玩家名", Finished = true, Callback = function(v) if v and v ~= "" then addWL(v) end end })
wL:AddButton({ Text = "清空白名单", Func = function() for n in pairs(WL) do WL[n] = nil end; Library:Notify("白名单已清空", 3) end })
Library:Notify("SCP 功能已加载", 3)
end
