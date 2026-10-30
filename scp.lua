return function(Library, Window)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer
local Libraries = ReplicatedStorage:FindFirstChild("Libraries")
local Network = Libraries and Libraries:FindFirstChild("Network")
local Channel = Network and Network:FindFirstChild("Channel")
local ShootEvent = Channel and Channel:FindFirstChild("tool/shoot")
local AttackEvent = Channel and Channel:FindFirstChild("tool/attack")
local SoundEvent = Channel and Channel:FindFirstChild("tool/sound")
local MAX_RANGE = 271
local MELEE_RANGE = 8
local SHOOT_CD = 0.087
local MELEE_CD = 0.150
local MELEE_INTERVAL = 0.035
local autoShoot = false
local autoMelee = false
local rayEnabled = false
local drawCircle = false
local attackEscapedD = false
local espEnabled = false
local funMode = false
local silentMode = false
local invincibleCheck = false
local drawBeams = false
local phaseDoor = false
local autoFarm = false
local unloaded = false
local FOUNDATION = { scientist = true, security = true, mtf = true, director = true }
local CHAOS = { chaos_insurgency = true, rogue_agent = true, traitor = true, renegade = true }
local DCLASS = { d_class = true, escaped_d = true, escaped_d_class = true }
local roleMap = {
scientist = "科学家", security = "安保", mtf = "机动特遣队", director = "主管",
d_class = "D级人员", escaped_d = "逃脱D级", escaped_d_class = "逃脱D级",
chaos_insurgency = "混沌分裂者", rogue_agent = "叛变特工", traitor = "叛徒",
renegade = "反叛者", anomaly = "异常实体",
}
local roleColors = {
["D级人员"] = {Color3.fromRGB(255,142,105), Color3.fromRGB(220,175,110)},
["安保"] = {Color3.fromRGB(225,227,231), Color3.fromRGB(165,168,174)},
["机动特遣队"] = {Color3.fromRGB(112,162,252), Color3.fromRGB(176,208,254)},
["混沌分裂者"] = {Color3.fromRGB(255,210,76), Color3.fromRGB(243,227,165)},
["科学家"] = {Color3.fromRGB(146,213,238), Color3.fromRGB(201,237,251)},
["异常实体"] = {Color3.fromRGB(44,43,45), Color3.fromRGB(89,88,91)},
["主管"] = {Color3.fromRGB(151,240,152), Color3.fromRGB(198,252,199)},
["Default"] = {Color3.fromRGB(204,206,210), Color3.fromRGB(104,106,108)}
}
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
local s, v = pcall(function() return h.Visible end)
return s and v or false
end
local function IsEscaped(p)
local w = GetTagWrapper(p)
if not w then return false end
local e = w:FindFirstChild("Escaped")
if not e then return false end
local s, v = pcall(function() return e.Visible end)
return s and v or false
end
local invincibleUntil = {}
local forceFieldState = {}
local function CheckForceFieldExists(p)
if not p then return false end
local wsModel = Workspace:FindFirstChild(p.Name)
if wsModel then
if wsModel:FindFirstChild("Forcefield") then return true end
if wsModel:FindFirstChild("ForceField") then return true end
for _, child in ipairs(wsModel:GetChildren()) do
if child:IsA("ForceField") then return true end
if child:FindFirstChild("Forcefield") then return true end
if child:FindFirstChild("ForceField") then return true end
end
end
if p.Character then
if p.Character:FindFirstChild("Forcefield") then return true end
if p.Character:FindFirstChild("ForceField") then return true end
for _, desc in ipairs(p.Character:GetDescendants()) do
if desc.Name == "Forcefield" or desc.Name == "ForceField" then
if desc:IsA("ForceField") or desc:IsA("BasePart") or desc:IsA("Folder") then return true end
end
end
end
return false
end
local function MarkInvincible(p)
invincibleUntil[p] = tick() + 5.0
forceFieldState[p] = true
end
local function ClearInvincible(p)
invincibleUntil[p] = nil
forceFieldState[p] = false
end
local function IsInvincibleCached(p)
if not invincibleCheck then return false end
if invincibleUntil[p] and tick() < invincibleUntil[p] then return true end
return false
end
local MeleeNames = { "knife", "crowbar", "tomahawk", "hammer", "bat", "sword", "axe", "machete", "fists", "combat", "blade", "spear", "dagger" }
local RangedNames = { "glock", "beretta", "mp5", "ak47", "hk416", "spas-12", "awm", "m249", "deagle", "uzi", "rifle", "shotgun", "pistol" }
local function IsMelee(n) n = (n or ""):lower() for _, k in ipairs(MeleeNames) do if n:find(k) then return true end end return false end
local function IsRanged(n) n = (n or ""):lower() for _, k in ipairs(RangedNames) do if n:find(k) then return true end end return false end
local function IsShotgun(n) n = (n or ""):lower() return n:find("spas") or n:find("shotgun") or false end
local WepList, WepNames = {}, {}
local function ExtractID(tool)
for _, c in ipairs(tool:GetDescendants()) do if c:IsA("StringValue") and c.Value and #c.Value == 36 then return c.Value end end
for _, v in pairs(tool:GetAttributes()) do if type(v) == "string" and #v == 36 then return v end end
return #tool.Name == 36 and tool.Name or nil
end
local currentWeaponName = "无"
local currentWeaponID = "无"
local function ScanWeapons()
local ids, names = {}, {}
local function AddTool(t)
local id = ExtractID(t)
if id then ids[id] = true; names[id] = (t:GetAttribute("Name") or t.Name):lower() end
end
local bp = player:FindFirstChild("Backpack")
if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then AddTool(t) end end end
if player.Character then for _, t in ipairs(player.Character:GetChildren()) do if t:IsA("Tool") then AddTool(t) end end end
WepList = {}; WepNames = {}
for id in pairs(ids) do table.insert(WepList, id); WepNames[id] = names[id] end
if player.Character then
for _, t in ipairs(player.Character:GetChildren()) do
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
local function HasRanged()
local has = false
for _, id in ipairs(WepList) do if IsRanged(WepNames[id]) then has = true; break end end
return has
end
local function HasMelee()
for _, id in ipairs(WepList) do if IsMelee(WepNames[id]) then return true end end
return false
end
local weaponScanScheduled = false
local function ScheduleWeaponScan()
if weaponScanScheduled then return end
weaponScanScheduled = true
task.delay(0.05, function()
weaponScanScheduled = false
ScanWeapons()
end)
end
local function HookChar(char)
char.ChildAdded:Connect(function(c) if c:IsA("Tool") then ScheduleWeaponScan() end end)
char.ChildRemoved:Connect(function(c) if c:IsA("Tool") then ScheduleWeaponScan() end end)
end
local ignoreList = nil
local IGNORE_TTL = 0.1
local function BuildIgnore()
if ignoreList and tick() < ignoreList.expire then return ignoreList.list end
local ig = {}
local char = player.Character
if char then for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then table.insert(ig, p) end end end
local bp2 = player:FindFirstChild("Backpack")
if bp2 then
for _, t in ipairs(bp2:GetChildren()) do
if t:IsA("Tool") then
table.insert(ig, t)
for _, c in ipairs(t:GetDescendants()) do if c:IsA("BasePart") then table.insert(ig, c) end end
end
end
end
ignoreList = { list = ig, expire = tick() + IGNORE_TTL }
return ig
end
local function ClearIgnoreCache() ignoreList = nil end
local function HasLineOfSight(from, char)
local hrp = char:FindFirstChild("HumanoidRootPart")
if not hrp then return false end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = BuildIgnore()
params.IgnoreWater = true
local dir = (hrp.Position - from).Unit
local dist = (hrp.Position - from).Magnitude
local result = Workspace:Raycast(from, dir * dist, params)
if not result then return true end
return char:IsAncestorOf(result.Instance) or result.Instance:FindFirstAncestorOfClass("Model") == char
end
local function GetEnemies()
local out = {}
local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return out end
for _, p in ipairs(Players:GetPlayers()) do
if p ~= player and not isWL(p) and p.Character then
local ph = p.Character:FindFirstChild("HumanoidRootPart")
local hu = p.Character:FindFirstChildOfClass("Humanoid")
if ph and hu and hu.Health > 0 then
if not (invincibleCheck and IsInvincibleCached(p)) then
local d = (ph.Position - hrp.Position).Magnitude
if d <= MAX_RANGE then
local tr = GetRole(p)
local sameTeam = false
if myRole and tr then
if (DCLASS[myRole] and DCLASS[tr]) or (FOUNDATION[myRole] and FOUNDATION[tr]) or (CHAOS[myRole] and CHAOS[tr]) then sameTeam = true end
end
if not sameTeam then
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
end
end
table.sort(out, function(a, b) return a.dist < b.dist end)
return out
end
local function GetMeleeTargets()
local out = {}
local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return out end
for _, p in ipairs(Players:GetPlayers()) do
if p ~= player and not isWL(p) and p.Character then
local ph = p.Character:FindFirstChild("HumanoidRootPart")
local hu = p.Character:FindFirstChildOfClass("Humanoid")
if ph and hu and hu.Health > 0 and (ph.Position - hrp.Position).Magnitude <= MELEE_RANGE then
if not (invincibleCheck and IsInvincibleCached(p)) then
local tr = GetRole(p)
local sameTeam = false
if myRole and tr then
if (DCLASS[myRole] and DCLASS[tr]) or (FOUNDATION[myRole] and FOUNDATION[tr]) or (CHAOS[myRole] and CHAOS[tr]) then sameTeam = true end
end
if not sameTeam then
local enemy = IsEnemy(p)
if not enemy and not DCLASS[myRole] and IsHostile(p) then enemy = true end
if not enemy and not DCLASS[myRole] and IsEscaped(p) then enemy = true end
if enemy then table.insert(out, { player = p, char = p.Character, hrp = ph }) end
end
end
end
end
end
return out
end
local BEAM_COLOR = Color3.fromRGB(255, 183, 197)
local BEAM_LIFETIME = 0.5
local MAX_BEAMS = 40
local activeBeams = {}
local beamPool = {}
local function GetBeamPart()
for i = #beamPool, 1, -1 do
local p = beamPool[i]
if p and not p.Parent then table.remove(beamPool, i); return p end
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
if #beamPool < 60 then table.insert(beamPool, p) end
end
local function CleanOldBeams()
while #activeBeams > MAX_BEAMS do
local old = table.remove(activeBeams, 1)
if old and old.Parent then old:Destroy() end
end
end
local function DrawBulletTrail(from, to)
if not drawBeams or silentMode then return end
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
CleanOldBeams()
task.delay(BEAM_LIFETIME, function()
if part.Parent then
part.Parent = nil
RecycleBeamPart(part)
end
for i = #activeBeams, 1, -1 do
if activeBeams[i] == part then table.remove(activeBeams, i); break end
end
end)
end
local function GetMuzzlePos(id)
local cam = Workspace:FindFirstChild("Camera")
if not cam then return nil end
local obj = cam:FindFirstChild(id)
if not obj then return nil end
local pts = obj:FindFirstChild("Points")
local mz = pts and pts:FindFirstChild("Muzzle")
if mz and mz:IsA("BasePart") then return mz.Position end
return nil
end
local function FireRanged(t)
local head = t.char:FindFirstChild("Head")
local aimPoint = (head or t.hrp).Position
local origin = nil
for _, id in ipairs(WepList) do
if IsRanged(WepNames[id]) then
local mp = GetMuzzlePos(id)
if mp then origin = mp; break end
end
end
if not origin then
local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if hrp then
origin = hrp.Position + Vector3.new(0, 1.63, 0) + Vector3.new(math.random(-10, 10) / 10, math.random(-5, 10) / 10, math.random(-10, 10) / 10)
else
origin = t.hrp.Position + Vector3.new(0, 2.54, 0)
end
end
local base = aimPoint - origin
if base.Magnitude < 0.001 then return end
local unit = base.Unit
for _, id in ipairs(WepList) do
if IsRanged(WepNames[id]) then
local shots = {}
if IsShotgun(WepNames[id]) then
for i = 1, 8 do
local sp = Vector3.new(math.random(-100, 100) / 1000, math.random(-100, 100) / 1000, math.random(-100, 100) / 1000)
shots[#shots + 1] = { normal = Vector3.new(0, 1, 0), direction = (unit + sp).Unit * 9550, origin = origin, instance = head or t.hrp, points = {}, position = aimPoint }
end
else
shots[#shots + 1] = { normal = Vector3.new(0, 1, 0), direction = unit * 9550, origin = origin, instance = head or t.hrp, points = {}, position = aimPoint }
end
pcall(function() ShootEvent:FireServer(id, shots) end)
pcall(function() SoundEvent:FireServer(id, "FIRE") end)
end
end
DrawBulletTrail(origin, aimPoint)
end
local lastMelee = 0
local function FireMelee(targets)
if #targets == 0 then return end
local now = tick()
if now - lastMelee < MELEE_CD then return end
lastMelee = now
local cam = Workspace:FindFirstChild("Camera")
if not cam then return end
local tc = targets[1].char
for _, id in ipairs(WepList) do
if IsMelee(WepNames[id]) then
local cw = cam:FindFirstChild(id)
if not cw then
task.wait(0.003)
cw = cam:FindFirstChild(id)
end
if cw then
pcall(function() AttackEvent:FireServer(id, { tc, cw }) end)
if MELEE_INTERVAL > 0 then task.wait(MELEE_INTERVAL) end
end
end
end
end
local circleParts = {}
local function DestroyCircle()
for _, part in ipairs(circleParts) do pcall(function() part:Destroy() end) end
circleParts = {}
end
local function CreateCircle()
DestroyCircle()
if not drawCircle or silentMode then return end
local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return end
local segments = 48
local radius = MELEE_RANGE
local center = hrp.Position
for i = 1, segments do
local angle = (i / segments) * math.pi * 2
local x = center.X + math.cos(angle) * radius
local z = center.Z + math.sin(angle) * radius
local part = Instance.new("Part")
part.Name = "MeleeCircleSegment"
part.Anchored = true
part.CanCollide = false
part.CastShadow = false
part.Material = Enum.Material.Neon
part.Color = Color3.fromRGB(255, 105, 180)
part.Transparency = 0.4
part.Size = Vector3.new(0.09, 0.02, 0.09)
part.CFrame = CFrame.new(x, center.Y - 0.037, z)
part.Parent = Workspace
table.insert(circleParts, part)
end
end
local function UpdateCircle()
if unloaded then return end
if not drawCircle or silentMode then
if #circleParts > 0 then DestroyCircle() end
return
end
local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if not hrp then
if #circleParts > 0 then DestroyCircle() end
return
end
local valid = true
for _, part in ipairs(circleParts) do
if not part or not part.Parent then valid = false; break end
end
if not valid or #circleParts == 0 then
CreateCircle()
return
end
local center = hrp.Position
local radius = MELEE_RANGE
local segments = #circleParts
for i, part in ipairs(circleParts) do
local angle = (i / segments) * math.pi * 2
local x = center.X + math.cos(angle) * radius
local z = center.Z + math.sin(angle) * radius
part.CFrame = CFrame.new(x, center.Y - 0.039, z)
end
end
local doorParts = {}
local doorOrig = {}
local function CollectDoors()
doorParts = {}
for _, d in ipairs(Workspace:GetDescendants()) do
if d:IsA("BasePart") and d.Name:lower():find("door") then
table.insert(doorParts, d)
if doorOrig[d] == nil then doorOrig[d] = d.CanCollide end
end
end
end
local function DoorLoop()
while true do
task.wait(0.25)
if unloaded then break end
if phaseDoor then
pcall(function()
local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return end
for _, d in ipairs(doorParts) do
if d and d.Parent then
local dist = (d.Position - hrp.Position).Magnitude
if dist <= 12 then
d.CanCollide = false
elseif doorOrig[d] ~= nil then
d.CanCollide = doorOrig[d]
end
end
end
end)
else
for d, orig in pairs(doorOrig) do
if d and d.Parent and orig ~= nil then pcall(function() d.CanCollide = orig end) end
end
end
end
end
local espObjs = {}
local function CleanESP(p)
if espObjs[p] then
if espObjs[p].gui and espObjs[p].gui.Parent then espObjs[p].gui:Destroy() end
espObjs[p] = nil
end
end
local function CreateESP(p)
if p == player or espObjs[p] then return end
task.spawn(function()
local ok = pcall(function()
local ch = p.Character or p.CharacterAdded:Wait()
local hrp = ch:WaitForChild("HumanoidRootPart", 5)
local hum = ch:FindFirstChildOfClass("Humanoid") or ch:WaitForChild("Humanoid", 5)
if not hrp or not hum then return end
local gui = Instance.new("BillboardGui")
gui.Name = "ESP_" .. p.Name
gui.Adornee = hrp
gui.Size = UDim2.new(0, 150, 0, 220)
gui.StudsOffset = Vector3.new(0, 1.5, 0)
gui.AlwaysOnTop = true
gui.MaxDistance = 900
gui.Enabled = false
gui.Parent = hrp
local box = Instance.new("Frame")
box.Size = UDim2.new(0.5, 0, 0.62, 0)
box.Position = UDim2.new(0.25, 0, 0.3, 0)
box.BackgroundTransparency = 1
box.BorderSizePixel = 0
box.Parent = gui
local grad = Instance.new("UIGradient")
grad.Rotation = 308
grad.Parent = box
local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Parent = box
for i = 1, 4 do
local isR = (i == 2 or i == 4)
local isB = (i == 3 or i == 4)
local h = Instance.new("Frame")
h.Size = UDim2.new(0.28, 0, 0.05, 0)
h.Position = UDim2.new(isR and 0.72 or 0, 0, isB and 0.95 or 0, 0)
h.BackgroundColor3 = Color3.new(1, 1, 1)
h.BorderSizePixel = 0
h.Parent = box
local v = Instance.new("Frame")
v.Size = UDim2.new(0.05, 0, 0.28, 0)
v.Position = UDim2.new(isR and 0.95 or 0, 0, isB and 0.72 or 0, 0)
v.BackgroundColor3 = Color3.new(1, 1, 1)
v.BorderSizePixel = 0
v.Parent = box
end
local hpBg = Instance.new("Frame")
hpBg.Size = UDim2.new(0.1, 0, 0.62, 0)
hpBg.Position = UDim2.new(0.76, 0, 0.3, 0)
hpBg.BackgroundColor3 = Color3.fromRGB(29, 27, 28)
hpBg.BackgroundTransparency = 0.3
hpBg.BorderSizePixel = 0
hpBg.Parent = gui
local hpFill = Instance.new("Frame")
hpFill.Size = UDim2.new(1, 0, 1, 0)
hpFill.AnchorPoint = Vector2.new(0, 1)
hpFill.Position = UDim2.new(0, 0, 1, 0)
hpFill.BackgroundColor3 = Color3.fromRGB(41, 196, 67)
hpFill.BorderSizePixel = 0
hpFill.Parent = hpBg
espObjs[p] = { gui = gui, box = box, grad = grad, stroke = stroke, hpFill = hpFill, hum = hum, char = ch }
end)
if not ok then espObjs[p] = nil end
end)
end
local farmTarget = nil
local lastTp = 0
local function PressKey(k, times)
for i = 1, times do
pcall(function() VirtualInputManager:SendKeyEvent(true, k, false, nil) end)
task.wait(0.05)
pcall(function() VirtualInputManager:SendKeyEvent(false, k, false, nil) end)
task.wait(0.05)
end
end
local function UnloadAll()
unloaded = true
pcall(DestroyCircle)
for _, b in ipairs(activeBeams) do pcall(function() b:Destroy() end) end
activeBeams = {}
for p in pairs(espObjs) do CleanESP(p) end
espObjs = {}
for d, orig in pairs(doorOrig) do
if d and d.Parent and orig ~= nil then pcall(function() d.CanCollide = orig end) end
end
doorOrig = {}
doorParts = {}
end
local CombatTab = Window:AddTab("战斗", "crosshair")
local cL = CombatTab:AddLeftGroupbox("自动功能", "power")
local cR = CombatTab:AddRightGroupbox("参数", "sliders-horizontal")
cL:AddToggle("scpShoot", { Text = "自动射击", Default = false, Callback = function(v) autoShoot = v end })
cL:AddToggle("scpMelee", { Text = "自动近战", Default = false, Callback = function(v) autoMelee = v end })
cL:AddToggle("scpRay", { Text = "视线检测", Default = false, Callback = function(v) rayEnabled = v end })
cL:AddToggle("scpBeam", { Text = "弹道特效", Default = false, Callback = function(v) drawBeams = v end })
cL:AddToggle("scpCircle", { Text = "脚底圆圈", Default = false, Callback = function(v) drawCircle = v; if drawCircle then pcall(CreateCircle) else pcall(DestroyCircle) end end })
cL:AddToggle("scpEscD", { Text = "攻击逃出D级", Default = false, Callback = function(v) attackEscapedD = v end })
cL:AddToggle("scpInv", { Text = "无敌检测", Default = false, Callback = function(v) invincibleCheck = v end })
cL:AddToggle("scpDoor", { Text = "穿门", Default = false, Callback = function(v) phaseDoor = v; if phaseDoor then pcall(CollectDoors) end end })
local statusLabel = cL:AddLabel("等待数据...")
cR:AddSlider("scpRange", { Text = "射击距离", Default = MAX_RANGE, Min = 50, Max = 1000, Rounding = 0, Suffix = " studs", Callback = function(v) MAX_RANGE = v end })
cR:AddSlider("scpMeleeRange", { Text = "近战范围", Default = MELEE_RANGE, Min = 2, Max = 20, Rounding = 0, Callback = function(v) MELEE_RANGE = v; pcall(CreateCircle) end })
cR:AddSlider("scpCd", { Text = "射击冷却", Default = SHOOT_CD, Min = 0.012, Max = 1, Rounding = 3, Suffix = " s", Callback = function(v) SHOOT_CD = v end })
cR:AddButton({ Text = "立即扫描武器", Func = function() pcall(ScanWeapons); Library:Notify("已扫描武器", 3) end })
local EspTab = Window:AddTab("透视", "eye")
local eL = EspTab:AddLeftGroupbox("ESP", "eye")
eL:AddToggle("scpEsp", { Text = "ESP透视", Default = false, Callback = function(v) espEnabled = v end })
local FunTab = Window:AddTab("娱乐", "smile")
local fL = FunTab:AddLeftGroupbox("娱乐模式", "smile")
local fR = FunTab:AddRightGroupbox("刷钱", "dollar-sign")
fL:AddToggle("scpFun", { Text = "娱乐模式", Default = false, Callback = function(v) funMode = v end })
fL:AddToggle("scpSilent", { Text = "静默模式", Default = false, Callback = function(v) silentMode = v end })
fR:AddToggle("scpFarm", { Text = "自动刷钱", Default = false, Callback = function(v) autoFarm = v end })
fR:AddButton({ Text = "设置传送点", Func = function()
local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if hrp then farmTarget = hrp.Position; Library:Notify("传送点已设置", 3) end
end })
local WLTab = Window:AddTab("白名单", "shield")
local wL = WLTab:AddLeftGroupbox("白名单管理", "user")
wL:AddInput("scpWlInput", { Text = "添加白名单", Default = "", Placeholder = "输入玩家名后回车", Finished = true, Callback = function(v) if v and v ~= "" then addWL(v) end end })
wL:AddButton({ Text = "清空白名单", Func = function() for n in pairs(WL) do WL[n] = nil end; Library:Notify("白名单已清空", 3) end })
wL:AddButton({ Text = "卸载脚本", Func = function() pcall(UnloadAll); Library:Notify("已卸载", 3) end })
player:GetAttributeChangedSignal("Role"):Connect(UpdateMyRole)
player.CharacterAdded:Connect(function(char)
ClearIgnoreCache()
HookChar(char)
ScanWeapons()
task.spawn(function()
task.wait(0.1)
ScanWeapons()
if drawCircle then pcall(CreateCircle) end
end)
end)
local bp = player:FindFirstChild("Backpack")
if bp then bp.ChildAdded:Connect(function(c) if c:IsA("Tool") then ScheduleWeaponScan() end end) end
if player.Character then HookChar(player.Character); ScanWeapons() end
Players.PlayerRemoving:Connect(function(p) ClearInvincible(p); forceFieldState[p] = nil; CleanESP(p) end)
Players.PlayerAdded:Connect(function(p) task.wait(0.5); CreateESP(p) end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(function() CreateESP(p) end) end
task.spawn(function()
while true do
task.wait(0.3)
if unloaded then break end
if not invincibleCheck then
for p in pairs(forceFieldState) do forceFieldState[p] = false end
invincibleUntil = {}
else
for _, p in ipairs(Players:GetPlayers()) do
if p ~= player then
if CheckForceFieldExists(p) then MarkInvincible(p) elseif forceFieldState[p] then ClearInvincible(p) end
end
end
end
end
end)
task.spawn(DoorLoop)
task.spawn(function()
while true do
task.wait(0.1)
if unloaded then break end
if funMode then
pcall(function()
local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if hrp then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(45), 0) end
end)
end
end
end)
task.spawn(function()
while true do
task.wait(0.25)
if unloaded then break end
if autoFarm and farmTarget then
pcall(function()
local ch = player.Character
local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
local hum = ch and ch:FindFirstChildOfClass("Humanoid")
if not hrp or not hum then return end
if IsEscaped(player) then hum.Health = 0; task.wait(2); return end
if myRole and DCLASS[myRole] then
local now = tick()
if now - lastTp >= 0.5 then
lastTp = now
hrp.CFrame = CFrame.new(farmTarget)
task.wait(0.1)
PressKey(Enum.KeyCode.S, 2)
PressKey(Enum.KeyCode.W, 2)
end
end
end)
end
end
end)
local lastShoot = 0
RunService.Heartbeat:Connect(function()
if unloaded then return end
pcall(function()
if not autoShoot then return end
local ch = player.Character
if not ch then return end
local hu = ch:FindFirstChildOfClass("Humanoid")
if not hu or hu.Health <= 0 then return end
if #WepList == 0 or not HasRanged() then return end
local now = tick()
if now - lastShoot < SHOOT_CD then return end
local list = GetEnemies()
if #list == 0 then return end
lastShoot = now
FireRanged(list[1])
end)
end)
RunService.Heartbeat:Connect(function()
if unloaded then return end
pcall(function()
if not autoMelee then return end
local ch = player.Character
if not ch then return end
local hu = ch:FindFirstChildOfClass("Humanoid")
if not hu or hu.Health <= 0 then return end
if #WepList == 0 or not HasMelee() then return end
local ts = GetMeleeTargets()
if #ts > 0 then FireMelee(ts) end
end)
end)
RunService.RenderStepped:Connect(function()
if unloaded then return end
pcall(UpdateCircle)
pcall(function()
for p, d in pairs(espObjs) do
if d.gui then
if espEnabled and not silentMode then
d.gui.Enabled = true
local role = GetRole(p) or "?"
local cn = roleMap[role] or role
local cols = roleColors[cn] or roleColors["Default"]
d.stroke.Color = cols[1]
d.grad.Color = ColorSequence.new(cols[1], cols[2])
if d.hum and d.hum.Parent then
local maxHp = d.hum.MaxHealth > 0 and d.hum.MaxHealth or 100
local ratio = math.clamp(d.hum.Health / maxHp, 0, 1)
d.hpFill.Size = UDim2.new(1, 0, ratio, 0)
if IsInvincibleCached(p) then
d.hpFill.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
elseif ratio > 0.585 then
d.hpFill.BackgroundColor3 = Color3.fromRGB(34, 188, 60)
elseif ratio > 0.283 then
d.hpFill.BackgroundColor3 = Color3.fromRGB(245, 194, 52)
else
d.hpFill.BackgroundColor3 = Color3.fromRGB(210, 48, 42)
end
end
else
d.gui.Enabled = false
end
end
end
end)
end)
task.spawn(function()
while true do
task.wait(1)
if unloaded then break end
pcall(function()
UpdateMyRole()
local enemies, friends, whitelisted = 0, 0, 0
for _, p in ipairs(Players:GetPlayers()) do
if p ~= player then
if isWL(p) then whitelisted = whitelisted + 1 elseif IsEnemy(p) then enemies = enemies + 1 else friends = friends + 1 end
end
end
if statusLabel then
pcall(function()
statusLabel:SetText(string.format("角色:%s\n友:%d 敌:%d 白:%d 武器:%d\n射程:%d 近战:%d\n装备:%s", tostring(myRole), friends, enemies, whitelisted, #WepList, MAX_RANGE, MELEE_RANGE, currentWeaponName))
end)
end
end)
end
end)
task.spawn(function()
while true do
task.wait(2)
if unloaded then break end
pcall(ScanWeapons)
end
end)
task.wait(1)
pcall(ScanWeapons)
pcall(CollectDoors)
Library:Notify("SCP 功能已加载（默认关闭）", 3)
end
