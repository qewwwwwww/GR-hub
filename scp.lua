return function(Library, Window)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local Libraries = ReplicatedStorage:WaitForChild("Libraries")
local Network = Libraries:WaitForChild("Network")
local Channel = Network:WaitForChild("Channel")
local ShootEvent = Channel:WaitForChild("tool/shoot")
local AttackEvent = Channel:WaitForChild("tool/attack")
local SoundEvent = Channel:WaitForChild("tool/sound")
local MAX_RANGE = 271
local MELEE_RANGE = 5
local SHOOT_CD = 0.087
local MELEE_CD = 0.45
local autoShoot = false
local autoMelee = false
local rayEnabled = false
local drawVis = false
local drawCircle = false
local attackEscapedD = false
local espEnabled = false
local silentMode = false
local FOUNDATION = { scientist = true, security = true, mtf = true, director = true }
local CHAOS = { chaos_insurgency = true, rogue_agent = true, traitor = true, renegade = true }
local DCLASS = { d_class = true, escaped_d = true, escaped_d_class = true }
local WL = {}
local function isWL(p) return p and WL[p.Name] or false end
local function addWL(n) if n and n ~= "" then WL[n] = true end end
local function rmWL(n) WL[n] = nil end
local myRole = nil
local function GetRole(p) return p and p:GetAttribute("Role") or nil end
local function UpdateMyRole()
local r = GetRole(player)
if r ~= myRole then myRole = r end
end
UpdateMyRole()
player:GetAttributeChangedSignal("Role"):Connect(UpdateMyRole)
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
local MeleeNames = { "knife", "crowbar", "tomahawk", "hammer", "bat", "sword", "axe", "machete" }
local RangedNames = { "glock", "beretta", "mp5", "ak47", "hk416", "spas-12", "awm", "m249", "deagle", "uzi", "rifle", "shotgun", "pistol" }
local function IsMelee(n) n = (n or ""):lower() for _, k in ipairs(MeleeNames) do if n:find(k) then return true end end return false end
local function IsRanged(n) n = (n or ""):lower() for _, k in ipairs(RangedNames) do if n:find(k) then return true end end return false end
local function IsShotgun(n) n = (n or ""):lower() return n:find("spas") or n:find("shotgun") or false end
local WepList, WepNames = {}, {}
local currentWeaponName = "无"
local function ExtractID(tool)
for _, c in ipairs(tool:GetDescendants()) do
if c:IsA("StringValue") and c.Value and #c.Value == 36 then return c.Value end
end
for _, v in pairs(tool:GetAttributes()) do
if type(v) == "string" and #v == 36 then return v end
end
return #tool.Name == 36 and tool.Name or nil
end
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
currentWeaponName = "无"
if player.Character then
for _, t in ipairs(player.Character:GetChildren()) do
if t:IsA("Tool") then
currentWeaponName = t:GetAttribute("Name") or t.Name
break
end
end
end
return #WepList
end
local function HasRanged()
for _, id in ipairs(WepList) do if IsRanged(WepNames[id]) then return true end end
return false
end
local function HasMelee()
for _, id in ipairs(WepList) do if IsMelee(WepNames[id]) then return true end end
return false
end
local function BuildIgnore()
local ig = {}
local char = player.Character
if char then
for _, p in ipairs(char:GetDescendants()) do
if p:IsA("BasePart") then table.insert(ig, p) end
end
for _, t in ipairs(char:GetChildren()) do
if t:IsA("Tool") then
table.insert(ig, t)
for _, c in ipairs(t:GetDescendants()) do
if c:IsA("BasePart") then table.insert(ig, c) end
end
end
end
end
local bp2 = player:FindFirstChild("Backpack")
if bp2 then
for _, t in ipairs(bp2:GetChildren()) do
if t:IsA("Tool") then
table.insert(ig, t)
for _, c in ipairs(t:GetDescendants()) do
if c:IsA("BasePart") then table.insert(ig, c) end
end
end
end
end
return ig
end
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
local d = (ph.Position - hrp.Position).Magnitude
if d <= MAX_RANGE then
local tr = GetRole(p)
local skip = false
if myRole and tr then
if (DCLASS[myRole] and DCLASS[tr]) or (FOUNDATION[myRole] and FOUNDATION[tr]) or (CHAOS[myRole] and CHAOS[tr]) then skip = true end
end
if not skip then
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
local tr = GetRole(p)
local skip = false
if myRole and tr then
if (DCLASS[myRole] and DCLASS[tr]) or (FOUNDATION[myRole] and FOUNDATION[tr]) or (CHAOS[myRole] and CHAOS[tr]) then skip = true end
end
if not skip then
local enemy = IsEnemy(p)
if not enemy and not DCLASS[myRole] and IsHostile(p) then enemy = true end
if not enemy and not DCLASS[myRole] and IsEscaped(p) then enemy = true end
if enemy then table.insert(out, { player = p, char = p.Character, hrp = ph }) end
end
end
end
end
return out
end
local CircleParts = {}
local function DestroyCircle()
for _, p in ipairs(CircleParts) do pcall(function() p:Destroy() end) end
CircleParts = {}
end
local function CreateCircle()
DestroyCircle()
if not drawCircle then return end
local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return end
for i = 1, 44 do
local a = (i / 44) * math.pi * 2
local pt = Instance.new("Part")
pt.Anchored = true
pt.CanCollide = false
pt.CastShadow = false
pt.Material = Enum.Material.Neon
pt.Color = Color3.fromRGB(231, 235, 241)
pt.Transparency = 0.547
pt.Size = Vector3.new(0.077, 0.007, 0.072)
pt.CFrame = CFrame.new(hrp.Position + Vector3.new(math.cos(a) * MELEE_RANGE, -0.009, math.sin(a) * MELEE_RANGE))
pt.Parent = Workspace
table.insert(CircleParts, pt)
end
end
local function UpdateCircle()
if not drawCircle then DestroyCircle(); return end
local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if not hrp then DestroyCircle(); return end
if #CircleParts == 0 then CreateCircle(); return end
for i, pt in ipairs(CircleParts) do
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
local shots = {}
local pelletCount = wepIsShotgun and 8 or 1
for i = 1, pelletCount do
local spread = Vector3.zero
if wepIsShotgun and i > 1 then
spread = Vector3.new(math.random(-15, 15) / 100, math.random(-10, 10) / 100, math.random(-15, 15) / 100)
end
table.insert(shots, BuildShotData(org, aim, head or tgt.hrp, spread))
end
if drawVis then
local beam = Instance.new("Part")
beam.Anchored = true
beam.CanCollide = false
beam.Material = Enum.Material.Neon
beam.Color = Color3.fromRGB(227, 233, 239)
beam.Transparency = 0.329
beam.Size = Vector3.new(0.035, 0.043, (aim - org).Magnitude)
beam.CFrame = CFrame.new(org, aim) * CFrame.new(0, 0, -beam.Size.Z / 2)
beam.Parent = Workspace
local hit = Instance.new("Part")
hit.Anchored = true
hit.CanCollide = false
hit.Material = Enum.Material.Neon
hit.Color = Color3.fromRGB(237, 242, 249)
hit.Transparency = 0.418
hit.Shape = Enum.PartType.Ball
hit.Size = Vector3.new(0.355, 0.347, 0.307)
hit.CFrame = CFrame.new(aim)
hit.Parent = Workspace
task.delay(0.745, function() pcall(function() beam:Destroy() end) pcall(function() hit:Destroy() end) end)
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
local function FireMelee(tgts)
if #tgts == 0 then return end
local cam = Workspace:FindFirstChild("Camera")
if not cam then return end
for _, id in ipairs(WepList) do
if IsMelee(WepNames[id]) then
local cw = cam:FindFirstChild(id)
if not cw then
task.wait(0.028)
cw = cam:FindFirstChild(id)
end
if cw and AttackEvent then
pcall(function() AttackEvent:FireServer(id, { tgts[1].char, cw }) end)
end
end
end
end
local RoleNames = {
scientist = "科学家", security = "安保", mtf = "机动特遣队", director = "主管",
d_class = "D级人员", escaped_d = "逃脱D级", escaped_d_class = "逃脱D级",
chaos_insurgency = "混沌分裂者", rogue_agent = "叛变特工", traitor = "叛徒",
renegade = "反叛者", anomaly = "异常实体",
}
local RoleColors = {
["D级人员"] = { Color3.fromRGB(255, 142, 105), Color3.fromRGB(220, 175, 110) },
["安保"] = { Color3.fromRGB(225, 227, 231), Color3.fromRGB(165, 168, 174) },
["机动特遣队"] = { Color3.fromRGB(112, 162, 252), Color3.fromRGB(176, 208, 254) },
["混沌分裂者"] = { Color3.fromRGB(255, 210, 76), Color3.fromRGB(243, 227, 165) },
["科学家"] = { Color3.fromRGB(146, 213, 238), Color3.fromRGB(201, 237, 251) },
["异常实体"] = { Color3.fromRGB(44, 43, 45), Color3.fromRGB(89, 88, 91) },
["主管"] = { Color3.fromRGB(151, 240, 152), Color3.fromRGB(198, 252, 199) },
["Default"] = { Color3.fromRGB(204, 206, 210), Color3.fromRGB(104, 106, 108) }
}
local ESP_BASE_W = 150
local ESP_BASE_H = 220
local espTable = {}
local function CleanESP(p)
if espTable[p] then
if espTable[p].Gui and espTable[p].Gui.Parent then
espTable[p].Gui:Destroy()
end
espTable[p] = nil
end
end
local function CreateESPForPlayer(p)
if p == player or espTable[p] then return end
p.CharacterAdded:Connect(function(ch)
task.wait(0.25)
CleanESP(p)
task.spawn(function() CreateESPForPlayer(p) end)
end)
p.CharacterRemoving:Connect(function() CleanESP(p) end)
task.spawn(function()
local char = p.Character or p.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart", 5)
local head = char:WaitForChild("Head", 5)
local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
if not hrp or not head or not hum then return end
local billboard = Instance.new("BillboardGui")
billboard.Name = "ESPGui_" .. p.Name
billboard.Adornee = hrp
billboard.Size = UDim2.new(0, ESP_BASE_W, 0, ESP_BASE_H)
billboard.StudsOffset = Vector3.new(0, 1.525, 0)
billboard.AlwaysOnTop = true
billboard.MaxDistance = 5500
billboard.Enabled = espEnabled
billboard.Parent = hrp
local boxFrame = Instance.new("Frame")
boxFrame.Size = UDim2.new(0.462, 0, 0.618, 0)
boxFrame.Position = UDim2.new(0.269, 0, 0.318, 0)
boxFrame.BackgroundTransparency = 0.844
boxFrame.BorderSizePixel = 0
boxFrame.Parent = billboard
local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(224, 218, 216)
stroke.Parent = boxFrame
local gradient = Instance.new("UIGradient")
gradient.Rotation = 308
gradient.Parent = boxFrame
local hpBg = Instance.new("Frame")
hpBg.Size = UDim2.new(0.095, 0, 0.614, 0)
hpBg.Position = UDim2.new(0.745, 0, 0.320, 0)
hpBg.BackgroundColor3 = Color3.fromRGB(29, 27, 28)
hpBg.BackgroundTransparency = 0.286
hpBg.BorderSizePixel = 0
hpBg.Parent = billboard
Instance.new("UICorner", hpBg).CornerRadius = UDim.new(0, 2)
local hpFill = Instance.new("Frame")
hpFill.Size = UDim2.new(1, 0, 1, 0)
hpFill.AnchorPoint = Vector2.new(0, 1)
hpFill.Position = UDim2.new(0, 0, 1, 0)
hpFill.BackgroundColor3 = Color3.fromRGB(41, 196, 67)
hpFill.BorderSizePixel = 0
hpFill.Parent = hpBg
Instance.new("UICorner", hpFill).CornerRadius = UDim.new(0, 2)
local hpGradient = Instance.new("UIGradient")
hpGradient.Rotation = 285
hpGradient.Parent = hpFill
espTable[p] = {
Gui = billboard,
Box = boxFrame,
Stroke = stroke,
Gradient = gradient,
HpFill = hpFill,
Hum = hum,
Char = char
}
hum.HealthChanged:Connect(function(health)
if hpFill and hpFill.Parent then
local maxHp = hum.MaxHealth > 0 and hum.MaxHealth or 100
local ratio = math.clamp(health / maxHp, 0, 1)
hpFill.Size = UDim2.new(1, 0, ratio, 0)
if ratio > 0.585 then
hpFill.BackgroundColor3 = Color3.fromRGB(34, 188, 60)
elseif ratio > 0.283 then
hpFill.BackgroundColor3 = Color3.fromRGB(245, 194, 52)
else
hpFill.BackgroundColor3 = Color3.fromRGB(210, 48, 42)
end
end
end)
end)
end
for _, p in ipairs(Players:GetPlayers()) do
task.spawn(function() CreateESPForPlayer(p) end)
end
Players.PlayerAdded:Connect(function(p)
task.wait(0.5)
CreateESPForPlayer(p)
end)
Players.PlayerRemoving:Connect(function(p)
CleanESP(p)
rmWL(p.Name)
end)
task.spawn(function()
while true do
task.wait(0.09)
if not espEnabled then
for p, data in pairs(espTable) do
if data.Gui then data.Gui.Enabled = false end
end
else
local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
for p, data in pairs(espTable) do
if data.Gui then
data.Gui.Enabled = true
local role = GetRole(p) or "?"
local roleCN = RoleNames[role] or role
local colors = RoleColors[roleCN] or RoleColors["Default"]
data.Stroke.Color = colors[1]
data.Gradient.Color = ColorSequence.new(colors[1], colors[2])
if myHRP and data.Char then
local targetHRP = data.Char:FindFirstChild("HumanoidRootPart")
if targetHRP then
local distance = (myHRP.Position - targetHRP.Position).Magnitude
local scaleFactor = math.clamp(1 - (distance - 10) / 570, 0.4, 1)
data.Gui.Size = UDim2.new(0, ESP_BASE_W * scaleFactor, 0, ESP_BASE_H * scaleFactor)
end
end
local char = p.Character
if not char or (data.Hum and data.Hum.Health <= 0) then
CleanESP(p)
end
end
end
end
end
end)
local CombatTab = Window:AddTab("战斗", "crosshair")
local cL = CombatTab:AddLeftGroupbox("自动功能", "power")
local cR = CombatTab:AddRightGroupbox("参数", "sliders-horizontal")
cL:AddToggle("scpShoot", {
Text = "自动射击",
Default = false,
Callback = function(v) autoShoot = v end,
})
cL:AddToggle("scpMelee", {
Text = "自动近战",
Default = false,
Callback = function(v) autoMelee = v end,
})
cL:AddToggle("scpRay", {
Text = "视线检测",
Default = false,
Callback = function(v) rayEnabled = v end,
})
cL:AddToggle("scpVis", {
Text = "弹道特效",
Default = false,
Callback = function(v) drawVis = v end,
})
cL:AddToggle("scpCircle", {
Text = "脚底圆圈",
Default = false,
Callback = function(v)
drawCircle = v
if drawCircle then pcall(CreateCircle) else pcall(DestroyCircle) end
end,
})
cL:AddToggle("scpDClass", {
Text = "攻击逃脱D级",
Default = false,
Callback = function(v) attackEscapedD = v end,
})
cL:AddToggle("scpSilent", {
Text = "静默音效",
Default = false,
Callback = function(v) silentMode = v end,
})
cL:AddToggle("scpEsp", {
Text = "ESP透视",
Default = false,
Callback = function(v) espEnabled = v end,
})
local statusLabel = cL:AddLabel("等待数据...")
cR:AddSlider("scpRange", {
Text = "射击距离",
Default = MAX_RANGE,
Min = 50,
Max = 1000,
Rounding = 0,
Suffix = " studs",
Callback = function(v) MAX_RANGE = v end,
})
cR:AddSlider("scpMeleeRange", {
Text = "近战范围",
Default = MELEE_RANGE,
Min = 2,
Max = 20,
Rounding = 0,
Callback = function(v) MELEE_RANGE = v; pcall(CreateCircle) end,
})
cR:AddSlider("scpCd", {
Text = "射击冷却",
Default = SHOOT_CD,
Min = 0.012,
Max = 1,
Rounding = 3,
Suffix = " s",
Callback = function(v) SHOOT_CD = v end,
})
cR:AddButton({
Text = "立即扫描武器",
Func = function()
local n = ScanWeapons()
Library:Notify("已扫描武器 数量:" .. tostring(n), 3)
end,
})
local WLTab = Window:AddTab("白名单", "shield")
local wL = WLTab:AddLeftGroupbox("白名单管理", "user")
wL:AddInput("scpWlInput", {
Text = "添加白名单",
Default = "",
Placeholder = "输入玩家名",
Finished = true,
Callback = function(v)
if v and v ~= "" then addWL(v) end
end,
})
wL:AddButton({
Text = "清空白名单",
Func = function()
for n in pairs(WL) do WL[n] = nil end
Library:Notify("白名单已清空", 3)
end,
})
task.spawn(function()
while true do
task.wait(1)
pcall(function()
UpdateMyRole()
local enemies, friends, whitelisted = 0, 0, 0
for _, p in ipairs(Players:GetPlayers()) do
if p ~= player then
if isWL(p) then whitelisted = whitelisted + 1
elseif IsEnemy(p) then enemies = enemies + 1
else friends = friends + 1 end
end
end
if statusLabel then
pcall(function()
statusLabel:SetText(string.format(
"角色:%s\n友:%d 敌:%d 白:%d 武器:%d\n射程:%d 近战:%d\n装备:%s",
tostring(myRole), friends, enemies, whitelisted, #WepList,
MAX_RANGE, MELEE_RANGE, tostring(currentWeaponName)))
end)
end
end)
end
end)
task.spawn(function()
while true do
task.wait(2)
pcall(ScanWeapons)
end
end)
local lastShoot = 0
RunService.Heartbeat:Connect(function()
pcall(function()
if not autoShoot then return end
local ch = player.Character
if not ch then return end
local hum = ch:FindFirstChildOfClass("Humanoid")
if not hum or hum.Health <= 0 then return end
if not HasRanged() then return end
local now = tick()
if now - lastShoot < SHOOT_CD then return end
for _, t in ipairs(GetEnemies()) do
FireRanged(t)
lastShoot = now
break
end
end)
end)
local lastMelee = 0
RunService.Heartbeat:Connect(function()
pcall(function()
if not autoMelee then return end
local ch = player.Character
if not ch then return end
local hum = ch:FindFirstChildOfClass("Humanoid")
if not hum or hum.Health <= 0 then return end
if not HasMelee() then return end
local now = tick()
if now - lastMelee < MELEE_CD then return end
local ts = GetMeleeTargets()
if #ts > 0 then
FireMelee(ts)
lastMelee = now
end
end)
end)
RunService.RenderStepped:Connect(function() pcall(UpdateCircle) end)
player.CharacterAdded:Connect(function(char)
task.wait(0.5)
UpdateMyRole()
pcall(ScanWeapons)
pcall(CreateCircle)
char.ChildAdded:Connect(function(c)
if c:IsA("Tool") then task.wait(0.085); pcall(ScanWeapons) end
end)
char.ChildRemoved:Connect(function(c)
if c:IsA("Tool") then task.wait(0.082); pcall(ScanWeapons) end
end)
end)
local bpMain = player:FindFirstChild("Backpack")
if bpMain then
bpMain.ChildAdded:Connect(function(c)
if c:IsA("Tool") then task.wait(0.084); pcall(ScanWeapons) end
end)
end
task.wait(1)
pcall(ScanWeapons)
pcall(CreateCircle)
Library:Notify("SCP 功能已加载（默认关闭）", 3)
end
