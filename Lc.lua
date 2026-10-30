return function(Library, Window)
local RunService = game:GetService("RunService")
local UserInput = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local lp = Players.LocalPlayer
local LOG_ENABLED = false
local FX_ENABLED = false
local USE_NATIVE_TRACER = false
local AIM_RAY_FROM_MUZZLE = false
local BULLET_SPEED = 1600
local BULLET_VELOCITY = nil
pcall(function() BULLET_VELOCITY = workspace:GetAttribute("BulletVelocity") end)
pcall(function()
workspace:GetAttributeChangedSignal("BulletVelocity"):Connect(function()
BULLET_VELOCITY = workspace:GetAttribute("BulletVelocity")
end)
end)
local BALLISTIC_GRAVITY = 0
local DROP_SKIP_EPS = 0.15
local SEG_DROP_STEP = 0.6
local BALLISTIC_MAX_SEGMENTS = 6
local PART_LABEL = {
Head = "头部 Head",
UpperTorso = "上胸 UpperTorso",
Torso = "躯干 Torso",
HumanoidRootPart = "根节点 Root",
LowerTorso = "下腹 LowerTorso",
}
local PART_LABEL_REV = {}
for k, v in pairs(PART_LABEL) do PART_LABEL_REV[v] = k end
local PART_ALIAS = {
UpperTorso = "Torso",
LowerTorso = "Torso",
Torso = "UpperTorso",
}
local RIG_TYPE = nil
local function detectRig(model)
if not model then return nil end
if model:FindFirstChild("UpperTorso") or model:FindFirstChild("LowerTorso") then
return "R15"
end
if model:FindFirstChild("Torso") then return "R6" end
return nil
end
local function currentRig()
if RIG_TYPE then return RIG_TYPE end
local m = lp.Character
local r = detectRig(m)
if not r then
for _, p in ipairs(Players:GetPlayers()) do
r = detectRig(p.Character)
if r then break end
end
end
RIG_TYPE = r or "R6"
return RIG_TYPE
end
local function partListForRig(model)
local r = model and detectRig(model) or currentRig()
if r == "R15" then
return { "Head", "UpperTorso", "Torso", "HumanoidRootPart", "LowerTorso" }
end
return { "Head", "Torso", "HumanoidRootPart" }
end
local AIM_PART_MAIN = "Head"
local AIM_PART_FALLBACK = true
local RAY_ACCURACY = 2
local LOS_CACHE_TTL = 0.05
local EVICT_EVERY = 0.02
local MULTI_PART_AIM = true
local HEADSHOT_ONLY = false
local EARLY_OUT_HEAD_BLOCK = false
local PIERCE_ENABLED = true
local PIERCE_MAX = 3
local PIERCE_STEP = 0.05
local LOS_RELEASE_GRACE = 0.15
local _LOS_INTERVAL = 0.03
local _RAYPARAMS_REBUILD = 2.0
local SCAN_BUDGET = 0.003
local SCAN_REFRESH = 0
local LOCK_CONFIRM_TIME = 0.35
local LOCK_UI_SIZE = 42
local LOCK_UI_MIN = 16
local LOCK_UI_MAX = 70
local RAY_ENABLED = true
local RELOAD_TIME = 7.0
local PACKET_DELAY = 0.1
local MAX_DIST = 300
local SLIDER_MIN = 50
local SLIDER_MAX = 10000
local TRACER_LENGTH = 15
local TRACER_LIFETIME = 1.5
local SLIDER_MIN_COOLDOWN = 1
local SLIDER_MAX_COOLDOWN = 20
local TEAM_CHECK = false
local ATTACK_BOTS = false
local ATTACK_PLAYERS = false
local BOT_FOLDER
pcall(function()
local gi = workspace:FindFirstChild("GameInfo")
if gi then BOT_FOLDER = gi:FindFirstChild("LivingBotPlayers") end
end)
local _botSet = setmetatable({}, { __mode = "k" })
local TAG_DYN = "fx_DynamicHumanoid"
local NPC_ROOT
pcall(function()
if workspace.MapContainer and workspace.MapContainer.Special then
NPC_ROOT = workspace.MapContainer.Special:FindFirstChild("NPC_Container")
end
end)
local EXCLUDE_ROOT = nil
pcall(function()
local sp = workspace.MapContainer and workspace.MapContainer.Special
if sp then
local nd = sp:FindFirstChild("NPC_Data")
if nd then EXCLUDE_ROOT = nd:FindFirstChild("RigContainers") end
end
end)
local _excludeCache = setmetatable({}, { __mode = "k" })
local function isExcludedModel(m)
if not m then return false end
local v = _excludeCache[m]
if v ~= nil then return v end
local res = false
if EXCLUDE_ROOT and m:IsDescendantOf(EXCLUDE_ROOT) then
res = true
end
_excludeCache[m] = res
return res
end
local BOT_KEYWORDS = { "bot", "npc", "dummy", "mob_", "zombie", "monster", "ai", "summon", "minion" }
local NPC_KEYS = { "bot", "npc", "dummy", "ai", "summon", "minion" }
local running = false
local state = "IDLE"
local target = nil
local reloadUntil = 0
local sent = 0
local _targetReady = false
local _lockStart = 0
local _lastLosTime = 0
local _losLostAt = 0
local _scanValid = false
local _scanRefreshAt = 0
local ecoOn = false
local ClientCursor = nil
local PlayerUtility = nil
local QuickCreate = nil
local CrossPlatformMethods = nil
local ClientUtilities = nil
local SharedModuleFunctions = nil
local ProjectileUtility = nil
local ActiveCast = nil
local ClientPlayerWrapper = nil
pcall(function()
local ok, mod = pcall(function() return require(Replicated.MODULES.ClientCursor) end)
if ok and mod then ClientCursor = mod end
ok, mod = pcall(function() return require(Replicated.MODULES.PlayerUtility) end)
if ok and mod then PlayerUtility = mod end
ok, mod = pcall(function() return require(Replicated.MODULES.QuickCreate) end)
if ok and mod then QuickCreate = mod end
ok, mod = pcall(function() return require(Replicated.MODULES.CrossPlatformMethods) end)
if ok and mod then CrossPlatformMethods = mod end
ok, mod = pcall(function() return require(Replicated.MODULES.ClientUtilities) end)
if ok and mod then ClientUtilities = mod end
ok, mod = pcall(function() return require(Replicated.MODULES.ProjectileUtility) end)
if ok and mod then ProjectileUtility = mod end
ok, mod = pcall(function() return require(Replicated.MODULES.ClientPlayerWrapper) end)
if ok and mod then ClientPlayerWrapper = mod end
ok, mod = pcall(function()
local pu = Replicated:FindFirstChild("MODULES")
pu = pu and pu:FindFirstChild("ProjectileUtility")
if not pu then return nil end
for _, node in ipairs(pu:GetDescendants()) do
if node:IsA("ModuleScript") and node.Name == "SharedModuleFunctions" then
return require(node)
end
end
return nil
end)
if ok and mod then SharedModuleFunctions = mod end
end)
local clearAllLockUI, hideLockUI, showLockUI
local startLockSpin, stopLockSpin
local setLockState, updateLockUISize, updateLockUIMaxDistance
local requestScan
local lockUI = {}
local lockReady = {}
local _deathConn = setmetatable({}, { __mode = "k" })
local _lockTw = setmetatable({}, { __mode = "k" })
local _losCache = setmetatable({}, { __mode = "k" })
local _aimPick = setmetatable({}, { __mode = "k" })
updateLockUIMaxDistance = function() end
requestScan = function() end
clearAllLockUI = function() end
hideLockUI = function() end
showLockUI = function() end
startLockSpin = function() end
stopLockSpin = function() end
setLockState = function() end
updateLockUISize = function() end
local AimTab = Window:AddTab("枪械", "crosshair")
local MiscTab = Window:AddTab("杂项", "settings")
local aL = AimTab:AddLeftGroupbox("ragebot", "power")
local aR = AimTab:AddRightGroupbox("射击参数", "crosshair")
aL:AddToggle("swFire", {
Text = "启动",
Default = false,
Tooltip = "关闭后只锁定",
Callback = function(v)
running = v
if not running then
clearAllLockUI()
target = nil
_targetReady = false
state = "IDLE"
end
end,
})
aL:AddToggle("swTeam", {
Text = "队伍检测",
Default = false,
Callback = function(v) TEAM_CHECK = v end,
})
aL:AddToggle("swBots", {
Text = "攻击Bot",
Default = false,
Callback = function(v)
ATTACK_BOTS = v
requestScan()
end,
})
aL:AddToggle("swPlr", {
Text = "攻击玩家",
Default = false,
Callback = function(v)
ATTACK_PLAYERS = v
requestScan()
end,
})
aR:AddSlider("sldLock", {
Text = "锁定时间",
Default = LOCK_CONFIRM_TIME,
Min = 0,
Max = 1,
Rounding = 2,
Suffix = " s",
Callback = function(v) LOCK_CONFIRM_TIME = v end,
})
aR:AddSlider("sldCool", {
Text = "换弹冷却",
Default = RELOAD_TIME,
Min = SLIDER_MIN_COOLDOWN,
Max = SLIDER_MAX_COOLDOWN,
Rounding = 1,
Suffix = " s",
Callback = function(v) RELOAD_TIME = v end,
})
aR:AddSlider("sldDist", {
Text = "射击距离",
Default = MAX_DIST,
Min = SLIDER_MIN,
Max = SLIDER_MAX,
Rounding = 0,
Suffix = " studs",
Callback = function(v)
MAX_DIST = v
if updateLockUIMaxDistance then updateLockUIMaxDistance() end
requestScan()
end,
})
local rL = AimTab:AddLeftGroupbox("射线设置", "eye")
local rR = AimTab:AddRightGroupbox("高级选项", "sliders-horizontal")
local partOptions = {}
for _, n in ipairs(partListForRig()) do
partOptions[#partOptions + 1] = PART_LABEL[n] or n
end
rL:AddToggle("swRay", {
Text = "射线锁定",
Default = false,
Callback = function(v)
RAY_ENABLED = v
_losCache = setmetatable({}, { __mode = "k" })
requestScan()
end,
})
rL:AddDropdown("ddPart", {
Text = "瞄准部位",
Default = PART_LABEL[AIM_PART_MAIN] or "头部 Head",
Values = partOptions,
Callback = function(v)
local name = PART_LABEL_REV[v]
if name then AIM_PART_MAIN = name end
_aimPick = setmetatable({}, { __mode = "k" })
_losCache = setmetatable({}, { __mode = "k" })
end,
})
rL:AddToggle("swFallback", {
Text = "挡头换部位",
Default = false,
Callback = function(v)
AIM_PART_FALLBACK = v
_losCache = setmetatable({}, { __mode = "k" })
end,
})
rL:AddSlider("sldSpeed", {
Text = "扫描速度",
Default = 3,
Min = 1,
Max = 5,
Rounding = 0,
Callback = function(v)
EVICT_EVERY = ({ 0.12, 0.06, 0.03, 0.015, 0.005 })[v] or 0.03
_LOS_INTERVAL = ({ 0.12, 0.06, 0.03, 0.02, 0.01 })[v] or 0.03
end,
})
rL:AddSlider("sldPrec", {
Text = "射线模式",
Default = RAY_ACCURACY,
Min = 0,
Max = 4,
Rounding = 0,
Callback = function(v) RAY_ACCURACY = v end,
})
rR:AddToggle("swPierce", {
Text = "穿透透明",
Default = false,
Callback = function(v) PIERCE_ENABLED = v end,
})
rR:AddToggle("swTracer", {
Text = "弹道特效",
Default = false,
Callback = function(v)
FX_ENABLED = v
for _, ui in pairs(lockUI) do
if FX_ENABLED then startLockSpin(ui) else stopLockSpin(ui) end
end
end,
})
rR:AddToggle("swEco", {
Text = "省电模式",
Default = false,
Callback = function(v)
ecoOn = v
if ecoOn then
_LOS_INTERVAL, SCAN_REFRESH = 0.2, 0.6
else
_LOS_INTERVAL, SCAN_REFRESH = 0.06, 0
end
end,
})
local mL = MiscTab:AddLeftGroupbox("状态", "activity")
local mR = MiscTab:AddRightGroupbox("操作", "wrench")
mL:AddLabel("等待数据...")
mR:AddButton({
Text = "立即重扫",
Func = function()
if requestScan then requestScan() end
Library:Notify("已请求重新扫描", 3)
end,
})
mR:AddButton({
Text = "恢复默认设置",
Func = function()
local O = Library.Options
if O.swFire then O.swFire:SetValue(false) end
if O.swTeam then O.swTeam:SetValue(false) end
if O.swBots then O.swBots:SetValue(false) end
if O.swPlr then O.swPlr:SetValue(false) end
if O.swRay then O.swRay:SetValue(false) end
if O.swFallback then O.swFallback:SetValue(false) end
if O.swPierce then O.swPierce:SetValue(false) end
if O.swTracer then O.swTracer:SetValue(false) end
if O.swEco then O.swEco:SetValue(false) end
if O.ddPart then O.ddPart:SetValue(PART_LABEL["Head"]) end
if O.sldLock then O.sldLock:SetValue(0.35) end
if O.sldCool then O.sldCool:SetValue(7) end
if O.sldDist then O.sldDist:SetValue(300) end
if O.sldSpeed then O.sldSpeed:SetValue(3) end
if O.sldPrec then O.sldPrec:SetValue(2) end
if requestScan then requestScan() end
Library:Notify("已恢复默认", 3)
end,
})
local cooldownGui = Instance.new("ScreenGui")
cooldownGui.Name = "GRCooldownBar"
cooldownGui.ResetOnSpawn = false
cooldownGui.IgnoreGuiInset = true
cooldownGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
cooldownGui.Parent = lp:WaitForChild("PlayerGui")
end)
local barFrame = Instance.new("Frame")
barFrame.Name = "BarFrame"
barFrame.Size = UDim2.new(0, 260, 0, 14)
barFrame.Position = UDim2.new(0.5, -130, 1, -100)
barFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
barFrame.BackgroundTransparency = 0.4
barFrame.BorderSizePixel = 0
barFrame.Visible = false
barFrame.Parent = cooldownGui
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 4)
barCorner.Parent = barFrame
local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
barFill.BorderSizePixel = 0
barFill.Parent = barFrame
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 4)
fillCorner.Parent = barFill
local barText = Instance.new("TextLabel")
barText.Name = "Text"
barText.Size = UDim2.new(1, 0, 1, 0)
barText.BackgroundTransparency = 1
barText.TextColor3 = Color3.fromRGB(255, 255, 255)
barText.Font = Enum.Font.GothamBold
barText.TextSize = 11
barText.Text = ""
barText.Parent = barFrame
local function updateCooldownBar()
if not running then
barFrame.Visible = false
return
end
barFrame.Visible = true
local now = os.clock()
if state == "RELOAD" then
local remain = reloadUntil - now
if remain < 0 then remain = 0 end
local ratio = 1 - (remain / RELOAD_TIME)
if ratio < 0 then ratio = 0 end
if ratio > 1 then ratio = 1 end
barFill.Size = UDim2.new(ratio, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
barText.Text = string.format("换弹冷却 %.1fs", remain)
else
barFill.Size = UDim2.new(1, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
barText.Text = "可射击"
end
end
local _playerOf = setmetatable({}, { __mode = "k" })
local _humOf = setmetatable({}, { __mode = "k" })
local _isNpc = setmetatable({}, { __mode = "k" })
local function playerOf(c)
if not c then return nil end
local v = _playerOf[c]
if v ~= nil then return v end
v = Players:GetPlayerFromCharacter(c)
_playerOf[c] = v
return v
end
local function humOf(c)
if not c then return nil end
local h = _humOf[c]
if h and h.Parent then return h end
h = c:FindFirstChildWhichIsA("Humanoid")
if h then _humOf[c] = h end
return h
end
local function isTeam(c)
if not TEAM_CHECK then return false end
if not c or c == lp.Character then return false end
if workspace:GetAttribute("Round_FriendlyFire") then return false end
local p = playerOf(c)
if not p then return false end
if p == lp then return false end
local mt, pt = lp.Team, p.Team
if mt and pt then return mt == pt end
return lp.TeamColor == p.TeamColor
end
local function isBotModel(model)
if not model or not model:IsA("Model") then return false end
if Players:GetPlayerFromCharacter(model) then return false end
if isExcludedModel(model) then return false end
local name = model.Name and model.Name:lower() or ""
for _, kw in ipairs(BOT_KEYWORDS) do
if name:find(kw) then return true end
end
if model:FindFirstChildOfClass("Humanoid") then return true end
return false
end
local function isNPC(c)
if not c then return false end
local cached = _isNpc[c]
if cached ~= nil then return cached end
if playerOf(c) then _isNpc[c] = false; return false end
if isExcludedModel(c) then _isNpc[c] = false; return false end
if _botSet[c] then _isNpc[c] = true; return true end
local res = false
if NPC_ROOT and c:IsDescendantOf(NPC_ROOT) then
res = true
else
local name = c.Name:lower()
for _, k in ipairs(NPC_KEYS) do
if string.find(name, k, 1, true) then res = true; break end
end
if not res then res = humOf(c) ~= nil end
end
if not res then res = isBotModel(c) end
_isNpc[c] = res
return res
end
local function alive(c)
local h = humOf(c)
return h ~= nil and h.Health > 0
end
local _teamAttackers, _teamDefenders
local _teamsTried = false
local function ensureTeams()
if _teamsTried then return end
_teamsTried = true
if QuickCreate and type(QuickCreate.GetTeam) == "function" then
pcall(function()
_teamAttackers = QuickCreate:GetTeam("Attackers")
_teamDefenders = QuickCreate:GetTeam("Defenders")
end)
end
end
local function teamAttrOf(c)
if not c then return nil end
local ok, v = pcall(function() return c:GetAttribute("Team") end)
if ok and type(v) == "string" and v ~= "" then return v end
ok, v = pcall(function() return c:GetAttribute("TeamName") end)
if ok and type(v) == "string" and v ~= "" then return v end
ok, v = pcall(function() return c:GetAttribute("Faction") end)
if ok and type(v) == "string" and v ~= "" then return v end
local hum = humOf(c)
if hum then
ok, v = pcall(function() return hum:GetAttribute("Team") end)
if ok and type(v) == "string" and v ~= "" then return v end
ok, v = pcall(function() return hum:GetAttribute("TeamName") end)
if ok and type(v) == "string" and v ~= "" then return v end
end
local par = c.Parent
if par and par:IsA("Instance") then
local pn = par.Name
if pn == "Attackers" or pn == "Defenders" then return pn end
end
return nil
end
local function isPVERound()
if PlayerUtility and type(PlayerUtility.IsPVERound) == "function" then
local ok, r = pcall(function() return PlayerUtility:IsPVERound() end)
if ok and type(r) == "boolean" then return r end
end
return false
end
local function localAreEnemies(myPlayer, c)
ensureTeams()
local p = playerOf(c)
if not p and isPVERound() then return true end
if workspace:GetAttribute("Round_Truce") then
if not p and isPVERound() then return true end
return false
end
if workspace:GetAttribute("Round_FriendlyFire") then return true end
local myTeam = myPlayer.Team
if p then
return myTeam ~= p.Team
end
local t = teamAttrOf(c)
local myName = myTeam and myTeam.Name or nil
if t and myName then return t ~= myName end
if _teamAttackers and myTeam == _teamAttackers then return t ~= "Attackers" end
if _teamDefenders and myTeam == _teamDefenders then return t ~= "Defenders" end
return false
end
local _enemyCache = setmetatable({}, { __mode = "k" })
local function isEnemyChar(c)
if not c then return false end
local v = _enemyCache[c]
if v ~= nil then return v end
local res
local p = playerOf(c)
if p then
if PlayerUtility and type(PlayerUtility.AreEnemies) == "function" then
local ok, r = pcall(function() return PlayerUtility:AreEnemies(lp, p) end)
if ok and type(r) == "boolean" then res = r end
end
end
if res == nil then res = localAreEnemies(lp, c) end
_enemyCache[c] = res
return res
end
local function invalidateTeamCache()
table.clear(_enemyCache)
end
pcall(function()
workspace:GetAttributeChangedSignal("Round_Truce"):Connect(invalidateTeamCache)
workspace:GetAttributeChangedSignal("Round_FriendlyFire"):Connect(invalidateTeamCache)
lp:GetPropertyChangedSignal("Team"):Connect(invalidateTeamCache)
end)
local function canAttack(c)
if not c then return false end
if c:GetAttribute("Immortal") then return false end
if c:GetAttribute("epoch") then return false end
if TEAM_CHECK and not isEnemyChar(c) then return false end
local plr = playerOf(c)
if plr then return ATTACK_PLAYERS end
if isNPC(c) then return ATTACK_BOTS end
return false
end
local function hasMuzzle(tool)
if not tool then return false end
return tool:FindFirstChild("Muzzle", true) ~= nil
end
local _gunCache, _gunCacheAt = nil, 0
local function getGun()
local now = os.clock()
if _gunCache and _gunCache.Parent and (now - _gunCacheAt) < 1 then
return _gunCache
end
_gunCacheAt = now
local c = lp.Character
local found = nil
if c then
local equipped = c:FindFirstChildWhichIsA("Tool")
if equipped and hasMuzzle(equipped) then found = equipped end
end
if not found then
local backpack = lp:FindFirstChildOfClass("Backpack")
if backpack then
for _, tool in ipairs(backpack:GetChildren()) do
if tool:IsA("Tool") and hasMuzzle(tool) then found = tool; break end
end
end
end
_gunCache = found
return found
end
local _aimPart = setmetatable({}, { __mode = "k" })
local function getAimPart(c)
if not c then return nil end
local p = _aimPart[c]
if p and p.Parent then return p end
p = c:FindFirstChild("Head")
or c:FindFirstChild("UpperTorso")
or c:FindFirstChild("Torso")
or c:FindFirstChild("HumanoidRootPart")
or c:FindFirstChild("Head", true)
or c.PrimaryPart
or c:FindFirstChildWhichIsA("BasePart")
if p then _aimPart[c] = p end
return p
end
local tracerFolder = Instance.new("Folder")
tracerFolder.Name = "AimTracers"
tracerFolder.Parent = Workspace
local TRACER_TEXTURE = "rbxassetid://6060542021"
local _beamFade = {}
do
local steps = 8
for i = 0, steps do
local a = 1 - i / steps
_beamFade[i + 1] = {
outer = NumberSequence.new({
NumberSequenceKeypoint.new(0, 0.6 * a),
NumberSequenceKeypoint.new(0.3, 0.3 * a),
NumberSequenceKeypoint.new(0.7, 0.3 * a),
NumberSequenceKeypoint.new(1, 0.6 * a)
}),
core = NumberSequence.new({
NumberSequenceKeypoint.new(0, 0.5 * a),
NumberSequenceKeypoint.new(0.5, 0.5 * a),
NumberSequenceKeypoint.new(1, 0.5 * a)
})
}
end
end
local TRACER_DURATION = TRACER_LIFETIME
local TRACER_HOLD = TRACER_LIFETIME * 0.6
local TRACER_FADE_STEP = (TRACER_LIFETIME - TRACER_HOLD) / 4
local function drawTracer(fromPos, toPos)
if not FX_ENABLED then return end
if (toPos - fromPos).Magnitude < 0.5 then return end
local beamEnd = toPos
pcall(function()
local rp = RaycastParams.new()
local exclude = {}
local cosmetic = Workspace:FindFirstChild("CosmeticContainer")
if cosmetic then exclude[#exclude + 1] = cosmetic end
if lp.Character then exclude[#exclude + 1] = lp.Character end
for _, p in ipairs(Players:GetPlayers()) do
if p ~= lp and p.Character then exclude[#exclude + 1] = p.Character end
end
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.FilterDescendantsInstances = exclude
rp.IgnoreWater = true
local hit = Workspace:Raycast(fromPos, toPos - fromPos, rp)
if hit and (hit.Position - toPos).Magnitude > 2 then
beamEnd = hit.Position + (hit.Normal * 0.15)
end
end)
toPos = beamEnd
local a0 = Instance.new("Attachment")
a0.WorldCFrame = CFrame.new(fromPos)
a0.Parent = tracerFolder
local a1 = Instance.new("Attachment")
a1.WorldCFrame = CFrame.new(toPos)
a1.Parent = tracerFolder
local outerBeam = Instance.new("Beam")
outerBeam.Attachment0 = a0
outerBeam.Attachment1 = a1
outerBeam.Texture = TRACER_TEXTURE
outerBeam.TextureSpeed = 5
outerBeam.Width0 = 1.2
outerBeam.Width1 = 1.2
outerBeam.Transparency = _beamFade[1].outer
outerBeam.Color = ColorSequence.new(Color3.fromRGB(85, 150, 255))
outerBeam.LightEmission = 1
outerBeam.LightInfluence = 0
outerBeam.FaceCamera = true
outerBeam.Parent = tracerFolder
local coreBeam = Instance.new("Beam")
coreBeam.Attachment0 = a0
coreBeam.Attachment1 = a1
coreBeam.Texture = TRACER_TEXTURE
coreBeam.TextureSpeed = 8
coreBeam.Width0 = 0.25
coreBeam.Width1 = 0.25
coreBeam.Transparency = _beamFade[1].core
coreBeam.Color = ColorSequence.new(Color3.fromRGB(230, 240, 255))
coreBeam.LightEmission = 1.5
coreBeam.LightInfluence = 0
coreBeam.FaceCamera = true
coreBeam.Parent = tracerFolder
Debris:AddItem(outerBeam, TRACER_DURATION)
Debris:AddItem(coreBeam, TRACER_DURATION)
Debris:AddItem(a0, TRACER_DURATION)
Debris:AddItem(a1, TRACER_DURATION)
task.spawn(function()
task.wait(TRACER_HOLD)
for i = 2, 5 do
local f = _beamFade[i]
if f then
pcall(function()
outerBeam.Transparency = f.outer
coreBeam.Transparency = f.core
end)
end
task.wait(TRACER_FADE_STEP)
end
end)
end
local lockFolder = Instance.new("Folder")
lockFolder.Name = "LockMarkers"
lockFolder.Parent = Workspace
local LOCK_APPEAR_TIME = 0.12
local LOCK_APPEAR_SCALE = 1.8
local LOCK_BURST_TIME = 0.35
local LOCK_BURST_SCALE = 2.2
startLockSpin = function(bg)
if not FX_ENABLED or _lockTw[bg] then return end
local ring = bg:FindFirstChild("Ring")
local innerRing = bg:FindFirstChild("InnerRing")
if not ring or not innerRing then return end
local tw1 = TweenService:Create(ring,
TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
{ Rotation = 360 })
local tw2 = TweenService:Create(innerRing,
TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
{ Rotation = -360 })
tw1:Play()
tw2:Play()
_lockTw[bg] = { tw1, tw2 }
end
stopLockSpin = function(bg)
local tws = _lockTw[bg]
if not tws then return end
for _, tw in ipairs(tws) do pcall(tw.Cancel, tw) end
_lockTw[bg] = nil
end
local function playAppearLockUI(ui)
if not ui or LOCK_APPEAR_TIME <= 0 or not FX_ENABLED then return end
pcall(function()
local px = ui.Size.X.Offset
if px <= 0 then return end
ui.Size = UDim2.new(0, px * LOCK_APPEAR_SCALE, 0, px * LOCK_APPEAR_SCALE)
TweenService:Create(ui,
TweenInfo.new(LOCK_APPEAR_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
{ Size = UDim2.new(0, px, 0, px) }):Play()
end)
end
local function burstLockUI(ui)
if not ui then return end
stopLockSpin(ui)
pcall(function()
local px = ui.Size.X.Offset
if px <= 0 then px = LOCK_UI_SIZE end
local info = TweenInfo.new(LOCK_BURST_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
TweenService:Create(ui, info, {
Size = UDim2.new(0, px * LOCK_BURST_SCALE, 0, px * LOCK_BURST_SCALE)
}):Play()
for _, d in ipairs(ui:GetDescendants()) do
if d:IsA("UIStroke") then
TweenService:Create(d, info, { Transparency = 1 }):Play()
elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
elseif d:IsA("TextLabel") then
TweenService:Create(d, info, { TextTransparency = 1 }):Play()
end
end
end)
task.delay(LOCK_BURST_TIME + 0.08, function()
pcall(ui.Destroy, ui)
end)
end
local function makeLockUI(part, offsetY)
local bg = Instance.new("BillboardGui")
bg.Name = "LockUI"
bg.Adornee = part
bg.Size = UDim2.new(0, LOCK_UI_SIZE, 0, LOCK_UI_SIZE)
bg.StudsOffset = Vector3.new(0, offsetY or 0, 0)
bg.AlwaysOnTop = true
bg.MaxDistance = MAX_DIST + 100
bg.LightInfluence = 0
bg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
bg.Enabled = true
bg.Parent = part.Parent or Workspace
local ring = Instance.new("Frame")
ring.Name = "Ring"
ring.Size = UDim2.new(1, 0, 1, 0)
ring.BackgroundTransparency = 1
ring.Parent = bg
local ringStroke = Instance.new("UIStroke")
ringStroke.Thickness = 2
ringStroke.Color = Color3.fromRGB(255, 60, 60)
ringStroke.Parent = ring
local ringCorner = Instance.new("UICorner")
ringCorner.CornerRadius = UDim.new(1, 0)
ringCorner.Parent = ring
local innerRing = Instance.new("Frame")
innerRing.Name = "InnerRing"
innerRing.Size = UDim2.new(0.6, 0, 0.6, 0)
innerRing.Position = UDim2.new(0.2, 0, 0.2, 0)
innerRing.BackgroundTransparency = 1
innerRing.Parent = bg
local innerStroke = Instance.new("UIStroke")
innerStroke.Thickness = 2
innerStroke.Color = Color3.fromRGB(255, 100, 100)
innerStroke.Parent = innerRing
local innerCorner = Instance.new("UICorner")
innerCorner.CornerRadius = UDim.new(1, 0)
innerCorner.Parent = innerRing
local hLine = Instance.new("Frame")
hLine.Name = "CrossH"
hLine.Size = UDim2.new(0.4, 0, 0.05, 0)
hLine.Position = UDim2.new(0.3, 0, 0.475, 0)
hLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
hLine.BorderSizePixel = 0
hLine.Parent = bg
local vLine = Instance.new("Frame")
vLine.Name = "CrossV"
vLine.Size = UDim2.new(0.05, 0, 0.4, 0)
vLine.Position = UDim2.new(0.475, 0, 0.3, 0)
vLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
vLine.BorderSizePixel = 0
vLine.Parent = bg
local CORNER_LEN = 0.22
local CORNER_THK = 0.06
for i = 1, 4 do
local isRight = (i == 2 or i == 4)
local isBottom = (i == 3 or i == 4)
local armH = Instance.new("Frame")
armH.Name = "ArmH" .. i
armH.Size = UDim2.new(CORNER_LEN, 0, CORNER_THK, 0)
armH.Position = UDim2.new(isRight and (1 - CORNER_LEN) or 0, 0,
isBottom and (1 - CORNER_THK) or 0, 0)
armH.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
armH.BorderSizePixel = 0
armH.Parent = bg
local armV = Instance.new("Frame")
armV.Name = "ArmV" .. i
armV.Size = UDim2.new(CORNER_THK, 0, CORNER_LEN, 0)
armV.Position = UDim2.new(isRight and (1 - CORNER_THK) or 0, 0,
isBottom and (1 - CORNER_LEN) or 0, 0)
armV.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
armV.BorderSizePixel = 0
armV.Parent = bg
end
startLockSpin(bg)
return bg
end
updateLockUIMaxDistance = function()
for _, ui in pairs(lockUI) do
pcall(function() ui.MaxDistance = MAX_DIST + 100 end)
end
end
updateLockUISize = function()
local myChar = lp.Character
local mh = myChar and getAimPart(myChar)
if not mh then return end
local myPos = mh.Position
for t, ui in pairs(lockUI) do
local ap = getAimPart(t)
if ap then
local px = LOCK_UI_SIZE * (30 / math.max((ap.Position - myPos).Magnitude, 8))
if px < LOCK_UI_MIN then px = LOCK_UI_MIN end
if px > LOCK_UI_MAX then px = LOCK_UI_MAX end
pcall(function() ui.Size = UDim2.new(0, px, 0, px) end)
end
end
end
showLockUI = function(t)
if lockUI[t] then return end
local aimPart = getAimPart(t)
if not aimPart then return end
local root = t:FindFirstChild("HumanoidRootPart")
if root then
lockUI[t] = makeLockUI(root, 2.2)
else
lockUI[t] = makeLockUI(aimPart, 0)
end
updateLockUISize()
playAppearLockUI(lockUI[t])
local hum = humOf(t)
if hum and not _deathConn[t] then
_deathConn[t] = hum.Died:Connect(function()
if target == t then
target = nil
_targetReady = false
_lockStart = 0
_scanValid = false
_scanRefreshAt = 0
end
hideLockUI(t)
end)
end
end
hideLockUI = function(t, burst)
local conn = _deathConn[t]
if conn then
pcall(conn.Disconnect, conn)
_deathConn[t] = nil
end
local ui = lockUI[t]
if ui then
lockUI[t] = nil
lockReady[t] = nil
if burst and FX_ENABLED then
burstLockUI(ui)
else
stopLockSpin(ui)
pcall(ui.Destroy, ui)
end
end
_losCache[t] = nil
end
clearAllLockUI = function()
for t, _ in pairs(lockUI) do hideLockUI(t) end
table.clear(_losCache)
end
setLockState = function(t, ready)
if lockReady[t] == ready then return end
lockReady[t] = ready
local ui = lockUI[t]
if not ui then return end
local ring = ui:FindFirstChild("Ring")
local innerRing = ui:FindFirstChild("InnerRing")
if ready then
pcall(function()
if ring and ring:FindFirstChildOfClass("UIStroke") then
ring:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(0, 255, 100)
end
if innerRing and innerRing:FindFirstChildOfClass("UIStroke") then
innerRing:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(0, 255, 100)
end
end)
else
pcall(function()
if ring and ring:FindFirstChildOfClass("UIStroke") then
ring:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(255, 60, 60)
end
if innerRing and innerRing:FindFirstChildOfClass("UIStroke") then
innerRing:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(255, 100, 100)
end
end)
end
end
local _filterCache = nil
local _filterDirty = true
local function invalidateFilterCache()
_filterDirty = true
_filterCache = nil
end
Players.PlayerAdded:Connect(function()
invalidateFilterCache()
end)
Players.PlayerRemoving:Connect(function()
invalidateFilterCache()
end)
local MAX_FILTER_ITEMS = 200
local USE_ZONE_CACHE_IN_FILTER = false
local OBSTRUCTION_BLACKLIST = {}
local function getObstructionBlacklist()
if #OBSTRUCTION_BLACKLIST > 0 then return OBSTRUCTION_BLACKLIST end
if SharedModuleFunctions
and type(SharedModuleFunctions._GunshotObstructionBlacklist) == "function" then
local ok2, r = pcall(function()
return SharedModuleFunctions._GunshotObstructionBlacklist()
end)
if ok2 and type(r) == "table" then
for _, v in ipairs(r) do
if v then OBSTRUCTION_BLACKLIST[#OBSTRUCTION_BLACKLIST + 1] = v end
end
end
end
if #OBSTRUCTION_BLACKLIST == 0 then
pcall(function()
local mc = Workspace:FindFirstChild("MapContainer")
if not mc then return end
for _, name in ipairs({ "Barriers", "Zones", "Spawn" }) do
local c = mc:FindFirstChild(name)
if c then OBSTRUCTION_BLACKLIST[#OBSTRUCTION_BLACKLIST + 1] = c end
end
end)
end
return OBSTRUCTION_BLACKLIST
end
local function buildFilterList()
if not _filterDirty and _filterCache then
return _filterCache
end
_filterDirty = false
local friendly, cursorFiltered = {}, {}
if PlayerUtility and type(PlayerUtility.GetFriendlyCharactersOfPlayer) == "function" then
local ok2, r = pcall(function() return PlayerUtility:GetFriendlyCharactersOfPlayer(lp, true) end)
if ok2 and type(r) == "table" then friendly = r end
end
if PlayerUtility and type(PlayerUtility.GetFriendlyPlayersOfPlayer) == "function" then
local ok2, r = pcall(function() return PlayerUtility:GetFriendlyPlayersOfPlayer(lp, true) end)
if ok2 and type(r) == "table" then
for _, p in ipairs(r) do
if p and p.Character then friendly[#friendly + 1] = p.Character end
end
end
end
if ClientCursor and type(ClientCursor.GetCursorRayFilteredDescendants) == "function" then
local ok2, r = pcall(function() return ClientCursor.GetCursorRayFilteredDescendants() end)
if ok2 and type(r) == "table" then cursorFiltered = r end
end
local combined
if QuickCreate and type(QuickCreate.CombineArrays) == "function" then
local ok2, r = pcall(function() return QuickCreate:CombineArrays(friendly, cursorFiltered) end)
if ok2 and type(r) == "table" then combined = r end
end
if not combined then
combined = {}
for _, v in ipairs(friendly) do combined[#combined + 1] = v end
for _, v in ipairs(cursorFiltered) do combined[#combined + 1] = v end
end
local list = {}
local n = 0
if lp.Character then n = n + 1; list[n] = lp.Character end
local bp = lp:FindFirstChildOfClass("Backpack")
if bp then n = n + 1; list[n] = bp end
for _, v in ipairs(getObstructionBlacklist()) do
n = n + 1; list[n] = v
end
local cosmetic = Workspace:FindFirstChild("CosmeticContainer")
if cosmetic then n = n + 1; list[n] = cosmetic end
if USE_ZONE_CACHE_IN_FILTER then
local zoneCache = nil
if ClientUtilities and type(ClientUtilities.GetZoneCache) == "function" then
local ok2, r = pcall(function() return ClientUtilities:GetZoneCache() end)
if ok2 and type(r) == "table" then zoneCache = r end
end
if zoneCache then
for _, v in ipairs(zoneCache) do
if n >= MAX_FILTER_ITEMS then break end
n = n + 1; list[n] = v
end
end
end
for _, v in ipairs(combined) do
if n >= MAX_FILTER_ITEMS then break end
n = n + 1; list[n] = v
end
if #combined == 0 and TEAM_CHECK then
for _, p in ipairs(Players:GetPlayers()) do
local c = p.Character
if n >= MAX_FILTER_ITEMS then break end
if c and c ~= lp.Character then n = n + 1; list[n] = c end
end
end
_filterCache = list
return list
end
local _rayParams = nil
local _rayParamsAt = 0
local function getRaycastParams()
local now = os.clock()
if _rayParams and not _filterDirty and (now - _rayParamsAt) < _RAYPARAMS_REBUILD then
return _rayParams
end
_rayParamsAt = now
local list = buildFilterList()
if not _rayParams then
local ok2, p = pcall(function()
if QuickCreate and type(QuickCreate.FastRaycastParams) == "function" then
return QuickCreate:FastRaycastParams(list, Enum.RaycastFilterType.Exclude, false, nil, false, false)
end
end)
if ok2 and typeof(p) == "RaycastParams" then
_rayParams = p
else
_rayParams = RaycastParams.new()
end
end
pcall(function()
_rayParams.FilterType = Enum.RaycastFilterType.Exclude
_rayParams.FilterDescendantsInstances = list
_rayParams.IgnoreWater = false
_rayParams.RespectCanCollide = false
end)
return _rayParams
end
local _LOS_CACHE_TTL_BLOCKED = 0.06
local _LOS_CACHE_THRESH = 2
local _losSource = "-"
local _rayCount = 0
local function ballisticPos(origin, v0, accel, t)
return origin + v0 * t + Vector3.new(accel.X * t * t / 2, accel.Y * t * t / 2, accel.Z * t * t / 2)
end
local _gravityVal = nil
local function getGravity()
if BALLISTIC_GRAVITY ~= 0 then return BALLISTIC_GRAVITY end
if not _gravityVal then
local okG, g = pcall(function() return Workspace.Gravity end)
_gravityVal = (okG and type(g) == "number") and g or 196.2
end
return _gravityVal
end
local function isInvisiblePartCollidable(p)
if not p or not p:IsA("BasePart") then return false end
if p.Transparency >= 1 then
return string.find(string.lower(p.Name), "collision", 1, true) == nil
end
return false
end
local function canBulletPierce(hit)
if not hit or not hit.Instance then return true end
local inst = hit.Instance
local model = inst:FindFirstAncestorWhichIsA("Model")
if model and model:FindFirstChildWhichIsA("Humanoid") then return false end
if inst:HasTag("fx_GlassFracture") then return true end
if inst.Parent and inst.Parent:HasTag("fx_GlassFracture") then return true end
return isInvisiblePartCollidable(inst)
end
local function raySegment(origin, delta, params)
_rayCount = _rayCount + 1
local hit = Workspace:Raycast(origin, delta, params)
if not PIERCE_ENABLED or not hit then return hit end
local from, rest = origin, delta
for _ = 1, PIERCE_MAX do
if not canBulletPierce(hit) then return hit end
rest = rest - (hit.Position - from)
local len = rest.Magnitude
if len <= PIERCE_STEP then return nil end
local unit = rest / len
from = hit.Position + unit * PIERCE_STEP
rest = rest - unit * PIERCE_STEP
_rayCount = _rayCount + 1
hit = Workspace:Raycast(from, rest, params)
if not hit then return nil end
end
return hit
end
local function ballisticRay(fromPos, toPos, params)
local delta = toPos - fromPos
local dist = delta.Magnitude
if dist < 0.01 then return nil end
local speed = BULLET_VELOCITY
if not speed or speed <= 0 then speed = BULLET_SPEED end
if not speed or speed <= 0 then speed = 1600 end
if RAY_ACCURACY <= 0 then
return raySegment(fromPos, delta, params)
end
local g = getGravity()
if g <= 0 then
return raySegment(fromPos, delta, params)
end
local tTotal = dist / speed
local drop = 0.5 * g * tTotal * tTotal
if drop <= DROP_SKIP_EPS then
return raySegment(fromPos, delta, params)
end
local segs = math.ceil(drop / SEG_DROP_STEP)
if segs < 2 then segs = 2 end
if segs > BALLISTIC_MAX_SEGMENTS then segs = BALLISTIC_MAX_SEGMENTS end
local accel = Vector3.new(0, -g, 0)
local v0 = delta.Unit * speed
local dt = tTotal / segs
local prev = fromPos
for i = 1, segs do
local t1 = dt * i
local cur
if i == segs then
cur = toPos
else
cur = ballisticPos(fromPos, v0, accel, t1)
end
local seg = cur - prev
if seg.Magnitude < 0.01 then break end
local hit = raySegment(prev, seg, params)
if hit then return hit end
prev = cur
end
return nil
end
local function getGameBodyHead()
if not ClientPlayerWrapper then return nil end
local ok2, ci = pcall(function() return ClientPlayerWrapper.CharacterInfo end)
if not ok2 or not ci then return nil end
local ok3, bp = pcall(function() return ci.BodyParts end)
if not ok3 or not bp then return nil end
local h = bp.Head
if not h then return nil end
if typeof(h) == "Vector3" then return h end
local ok4, p = pcall(function()
if h:IsA("BasePart") then return h.Position end
if h:IsA("Attachment") then return h.WorldPosition end
return nil
end)
if ok4 then return p end
return nil
end
local function getEquippedGun()
local c = lp.Character
if not c then return nil end
local tool = c:FindFirstChildWhichIsA("Tool")
if tool and hasMuzzle(tool) then return tool end
return nil
end
local _muzzleCache, _muzzleCacheAt, _muzzleCached = nil, 0, false
local function invalidateMuzzle()
_muzzleCache = nil
_muzzleCached = false
end
local function getMuzzlePart()
local now = os.clock()
if _muzzleCached and (now - _muzzleCacheAt) < 0.5 then
return _muzzleCache
end
_muzzleCacheAt = now
_muzzleCached = true
local m = nil
local gun = getEquippedGun()
if gun then
local cand = gun:FindFirstChild("Muzzle", true)
if cand and (cand:IsA("BasePart") or cand:IsA("Attachment")) then m = cand end
if not m then
local handle = gun:FindFirstChild("Handle") or gun:FindFirstChild("PrimaryPart")
if handle and handle:IsA("BasePart") then m = handle end
end
end
_muzzleCache = m
return m
end
local function hookMuzzleEvents(c)
if not c then return end
c.ChildAdded:Connect(function(ch)
if ch:IsA("Tool") or ch:IsA("Folder") or ch:IsA("Model") then invalidateMuzzle() end
end)
c.ChildRemoved:Connect(function(ch)
if ch:IsA("Tool") or ch:IsA("Folder") or ch:IsA("Model") then invalidateMuzzle() end
end)
end
hookMuzzleEvents(lp.Character)
local _lastVerifyTime = 0
local function onMyRespawn(c)
invalidateFilterCache()
invalidateMuzzle()
_rayParams = nil
_rayParamsAt = 0
if _aimPart then table.clear(_aimPart) end
table.clear(_losCache)
table.clear(_aimPick)
if target then hideLockUI(target) end
target = nil
_targetReady = false
_lockStart = 0
_losLostAt = 0
_lastLosTime = 0
_lastVerifyTime = 0
_scanValid = false
_scanRefreshAt = 0
end
lp.CharacterAdded:Connect(function(c)
onMyRespawn(c)
hookMuzzleEvents(c)
end)
local function getShootOrigin(myChar)
if AIM_RAY_FROM_MUZZLE then
local m = getMuzzlePart()
if m then
if m:IsA("BasePart") then return m.Position, "MUZZLE" end
return m.WorldPosition, "MUZZLE"
end
end
local ok1, gp = pcall(getGameBodyHead)
if ok1 and typeof(gp) == "Vector3" then return gp, "HEAD" end
local h = myChar and getAimPart(myChar)
if h then return h.Position, "HEAD" end
return nil, "-"
end
local function aimPartPos(model, name)
local p = model:FindFirstChild(name)
if p and p:IsA("BasePart") then return p end
local alt = PART_ALIAS[name]
if alt then
p = model:FindFirstChild(alt)
if p and p:IsA("BasePart") then return p end
end
return nil
end
local function aimOrder(model)
local first = AIM_PART_MAIN
if not AIM_PART_FALLBACK then
return { first }
end
local all = partListForRig(model)
local list = { first }
for _, n in ipairs(all) do
if n ~= first then list[#list + 1] = n end
end
return list
end
local function findVisiblePart(origin, targetModel, params)
local order = aimOrder(targetModel)
local first = nil
for i, name in ipairs(order) do
local p = aimPartPos(targetModel, name)
if p then
if not first then first = p end
local hit = ballisticRay(origin, p.Position, params)
if not hit or hit.Instance:IsDescendantOf(targetModel) then
return p, true
end
if not AIM_PART_FALLBACK then
return first, false
end
if EARLY_OUT_HEAD_BLOCK and i == 1 then
return first, false
end
end
end
return first, false
end
local function clearShotShooterStyle(myChar, targetModel, force)
if not myChar or not targetModel then return false end
if not RAY_ENABLED then
local ap = getAimPart(targetModel)
if ap then _aimPick[targetModel] = ap end
_losSource = "OFF"
return ap ~= nil
end
local origin, originTag = getShootOrigin(myChar)
if not origin then return false end
local tgAim = getAimPart(targetModel)
if not tgAim then return false end
local rough = tgAim.Position - origin
if rough.Magnitude > MAX_DIST then return false end
if rough.Magnitude < 0.5 then
_aimPick[targetModel] = tgAim
return true
end
local params = getRaycastParams()
local now = os.clock()
if not force then
local cache = _losCache[targetModel]
if cache then
local ttl = LOS_CACHE_TTL
if not cache.ready then ttl = LOS_CACHE_TTL * 1.2 end
if (now - cache.time) < ttl
and (cache.pos - tgAim.Position).Magnitude < _LOS_CACHE_THRESH
and (cache.my - origin).Magnitude < _LOS_CACHE_THRESH then
_losSource = "CACHE"
if cache.ready and cache.part then _aimPick[targetModel] = cache.part end
return cache.ready
end
end
end
_losSource = originTag
local part, ready = findVisiblePart(origin, targetModel, params)
if ready then
_aimPick[targetModel] = part
end
_losCache[targetModel] = {
ready = ready, part = part, pos = tgAim.Position, my = origin, time = now
}
return ready
end
local function getTargetHitPart(t)
local p = _aimPick[t]
if p and p.Parent then return p end
return getAimPart(t)
end
local _playerChars, _playerSet = {}, {}
local _npcChars, _npcSet = {}, {}
local function poolAdd(list, set, obj)
if set[obj] then return false end
set[obj] = true
list[#list + 1] = obj
return true
end
local function poolRemove(list, set, obj)
if not set[obj] then return end
set[obj] = nil
for i, v in ipairs(list) do
if v == obj then table.remove(list, i); break end
end
end
local _reviveConn = setmetatable({}, { __mode = "k" })
local function onNewCandidate()
if requestScan then requestScan() end
end
local function hookEnemyRespawn(c)
if not c or _reviveConn[c] then return end
local hum = humOf(c)
if not hum then return end
_reviveConn[c] = hum.Died:Connect(function()
_reviveConn[c] = nil
_losCache[c] = nil
_aimPick[c] = nil
_aimPart[c] = nil
if target == c then
hideLockUI(c)
target = nil
_targetReady = false
_lockStart = 0
_losLostAt = 0
_scanValid = false
_scanRefreshAt = 0
end
task.defer(function()
if not c.Parent then return end
local nh = humOf(c)
if nh and nh.Health > 0 then
_losCache[c] = nil
_aimPick[c] = nil
hookEnemyRespawn(c)
onNewCandidate()
end
end)
end)
end
local function hookPlayer(p)
if p.Character then poolAdd(_playerChars, _playerSet, p.Character) end
p.CharacterAdded:Connect(function(c)
poolAdd(_playerChars, _playerSet, c)
invalidateFilterCache()
_losCache[c] = nil
_aimPick[c] = nil
hookEnemyRespawn(c)
onNewCandidate()
end)
p.CharacterRemoving:Connect(function(c)
poolRemove(_playerChars, _playerSet, c)
_losCache[c] = nil
_aimPick[c] = nil
end)
end
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
Players.PlayerAdded:Connect(function(p)
hookPlayer(p)
invalidateFilterCache()
onNewCandidate()
end)
Players.PlayerRemoving:Connect(function(p)
if p.Character then poolRemove(_playerChars, _playerSet, p.Character) end
invalidateFilterCache()
end)
local function addNpcModel(m)
if not m or not m:IsA("Model") then return false end
if playerOf(m) then return false end
if m == lp.Character then return false end
if isExcludedModel(m) then return false end
if poolAdd(_npcChars, _npcSet, m) then onNewCandidate(); return true end
return false
end
local function scanNpcTree(root, depth)
if depth > 4 then return end
for _, c in ipairs(root:GetChildren()) do
if c:IsA("Model") then
addNpcModel(c)
elseif c:IsA("Folder") or c:IsA("Configuration") then
scanNpcTree(c, depth + 1)
end
end
end
local function addBotFromValue(ov)
if not ov or not ov:IsA("ObjectValue") then return end
local m = ov.Value
if m and m:IsA("Model") then
_botSet[m] = true
addNpcModel(m)
end
end
if BOT_FOLDER then
for _, ov in ipairs(BOT_FOLDER:GetChildren()) do addBotFromValue(ov) end
BOT_FOLDER.ChildAdded:Connect(function(ov)
addBotFromValue(ov)
invalidateTeamCache()
onNewCandidate()
end)
BOT_FOLDER.ChildRemoved:Connect(function(ov)
if ov:IsA("ObjectValue") and ov.Value then
poolRemove(_npcChars, _npcSet, ov.Value)
end
end)
for _, ov in ipairs(BOT_FOLDER:GetChildren()) do
if ov:IsA("ObjectValue") then
ov:GetPropertyChangedSignal("Value"):Connect(function()
addBotFromValue(ov)
invalidateTeamCache()
onNewCandidate()
end)
end
end
end
local function addTagHumanoid(h)
if not h or not h:IsA("Humanoid") then return end
if h.Health <= 0 then return end
local m = h.Parent
if not m or not m:IsA("Model") then return end
addNpcModel(m)
end
pcall(function()
for _, h in ipairs(CollectionService:GetTagged(TAG_DYN)) do
addTagHumanoid(h)
end
CollectionService:GetInstanceAddedSignal(TAG_DYN):Connect(function(h)
addTagHumanoid(h)
invalidateTeamCache()
onNewCandidate()
end)
CollectionService:GetInstanceRemovedSignal(TAG_DYN):Connect(function(h)
local m = h.Parent
if not m or not m:IsA("Model") then return end
poolRemove(_npcChars, _npcSet, m)
_losCache[m] = nil
_aimPick[m] = nil
_aimPart[m] = nil
if target == m then
hideLockUI(m)
target = nil
_targetReady = false
_lockStart = 0
_losLostAt = 0
_scanValid = false
_scanRefreshAt = 0
end
end)
end)
if NPC_ROOT then
scanNpcTree(NPC_ROOT, 0)
NPC_ROOT.DescendantAdded:Connect(function(d)
if d:IsA("Model") then addNpcModel(d) end
end)
NPC_ROOT.DescendantRemoving:Connect(function(d)
if d:IsA("Model") then poolRemove(_npcChars, _npcSet, d) end
end)
end
Workspace.DescendantAdded:Connect(function(d)
if d:IsA("Model") and isBotModel(d) then addNpcModel(d) end
end)
Workspace.DescendantRemoving:Connect(function(d)
if d:IsA("Model") then poolRemove(_npcChars, _npcSet, d) end
end)
local function ensureEnemyHooked(c)
if not _reviveConn[c] then hookEnemyRespawn(c) end
end
local _candBuf = {}
local function collectCandidates()
table.clear(_candBuf)
local myChar = lp.Character
if not myChar then return 0 end
local mh = getAimPart(myChar)
if not mh then return 0 end
local fromPos = mh.Position
local n = 0
local function collect(c)
if c == myChar or not c.Parent then return end
if not alive(c) then return end
if isTeam(c) then return end
if not canAttack(c) then return end
local aimPart = getAimPart(c)
if not aimPart then return end
ensureEnemyHooked(c)
local d = (aimPart.Position - fromPos).Magnitude
if d > MAX_DIST then return end
n = n + 1
_candBuf[n] = {
c = c,
d = d,
dot = aimPart.Position - fromPos,
}
end
for _, c in ipairs(_playerChars) do collect(c) end
for _, c in ipairs(_npcChars) do collect(c) end
if n > 1 then
local cam = Workspace.CurrentCamera
if cam then
local cd = cam.CFrame.LookVector
table.sort(_candBuf, function(a, b)
if math.abs(a.d - b.d) > 8 then return a.d < b.d end
return a.dot:Dot(cd) > b.dot:Dot(cd)
end)
else
table.sort(_candBuf, function(a, b) return a.d < b.d end)
end
end
return n
end
local _scanQueue = {}
local _scanIdx = 1
local _lastFullScan = 0
local function refreshNpcPool()
for i = #_npcChars, 1, -1 do
local m = _npcChars[i]
if isExcludedModel(m) then
poolRemove(_npcChars, _npcSet, m)
end
end
if BOT_FOLDER then
pcall(function()
for _, ov in ipairs(BOT_FOLDER:GetChildren()) do
if ov:IsA("ObjectValue") and ov.Value and ov.Value:IsA("Model") and not isExcludedModel(ov.Value) then
_botSet[ov.Value] = true
poolAdd(_npcChars, _npcSet, ov.Value)
end
end
end)
end
pcall(function()
for _, h in ipairs(CollectionService:GetTagged(TAG_DYN)) do
if h.Health > 0 then
local m = h.Parent
if m and m:IsA("Model") and not playerOf(m) and not isExcludedModel(m) then
poolAdd(_npcChars, _npcSet, m)
end
end
end
end)
local now = os.clock()
if now - _lastFullScan >= 1 then
_lastFullScan = now
pcall(function()
for _, desc in ipairs(Workspace:GetDescendants()) do
if desc:IsA("Humanoid") then
local m = desc.Parent
if m and m:IsA("Model") and isBotModel(m) then
poolAdd(_npcChars, _npcSet, m)
end
end
end
end)
end
end
local function rebuildScanQueue()
refreshNpcPool()
local n = collectCandidates()
table.clear(_scanQueue)
for i = 1, n do _scanQueue[i] = _candBuf[i] end
_scanIdx = 1
_scanValid = (n > 0)
_scanRefreshAt = os.clock()
end
local function stepScan(myChar)
if not _scanValid then
if SCAN_REFRESH > 0 and (os.clock() - _scanRefreshAt) < SCAN_REFRESH then
return nil
end
rebuildScanQueue()
if not _scanValid then return nil end
end
local deadline = os.clock() + SCAN_BUDGET
local q = _scanQueue
local n = #q
while _scanIdx <= n do
local e = q[_scanIdx]
_scanIdx = _scanIdx + 1
if e and e.c and e.c.Parent and alive(e.c) then
if clearShotShooterStyle(myChar, e.c) then
return e.c
end
end
if os.clock() >= deadline then break end
end
if _scanIdx > n then
_scanValid = false
end
return nil
end
local PR, PR_OK = nil, false
pcall(function()
local refs = Replicated:FindFirstChild("REFERENCES")
if refs then
PR = require(refs:FindFirstChild("PacketReference"))
PR_OK = PR ~= nil
end
end)
local function nowStamp()
local ok, t = pcall(function() return Workspace:GetServerTimeNow() end)
if ok and type(t) == "number" and t > 0 then return t end
return tick()
end
local function fire(t)
local gun = getEquippedGun() or getGun()
if not gun then return false end
local mH = lp.Character and getAimPart(lp.Character)
local tH = getTargetHitPart(t) or getAimPart(t)
if not mH or not tH then return false end
local origin = getShootOrigin(lp.Character)
if not origin then origin = mH.Position end
local shootDir = tH.Position - origin
if shootDir.Magnitude < 0.001 then return false end
shootDir = shootDir.Unit
local stamp = nowStamp()
pcall(function()
local shootSound = Instance.new("Sound")
shootSound.SoundId = "rbxassetid://8679627751"
shootSound.Volume = 1
shootSound.PlayOnRemove = false
shootSound.Parent = Workspace
shootSound:Play()
task.delay(3, function()
pcall(shootSound.Destroy, shootSound)
end)
end)
if FX_ENABLED then
local tracerStart
local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
if hrp then
local randomDir = Vector3.new(
math.random(-100, 100) / 100,
math.random(-30, 30) / 100,
math.random(-100, 100) / 100
).Unit
local randomDist = math.random(1, 10)
local candidatePos = hrp.Position + (randomDir * randomDist)
local hit = Workspace:Raycast(origin, candidatePos - origin, getRaycastParams())
if hit then
tracerStart = hit.Position - (hit.Normal * 0.5)
else
tracerStart = candidatePos
end
else
tracerStart = origin + (shootDir * math.min(TRACER_LENGTH, 10))
end
drawTracer(tracerStart, tH.Position)
end
local data = {
Gun = gun,
Vector = shootDir,
epoch = stamp,
bulletOrigin = origin,
bulletEnd = tH.Position,
rngSeed = math.random(0, 255),
otherCharacter = t,
hitLimb = tH.Name,
hitTimestamp = stamp,
clientHitPosition = tH.Position,
clientVictimPosition = (t.PrimaryPart and t.PrimaryPart.Position) or tH.Position
}
sent = sent + 1
if PR_OK then
task.spawn(function()
pcall(function()
local r = PR.ShootRegistration
if r and r.send then r.send(data) end
task.wait(PACKET_DELAY)
local g = PR.ReplicateGunShot
if g and g.send then g.send(data) end
task.wait(PACKET_DELAY)
local h = PR.gunshotCharacterHit
if h and h.send then h.send(data) end
end)
end)
else
pcall(function()
local h = t:FindFirstChildWhichIsA("Humanoid")
if h then h:TakeDamage(10) end
end)
end
return true
end
local function startReload()
state = "RELOAD"
reloadUntil = os.clock() + RELOAD_TIME
if target then hideLockUI(target, true) end
target = nil
_targetReady = false
_lockStart = 0
_losLostAt = 0
_lastLosTime = 0
_lastVerifyTime = 0
_scanValid = false
_scanRefreshAt = 0
end
requestScan = function()
_scanValid = false
_scanRefreshAt = 0
end
local _lastFireTime = 0
local _MIN_FIRE_INTERVAL = 3.0
local function hookMyDeath(c)
if not c then return end
local hum = c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid", 5)
if not hum then return end
hum.Died:Connect(function()
reloadUntil = 0
state = "IDLE"
clearAllLockUI()
target = nil
_targetReady = false
_lockStart = 0
_losLostAt = 0
_lastLosTime = 0
_lastVerifyTime = 0
_lastFireTime = 0
_scanValid = false
_scanRefreshAt = 0
end)
end
if lp.Character then hookMyDeath(lp.Character) end
lp.CharacterAdded:Connect(function(c)
task.wait(0.3)
hookMyDeath(c)
end)
RunService.Heartbeat:Connect(function(dt)
updateCooldownBar()
if not running then return end
local now = os.clock()
if state == "IDLE" then
if target and (now - _lastVerifyTime) >= 0.2 then
_lastVerifyTime = now
local myChar = lp.Character
local tH = getAimPart(target)
local myHeadPart = myChar and myChar:FindFirstChild("Head")
if not alive(target) or isTeam(target) or not canAttack(target) then
hideLockUI(target); target = nil; _targetReady = false
_lockStart = 0; _losLostAt = 0
elseif not tH or (myHeadPart and (myHeadPart.Position - tH.Position).Magnitude > MAX_DIST) then
hideLockUI(target); target = nil; _targetReady = false
_lockStart = 0; _losLostAt = 0
end
end
if not target then
local scanChar = lp.Character
if scanChar then
local t = stepScan(scanChar)
if t then
target = t
_targetReady = true
_lockStart = now
_losLostAt = 0
_lastLosTime = now
showLockUI(t)
end
end
end
if target then
local myChar = lp.Character
if myChar then
if RAY_ACCURACY <= 0 then
if (now - _lastLosTime) >= 0.12 then
_lastLosTime = now
_targetReady = clearShotShooterStyle(myChar, target)
end
elseif (now - _lastLosTime) >= _LOS_INTERVAL then
_lastLosTime = now
_targetReady = clearShotShooterStyle(myChar, target)
setLockState(target, _targetReady)
end
if not _targetReady then
if _losLostAt == 0 then
_losLostAt = now
elseif LOS_RELEASE_GRACE <= 0 or (now - _losLostAt) >= LOS_RELEASE_GRACE then
hideLockUI(target)
target = nil
_targetReady = false
_lockStart = 0
_losLostAt = 0
_lastLosTime = 0
_scanValid = false
_scanRefreshAt = 0
local nt = stepScan(myChar)
if nt then
target = nt
_targetReady = true
_lockStart = now
showLockUI(nt)
end
end
else
_losLostAt = 0
end
if target then
if not _targetReady then
_lockStart = 0
elseif _lockStart == 0 then
_lockStart = now
end
local confirmed = _targetReady
and (LOCK_CONFIRM_TIME <= 0 or (now - _lockStart) >= LOCK_CONFIRM_TIME)
if confirmed and (now - _lastFireTime) >= _MIN_FIRE_INTERVAL then
_lastFireTime = now
if clearShotShooterStyle(myChar, target, true) then
if fire(target) then
startReload()
end
else
if target then hideLockUI(target) end
target = nil
_targetReady = false
_lockStart = 0
_losLostAt = 0
_lastLosTime = 0
_scanValid = false
_scanRefreshAt = 0
end
end
end
end
end
elseif state == "RELOAD" then
if target then
hideLockUI(target)
target = nil
_targetReady = false
_lockStart = 0
end
if now >= reloadUntil then
_targetReady = false
_lockStart = 0
_losLostAt = 0
_lastLosTime = 0
_lastVerifyTime = 0
_scanValid = false
_scanRefreshAt = 0
state = "IDLE"
end
end
end)
UserInput.InputBegan:Connect(function(i, g)
if g then return end
if i.KeyCode == Enum.KeyCode.P then
running = not running
if not running then
clearAllLockUI()
target = nil
_targetReady = false
state = "IDLE"
end
end
end)
Library:Notify("GR 功能已加载（默认关闭）", 3)
end
