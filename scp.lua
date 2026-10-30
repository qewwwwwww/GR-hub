return function(Library, Window)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local channel = ReplicatedStorage:WaitForChild("Libraries"):WaitForChild("Network"):WaitForChild("Channel")
local attackEvent = channel:WaitForChild("tool/attack")
local shootEvent = channel:WaitForChild("tool/shoot")
local soundEvent = channel:WaitForChild("tool/sound")
local MAX_RANGE = 950
local MELEE_RANGE = 5
local SHOOT_CD = 0.012
local autoShoot = false
local autoMelee = false
local rayEnabled = false
local drawVis = false
local drawCircle = false
local attackInnocentDClass = false
local espEnabled = false
local FOUND = { scientist = true, security = true, mtf = true, director = true }
local ANTI = { chaos_insurgency = true, rogue_agent = true, traitor = true, renegade = true }
local WL = {}
local function isWL(p) return p and WL[p.Name] or false end
local function addWL(n) if n and n ~= "" then WL[n] = true end end
local function rmWL(n) WL[n] = nil end
local myRole = nil
local function getRole(p) return p and p:GetAttribute("Role") or nil end
local function updRole()
local r = getRole(player)
if r ~= myRole then myRole = r end
end
updRole()
local function isDClassHostile(t)
local hrp = t.Character and t.Character:FindFirstChild("HumanoidRootPart")
local tag = hrp and hrp:FindFirstChild("Tag")
local w = tag and tag:FindFirstChild("Wrapper")
local h = w and w:FindFirstChild("Hostile")
return h and (h:IsA("TextLabel") or h:IsA("ImageLabel")) and h.Visible
end
local function isEscaped(p)
if not p or not p.Character then return false end
local hrp = p.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return false end
local tag = hrp:FindFirstChild("Tag")
if not tag then return false end
local wrapper = tag:FindFirstChild("Wrapper")
if not wrapper then return false end
local escaped = wrapper:FindFirstChild("Escaped")
return escaped and escaped:IsA("TextLabel") and escaped.Visible
end
local function isEnemy(t)
if not t or t == player then return false end
if isWL(t) then return false end
local tr = getRole(t)
if not tr or tr == "" then return false end
if tr == "anomaly" or myRole == "anomaly" then return true end
if tr == myRole then return false end
if myRole == "d_class" or myRole == "escaped_d" or myRole == "escaped_d_class" then
if FOUND[tr] then return true end
if tr == "rogue_agent" or tr == "traitor" or tr == "renegade" then return true end
return false
end
if FOUND[myRole] then
if ANTI[tr] then return true end
if isEscaped(t) then return true end
if tr == "d_class" then return attackInnocentDClass or isDClassHostile(t) end
return false
end
if ANTI[myRole] then
if FOUND[tr] then return true end
if tr == "d_class" then return true end
if isEscaped(t) then return true end
return false
end
return false
end
local meleeKeywords = { "knife", "crowbar", "tomahawk" }
local rangedKeywords = { "glock", "beretta", "mp5", "ak47", "hk416", "spas-12", "awm", "m249" }
local function wepType(name)
name = (name or ""):lower()
for _, kw in ipairs(meleeKeywords) do if name:find(kw) then return "melee" end end
for _, kw in ipairs(rangedKeywords) do if name:find(kw) then return "ranged" end end
return "ranged"
end
local allWepIds, knownWepName = {}, {}
local function extractId(tool)
for _, c in ipairs(tool:GetDescendants()) do
if c:IsA("StringValue") and c.Value and #c.Value == 36 then return c.Value end
end
for _, v in pairs(tool:GetAttributes()) do
if type(v) == "string" and #v == 36 then return v end
end
if #tool.Name == 36 then return tool.Name end
return nil
end
local function collectWeps()
local got, names = {}, {}
local function add(t)
local id = extractId(t); if not id then return end
got[id] = true; names[id] = (t:GetAttribute("Name") or t.Name):lower()
end
local bp = player:FindFirstChild("Backpack")
if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then add(t) end end end
if player.Character then
for _, t in ipairs(player.Character:GetChildren()) do if t:IsA("Tool") then add(t) end end
end
allWepIds = {}; knownWepName = {}
for id in pairs(got) do allWepIds[#allWepIds + 1] = id; knownWepName[id] = names[id] end
end
local function getEquippedWeapon()
if not player.Character then return nil end
for _, tool in ipairs(player.Character:GetChildren()) do
if tool:IsA("Tool") then
local id = extractId(tool)
if id then return id, knownWepName[id] or (tool:GetAttribute("Name") or tool.Name):lower() end
end
end
return nil
end
local function buildBaseIgnoreList()
local t = {}
local function add(o) if o then t[#t + 1] = o end end
add(player.Character)
local function sweep(p)
if not p then return end
for _, v in ipairs(p:GetChildren()) do if v:IsA("Tool") then add(v) end end
end
sweep(player.Character); sweep(player:FindFirstChild("Backpack"))
local cam = Workspace:FindFirstChild("Camera")
if cam then for _, v in ipairs(cam:GetChildren()) do add(v) end end
return t
end
local function hasLineOfSight(from, targetChar)
local hrp = targetChar:FindFirstChild("HumanoidRootPart")
if not hrp then return false end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = buildBaseIgnoreList()
params.IgnoreWater = true
local r = Workspace:Raycast(from, (hrp.Position - from).Unit * (hrp.Position - from).Magnitude, params)
if r then return r.Instance:FindFirstAncestorOfClass("Model") == targetChar else return true end
end
local function scanAllPlayers()
local out = {}
local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if not myHRP then return out end
for _, p in ipairs(Players:GetPlayers()) do
if p ~= player and p.Character and isEnemy(p) then
local hrp = p.Character:FindFirstChild("HumanoidRootPart")
local hum = p.Character:FindFirstChildOfClass("Humanoid")
if hrp and hum and hum.Health > 0 then
local d = (hrp.Position - myHRP.Position).Magnitude
if d <= MAX_RANGE then
if not rayEnabled or hasLineOfSight(myHRP.Position, p.Character) then
out[#out + 1] = { player = p, char = p.Character, hrp = hrp, dist = d }
end
end
end
end
end
table.sort(out, function(a, b) return a.dist < b.dist end)
return out
end
local function getMeleeTargets()
local out = {}
local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if not myHRP then return out end
for _, p in ipairs(Players:GetPlayers()) do
if p ~= player and p.Character and isEnemy(p) then
local hrp = p.Character:FindFirstChild("HumanoidRootPart")
local hum = p.Character:FindFirstChildOfClass("Humanoid")
if hrp and hum and hum.Health > 0 and (hrp.Position - myHRP.Position).Magnitude <= MELEE_RANGE then
out[#out + 1] = { player = p, char = p.Character, hrp = hrp }
end
end
end
return out
end
local circleParts = {}
local function destroyCircle()
for _, part in ipairs(circleParts) do
pcall(function() part:Destroy() end)
end
circleParts = {}
end
local function createCircle()
destroyCircle()
if not drawCircle then return end
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
part.Color = Color3.fromRGB(232, 102, 116)
part.Transparency = 0.405
part.Size = Vector3.new(0.061, 0.018, 0.054)
part.CFrame = CFrame.new(x, center.Y - 0.037, z)
part.Parent = Workspace
table.insert(circleParts, part)
end
end
local function updateCircle()
if not drawCircle then
destroyCircle()
return
end
local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if not hrp then
destroyCircle()
return
end
local valid = true
for _, part in ipairs(circleParts) do
if not part or not part.Parent then
valid = false
break
end
end
if not valid or #circleParts == 0 then
createCircle()
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
local function getMuzzlePosition(weaponId)
local camera = Workspace:FindFirstChild("Camera")
if not camera then return nil end
local weaponObj = camera:FindFirstChild(weaponId)
if not weaponObj then return nil end
local points = weaponObj:FindFirstChild("Points")
if not points then return nil end
local muzzle = points:FindFirstChild("Muzzle")
if not muzzle then return nil end
return muzzle.Position
end
local function fireRanged(t)
local head = t.char:FindFirstChild("Head")
local aimPoint = (head or t.hrp).Position
local origin = nil
for _, id in ipairs(allWepIds) do
if wepType(knownWepName[id]) ~= "melee" then
local muzzlePos = getMuzzlePosition(id)
if muzzlePos then
origin = muzzlePos
break
end
end
end
if not origin then
local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
if hrp then
local randomOffset = Vector3.new(
math.random(-100, 100) / 10,
math.random(-50, 100) / 10,
math.random(-100, 100) / 10
)
origin = hrp.Position + Vector3.new(0, 1.630, 0) + randomOffset
else
origin = t.hrp.Position + Vector3.new(0, 2.540, 0)
end
end
local dir = (aimPoint - origin).Unit * 9550
if drawVis then
local beamPart = Instance.new("Part")
beamPart.Anchored = true
beamPart.CanCollide = false
beamPart.Material = Enum.Material.Neon
beamPart.Color = Color3.fromRGB(250, 234, 143)
beamPart.Transparency = 0.474
beamPart.Size = Vector3.new(0.048, 0.044, (aimPoint - origin).Magnitude)
beamPart.CFrame = CFrame.new(origin, aimPoint) * CFrame.new(0, 0, -beamPart.Size.Z / 2)
beamPart.Parent = Workspace
local hitMarker = Instance.new("Part")
hitMarker.Anchored = true
hitMarker.CanCollide = false
hitMarker.Material = Enum.Material.Neon
hitMarker.Color = Color3.fromRGB(255, 205, 153)
hitMarker.Transparency = 0.569
hitMarker.Shape = Enum.PartType.Ball
hitMarker.Size = Vector3.new(0.303, 0.265, 0.237)
hitMarker.CFrame = CFrame.new(aimPoint)
hitMarker.Parent = Workspace
task.delay(0.748, function()
if beamPart and beamPart.Parent then beamPart:Destroy() end
if hitMarker and hitMarker.Parent then hitMarker:Destroy() end
end)
end
for _, id in ipairs(allWepIds) do
if wepType(knownWepName[id]) ~= "melee" then
pcall(function()
shootEvent:FireServer(id, { {
normal = Vector3.new(0, 1, 0),
direction = dir,
origin = origin,
instance = head or t.hrp,
points = {},
position = aimPoint
} })
end)
pcall(function() soundEvent:FireServer(id, "FIRE") end)
end
end
end
local function fireMelee(targets)
if #targets == 0 then return end
local targetChar = targets[1].char
local camera = Workspace:FindFirstChild("Camera")
if not camera then return end
for _, weaponId in ipairs(allWepIds) do
if wepType(knownWepName[weaponId]) == "melee" then
local camWeapon = camera:FindFirstChild(weaponId)
if not camWeapon then
task.wait(0.003)
camWeapon = camera:FindFirstChild(weaponId)
if not camWeapon then continue end
end
pcall(function() attackEvent:FireServer(weaponId, { targetChar, camWeapon }) end)
end
end
end
local roleMap = {
scientist = "科学家", security = "安保", mtf = "机动特遣队", director = "主管",
d_class = "D级人员", escaped_d = "逃脱D级", escaped_d_class = "逃脱D级",
chaos_insurgency = "混沌分裂者", rogue_agent = "叛变特工", traitor = "叛徒",
renegade = "反叛者", anomaly = "异常实体",
}
local espTable = {}
local roleColors = {
["D级人员"] = {Color3.fromRGB(255, 142, 105), Color3.fromRGB(220, 175, 110)},
["安保"] = {Color3.fromRGB(225, 227, 231), Color3.fromRGB(165, 168, 174)},
["机动特遣队"] = {Color3.fromRGB(112, 162, 252), Color3.fromRGB(176, 208, 254)},
["混沌分裂者"] = {Color3.fromRGB(255, 210, 76), Color3.fromRGB(243, 227, 165)},
["科学家"] = {Color3.fromRGB(146, 213, 238), Color3.fromRGB(201, 237, 251)},
["异常实体"] = {Color3.fromRGB(44, 43, 45), Color3.fromRGB(89, 88, 91)},
["主管"] = {Color3.fromRGB(151, 240, 152), Color3.fromRGB(198, 252, 199)},
["Default"] = {Color3.fromRGB(204, 206, 210), Color3.fromRGB(104, 106, 108)}
}
local function cleanESP(p)
if espTable[p] then
if espTable[p].Gui and espTable[p].Gui.Parent then
espTable[p].Gui:Destroy()
end
espTable[p] = nil
end
end
local function createESPForPlayer(p)
if p == player or espTable[p] then return end
p.CharacterAdded:Connect(function(ch)
task.wait(0.25)
cleanESP(p)
task.spawn(function() createESPForPlayer(p) end)
end)
p.CharacterRemoving:Connect(function() cleanESP(p) end)
task.spawn(function()
local char = p.Character or p.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart", 5)
local head = char:WaitForChild("Head", 5)
local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
if not hrp or not head or not hum then return end
local billboard = Instance.new("BillboardGui")
billboard.Name = "ESPGui_" .. p.Name
billboard.Adornee = hrp
billboard.Size = UDim2.new(0, 580, 0, 780)
billboard.StudsOffset = Vector3.new(0, 1.525, 0)
billboard.AlwaysOnTop = true
billboard.MaxDistance = 5500
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
Role = getRole(p) or "?",
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
task.spawn(function() createESPForPlayer(p) end)
end
Players.PlayerAdded:Connect(function(p)
task.wait(0.5)
createESPForPlayer(p)
end)
Players.PlayerRemoving:Connect(cleanESP)
task.spawn(function()
while true do task.wait(0.09)
if not espEnabled then
for p, data in pairs(espTable) do
if data.Gui then data.Gui.Enabled = false end
end
else
local myHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
for p, data in pairs(espTable) do
if not data.Gui then continue end
data.Gui.Enabled = true
local role = getRole(p) or "?"
local roleCN = roleMap[role] or role
local colors = roleColors[roleCN] or roleColors["Default"]
data.Stroke.Color = colors[1]
data.Gradient.Color = ColorSequence.new(colors[1], colors[2])
if myHRP and data.Char then
local targetHRP = data.Char:FindFirstChild("HumanoidRootPart")
if targetHRP then
local distance = (myHRP.Position - targetHRP.Position).Magnitude
local scaleFactor = math.clamp(1 - (distance - 10) / 570, 0.086, 1)
local newWidth = 610 * scaleFactor
local newHeight = 810 * scaleFactor
newWidth = math.max(newWidth, 358)
newHeight = math.max(newHeight, 470)
data.Gui.Size = UDim2.new(0, newWidth, 0, newHeight)
end
end
local char = p.Character
if not char or (data.Hum and data.Hum.Health <= 0) then
cleanESP(p)
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
if drawCircle then pcall(createCircle) else pcall(destroyCircle) end
end,
})
cL:AddToggle("scpDClass", {
Text = "攻击无辜D级",
Default = false,
Callback = function(v) attackInnocentDClass = v end,
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
Max = 2000,
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
Callback = function(v) MELEE_RANGE = v; pcall(createCircle) end,
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
pcall(collectWeps)
Library:Notify("已扫描武器", 3)
end,
})
local WLTab = Window:AddTab("白名单", "shield")
local wL = WLTab:AddLeftGroupbox("白名单管理", "user")
wL:AddInput("scpWlInput", {
Text = "添加白名单",
Default = "",
Placeholder = "输入玩家名后回车",
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
while true do task.wait(1)
pcall(function()
updRole()
local enemies, friends, whitelisted = 0, 0, 0
for _, p in ipairs(Players:GetPlayers()) do
if p ~= player then
if isWL(p) then whitelisted = whitelisted + 1
elseif isEnemy(p) then enemies = enemies + 1
else friends = friends + 1 end
end
end
local eqId, eqName = getEquippedWeapon()
local eqStr = "无"
if eqId then
local typeStr = wepType(eqName) == "melee" and "近战" or "远程"
eqStr = typeStr .. " " .. eqName
end
if statusLabel then
pcall(function()
statusLabel:SetText(string.format(
"角色:%s\n友:%d 敌:%d 白:%d 武器:%d\n射程:%d 近战:%d CD:%.3f\n装备:%s",
tostring(myRole), friends, enemies, whitelisted, #allWepIds,
MAX_RANGE, MELEE_RANGE, SHOOT_CD, eqStr))
end)
end
end)
end
end)
task.spawn(function()
while true do task.wait(2)
pcall(collectWeps)
end
end)
local lastFire = 0
RunService.Heartbeat:Connect(function()
pcall(function()
if not autoShoot then return end
local ch = player.Character; if not ch then return end
local hum = ch:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health <= 0 then return end
if #allWepIds == 0 then return end
local now = tick()
for _, t in ipairs(scanAllPlayers()) do
if now - lastFire >= SHOOT_CD then fireRanged(t); lastFire = now end
end
end)
end)
RunService.Heartbeat:Connect(function()
pcall(function()
if not autoMelee then return end
local ch = player.Character; if not ch then return end
local hum = ch:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health <= 0 then return end
if #allWepIds == 0 then return end
local ts = getMeleeTargets()
if #ts > 0 then fireMelee(ts) end
end)
end)
RunService.RenderStepped:Connect(function() pcall(updateCircle) end)
Players.PlayerRemoving:Connect(function(p) rmWL(p.Name) end)
player.CharacterAdded:Connect(function() task.wait(0.5); updRole(); pcall(collectWeps); pcall(createCircle) end)
task.wait(1); pcall(collectWeps); pcall(createCircle)
Library:Notify("SCP 功能已加载（默认关闭）", 3)
end
