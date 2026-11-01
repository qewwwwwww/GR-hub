return function(Library, Window, GHub)
local C = {}
 C.genv = (type(getgenv) == "function") and getgenv() or _G
GHub = GHub or C.genv.GRHub
 C.RunService = game:GetService("RunService")
 C.UserInput = game:GetService("UserInputService")
 C.Workspace = game:GetService("Workspace")
 C.Players = game:GetService("Players")
 C.Replicated = game:GetService("ReplicatedStorage")
 C.TweenService = game:GetService("TweenService")
 C.CollectionService = game:GetService("CollectionService")
 C.Debris = game:GetService("Debris")
 C.lp = C.Players.LocalPlayer
 C.LOG_ENABLED = false
 C.FX_ENABLED = true
 C.USE_NATIVE_TRACER = false
 C.BULLET_SPEED = 1600
 C.BULLET_VELOCITY = nil
pcall(function() C.BULLET_VELOCITY = workspace:GetAttribute("BulletVelocity") end)
pcall(function()
workspace:GetAttributeChangedSignal("BulletVelocity"):Connect(function()
C.BULLET_VELOCITY = workspace:GetAttribute("BulletVelocity")
end)
end)
 C.BALLISTIC_GRAVITY = 0
 C.DROP_SKIP_EPS = 0.15
 C.SEG_DROP_STEP = 0.6
 C.BALLISTIC_MAX_SEGMENTS = 6
 C.PART_LABEL = {
Head = "头部 Head",
UpperTorso = "上胸 UpperTorso",
Torso = "躯干 Torso",
HumanoidRootPart = "根节点 Root",
LowerTorso = "下腹 LowerTorso",
}
 C.PART_LABEL_REV = {}
for k, v in pairs(C.PART_LABEL) do C.PART_LABEL_REV[v] = k end
 C.PART_ALIAS = {
UpperTorso = "Torso",
LowerTorso = "Torso",
Torso = "UpperTorso",
}
 C.RIG_TYPE = nil
local function detectRig(model)
if not model then return nil end
if model:FindFirstChild("UpperTorso") or model:FindFirstChild("LowerTorso") then
return "R15"
end
if model:FindFirstChild("Torso") then return "R6" end
return nil
end
local function currentRig()
if C.RIG_TYPE then return C.RIG_TYPE end
local m = C.lp.Character
local r = detectRig(m)
if not r then
for _, p in ipairs(C.Players:GetPlayers()) do
r = detectRig(p.Character)
if r then break end
end
end
C.RIG_TYPE = r or "R6"
return C.RIG_TYPE
end
local function partListForRig(model)
local r = model and detectRig(model) or currentRig()
if r == "R15" then
return { "Head", "UpperTorso", "Torso", "HumanoidRootPart", "LowerTorso" }
end
return { "Head", "Torso", "HumanoidRootPart" }
end
 C.AIM_PART_MAIN = "Head"
 C.AIM_PART_FALLBACK = true
 C.RAY_ACCURACY = 4
 C.LOS_CACHE_TTL = 0.05
 C.EVICT_EVERY = 0.005
 C.MULTI_PART_AIM = true
 C.HEADSHOT_ONLY = false
 C.EARLY_OUT_HEAD_BLOCK = false
 C.PIERCE_ENABLED = true
 C.PIERCE_MAX = 3
 C.PIERCE_STEP = 0.05
 C.LOS_RELEASE_GRACE = 0.15
 C._LOS_INTERVAL = 0.01
 C._RAYPARAMS_REBUILD = 2.0
 C.SCAN_BUDGET = 0.003
local SCAN_REFRESH = 0
 C.LOCK_CONFIRM_TIME = 0.35
 C.LOCK_UI_SIZE = 42
 C.LOCK_UI_MIN = 16
 C.LOCK_UI_MAX = 70
 C.RAY_ENABLED = true
 C.RELOAD_TIME = 7.0
 C.PACKET_DELAY = 0.1
 C.MAX_DIST = 300
 C.SLIDER_MIN = 50
 C.SLIDER_MAX = 10000
 C.TRACER_LENGTH = 15
 C.TRACER_LIFETIME = 1.5
 C.SLIDER_MIN_COOLDOWN = 1
 C.SLIDER_MAX_COOLDOWN = 20
 C.TEAM_CHECK = false
 C.ATTACK_BOTS = false
 C.ATTACK_PLAYERS = false
 C.BOT_FOLDER = nil
pcall(function()
local gi = workspace:FindFirstChild("GameInfo")
if gi then C.BOT_FOLDER = gi:FindFirstChild("LivingBotPlayers") end
end)
 C._botSet = setmetatable({}, { __mode = "k" })
 C.TAG_DYN = "fx_DynamicHumanoid"
 C.NPC_ROOT = nil
pcall(function()
if workspace.MapContainer and workspace.MapContainer.Special then
C.NPC_ROOT = workspace.MapContainer.Special:FindFirstChild("NPC_Container")
end
end)
 C.EXCLUDE_ROOTS = {}
 C.WHITELIST_GROUP_ROOTS = {}
 C.GROUP_KEYWORDS = { "spooky", "hollow" }
 C.PART_LIKE_NAMES = {
"head", "torso", "uppertorso", "lowertorso",
"humanoidrootpart", "rootpart",
"leftarm", "rightarm", "leftleg", "rightleg",
"leftupperarm", "rightupperarm", "leftlowerarm", "rightlowerarm",
"leftupperleg", "rightupperleg", "leftlowerleg", "rightlowerleg",
"leftfoot", "rightfoot", "lefthand", "righthand",
}
pcall(function()
local mc = workspace.MapContainer
if mc then
local sp = mc:FindFirstChild("Special")
if sp then
local nd = sp:FindFirstChild("NPC_Data")
if nd then C.WHITELIST_GROUP_ROOTS[#C.WHITELIST_GROUP_ROOTS + 1] = nd end
end
local misc = mc:FindFirstChild("Miscellaneous")
if misc then
local cb = misc:FindFirstChild("Special_ColonistBodies")
if cb then C.EXCLUDE_ROOTS[#C.EXCLUDE_ROOTS + 1] = cb end
end
end
end)
 C._excludeCache = setmetatable({}, { __mode = "k" })
local function isExcludedModel(m)
if not m then return false end
if #C.EXCLUDE_ROOTS == 0 and #C.WHITELIST_GROUP_ROOTS == 0 then return false end
local v = C._excludeCache[m]
if v ~= nil then return v end
local res = false
for _, root in ipairs(C.EXCLUDE_ROOTS) do
if m:IsDescendantOf(root) then
res = true
break
end
end
if not res then
for _, root in ipairs(C.WHITELIST_GROUP_ROOTS) do
if m:IsDescendantOf(root) then
local hit = false
local node = m
while node do
local nn = string.lower(node.Name or "")
for _, kw in ipairs(C.GROUP_KEYWORDS) do
if string.find(nn, kw, 1, true) then
hit = true
break
end
end
if hit then break end
if node == root then break end
node = node.Parent
end
if not hit then res = true end
break
end
end
end
if not res then
local n = string.lower(m.Name or "")
for _, pk in ipairs(C.PART_LIKE_NAMES) do
if string.find(n, pk, 1, true) then
res = true
break
end
end
end
C._excludeCache[m] = res
return res
end
 C.BOT_KEYWORDS = { "bot", "npc", "dummy", "mob_", "zombie", "monster", "ai", "summon", "minion" }
 C.NPC_KEYS = { "bot", "npc", "dummy", "ai", "summon", "minion" }
 C.running = false
 C.state = "IDLE"
 C.target = nil
 C.reloadUntil = 0
 C.sent = 0
 C._targetReady = false
 C._lockStart = 0
 C._lastLosTime = 0
 C._losLostAt = 0
 C._scanValid = false
 C._scanRefreshAt = 0
 C.ecoOn = false
 C.ClientCursor = nil
 C.PlayerUtility = nil
 C.QuickCreate = nil
 C.CrossPlatformMethods = nil
 C.ClientUtilities = nil
 C.SharedModuleFunctions = nil
 C.ProjectileUtility = nil
 C.ActiveCast = nil
 C.ClientPlayerWrapper = nil
pcall(function()
local ok, mod = pcall(function() return require(C.Replicated.MODULES.ClientCursor) end)
if ok and mod then C.ClientCursor = mod end
ok, mod = pcall(function() return require(C.Replicated.MODULES.PlayerUtility) end)
if ok and mod then C.PlayerUtility = mod end
ok, mod = pcall(function() return require(C.Replicated.MODULES.QuickCreate) end)
if ok and mod then C.QuickCreate = mod end
ok, mod = pcall(function() return require(C.Replicated.MODULES.CrossPlatformMethods) end)
if ok and mod then C.CrossPlatformMethods = mod end
ok, mod = pcall(function() return require(C.Replicated.MODULES.ClientUtilities) end)
if ok and mod then C.ClientUtilities = mod end
ok, mod = pcall(function() return require(C.Replicated.MODULES.ProjectileUtility) end)
if ok and mod then C.ProjectileUtility = mod end
ok, mod = pcall(function() return require(C.Replicated.MODULES.ClientPlayerWrapper) end)
if ok and mod then C.ClientPlayerWrapper = mod end
ok, mod = pcall(function()
local pu = C.Replicated:FindFirstChild("MODULES")
pu = pu and pu:FindFirstChild("ProjectileUtility")
if not pu then return nil end
for _, node in ipairs(pu:GetDescendants()) do
if node:IsA("ModuleScript") and node.Name == "SharedModuleFunctions" then
return require(node)
end
end
return nil
end)
if ok and mod then C.SharedModuleFunctions = mod end
end)
 C.clearAllLockUI = nil
local hideLockUI, showLockUI
 C.startLockSpin = nil
local stopLockSpin
 C.setLockState = nil
local updateLockUISize, updateLockUIMaxDistance
 C.requestScan = nil
 C.lockUI = {}
 C.lockReady = {}
 C._deathConn = setmetatable({}, { __mode = "k" })
 C._lockTw = setmetatable({}, { __mode = "k" })
 C._losCache = setmetatable({}, { __mode = "k" })
 C._aimPick = setmetatable({}, { __mode = "k" })
updateLockUIMaxDistance = function() end
C.requestScan = function() end
C.clearAllLockUI = function() end
hideLockUI = function() end
showLockUI = function() end
C.startLockSpin = function() end
stopLockSpin = function() end
C.setLockState = function() end
updateLockUISize = function() end
local AimTab = Window:AddTab("枪械", "crosshair")
local MiscTab = Window:AddTab("杂项", "settings")
 C.aL = AimTab:AddLeftGroupbox("ragebot", "power")
 C.aR = AimTab:AddRightGroupbox("射击参数", "crosshair")
C.aL:AddToggle("swFire", {
Text = "启动",
Default = false,
Tooltip = "关闭后只锁定",
Callback = function(v)
C.running = v
if not C.running then
C.clearAllLockUI()
C.target = nil
C._targetReady = false
C.state = "IDLE"
end
end,
})
C.aL:AddToggle("swTeam", {
Text = "队伍检测",
Default = false,
Callback = function(v) C.TEAM_CHECK = v end,
})
C.aL:AddToggle("swBots", {
Text = "攻击Bot",
Default = false,
Callback = function(v)
C.ATTACK_BOTS = v
C.requestScan()
end,
})
C.aL:AddToggle("swPlr", {
Text = "攻击玩家",
Default = false,
Callback = function(v)
C.ATTACK_PLAYERS = v
C.requestScan()
end,
})
C.aR:AddSlider("sldLock", {
Text = "锁定时间",
Default = C.LOCK_CONFIRM_TIME,
Min = 0,
Max = 1,
Rounding = 2,
Suffix = " s",
Callback = function(v) C.LOCK_CONFIRM_TIME = v end,
})
C.aR:AddSlider("sldCool", {
Text = "换弹冷却",
Default = C.RELOAD_TIME,
Min = C.SLIDER_MIN_COOLDOWN,
Max = C.SLIDER_MAX_COOLDOWN,
Rounding = 1,
Suffix = " s",
Callback = function(v) C.RELOAD_TIME = v end,
})
C.aR:AddSlider("sldDist", {
Text = "射击距离",
Default = C.MAX_DIST,
Min = C.SLIDER_MIN,
Max = C.SLIDER_MAX,
Rounding = 0,
Suffix = " studs",
Callback = function(v)
C.MAX_DIST = v
if updateLockUIMaxDistance then updateLockUIMaxDistance() end
C.requestScan()
end,
})
 C.rL = AimTab:AddLeftGroupbox("射线设置", "eye")
 C.rR = AimTab:AddRightGroupbox("高级选项", "sliders-horizontal")
 C.partOptions = {}
for _, n in ipairs(partListForRig()) do
C.partOptions[#C.partOptions + 1] = C.PART_LABEL[n] or n
end
C.rL:AddToggle("swRay", {
Text = "射线锁定",
Default = true,
Callback = function(v)
C.RAY_ENABLED = v
C._losCache = setmetatable({}, { __mode = "k" })
C.requestScan()
end,
})
C.rL:AddDropdown("ddPart", {
Text = "瞄准部位",
Default = C.PART_LABEL[C.AIM_PART_MAIN] or "头部 Head",
Values = C.partOptions,
Callback = function(v)
local name = C.PART_LABEL_REV[v]
if name then C.AIM_PART_MAIN = name end
C._aimPick = setmetatable({}, { __mode = "k" })
C._losCache = setmetatable({}, { __mode = "k" })
end,
})
C.rL:AddToggle("swFallback", {
Text = "挡头换部位",
Default = false,
Callback = function(v)
C.AIM_PART_FALLBACK = v
C._losCache = setmetatable({}, { __mode = "k" })
end,
})
C.rL:AddSlider("sldSpeed", {
Text = "扫描速度",
Default = 5,
Min = 1,
Max = 5,
Rounding = 0,
Callback = function(v)
C.EVICT_EVERY = ({ 0.12, 0.06, 0.03, 0.015, 0.005 })[v] or 0.03
C._LOS_INTERVAL = ({ 0.12, 0.06, 0.03, 0.02, 0.01 })[v] or 0.03
end,
})
C.rL:AddSlider("sldPrec", {
Text = "射线模式",
Default = 4,
Min = 0,
Max = 4,
Rounding = 0,
Callback = function(v) C.RAY_ACCURACY = v end,
})
C.rR:AddToggle("swPierce", {
Text = "穿透透明",
Default = true,
Callback = function(v) C.PIERCE_ENABLED = v end,
})
C.rR:AddToggle("swTracer", {
Text = "弹道特效",
Default = true,
Callback = function(v)
C.FX_ENABLED = v
for _, ui in pairs(C.lockUI) do
if C.FX_ENABLED then C.startLockSpin(ui) else stopLockSpin(ui) end
end
end,
})
C.rR:AddToggle("swEco", {
Text = "省电模式",
Default = false,
Callback = function(v)
C.ecoOn = v
if C.ecoOn then
C._LOS_INTERVAL, SCAN_REFRESH = 0.2, 0.6
else
C._LOS_INTERVAL, SCAN_REFRESH = 0.06, 0
end
end,
})
 C.getGunDiag = nil
 C.nowStamp = nil
 C.mL = MiscTab:AddLeftGroupbox("状态", "activity")
 C.mR = MiscTab:AddRightGroupbox("操作", "wrench")
 C.diagLabel = C.mL:AddLabel("等待数据...")
C.mR:AddButton({
Text = "立即重扫",
Func = function()
if C.requestScan then C.requestScan() end
Library:Notify("已请求重新扫描", 3)
end,
})
C.mR:AddButton({
Text = "恢复默认设置",
Func = function()
local O = Library.Options
if O.swFire then O.swFire:SetValue(false) end
if O.swTeam then O.swTeam:SetValue(false) end
if O.swBots then O.swBots:SetValue(false) end
if O.swPlr then O.swPlr:SetValue(false) end
if O.swRay then O.swRay:SetValue(true) end
if O.swFallback then O.swFallback:SetValue(false) end
if O.swPierce then O.swPierce:SetValue(true) end
if O.swTracer then O.swTracer:SetValue(true) end
if O.swEco then O.swEco:SetValue(false) end
if O.ddPart then O.ddPart:SetValue(C.PART_LABEL["Head"]) end
if O.sldLock then O.sldLock:SetValue(0.35) end
if O.sldCool then O.sldCool:SetValue(7) end
if O.sldDist then O.sldDist:SetValue(300) end
if O.sldSpeed then O.sldSpeed:SetValue(5) end
if O.sldPrec then O.sldPrec:SetValue(4) end
if C.requestScan then C.requestScan() end
Library:Notify("已恢复默认", 3)
end,
})
 C.cooldownGui = Instance.new("ScreenGui")
C.cooldownGui.Name = "GRCooldownBar"
C.cooldownGui.ResetOnSpawn = false
C.cooldownGui.IgnoreGuiInset = true
C.cooldownGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
C.cooldownGui.Parent = C.lp:WaitForChild("PlayerGui")
end)
 C.barFrame = Instance.new("Frame")
C.barFrame.Name = "BarFrame"
C.barFrame.Size = UDim2.new(0, 260, 0, 14)
C.barFrame.Position = UDim2.new(0.5, -130, 1, -100)
C.barFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
C.barFrame.BackgroundTransparency = 0.4
C.barFrame.BorderSizePixel = 0
C.barFrame.Visible = false
C.barFrame.Parent = C.cooldownGui
 C.barCorner = Instance.new("UICorner")
C.barCorner.CornerRadius = UDim.new(0, 4)
C.barCorner.Parent = C.barFrame
 C.barFill = Instance.new("Frame")
C.barFill.Name = "Fill"
C.barFill.Size = UDim2.new(0, 0, 1, 0)
C.barFill.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
C.barFill.BorderSizePixel = 0
C.barFill.Parent = C.barFrame
 C.fillCorner = Instance.new("UICorner")
C.fillCorner.CornerRadius = UDim.new(0, 4)
C.fillCorner.Parent = C.barFill
 C.barText = Instance.new("TextLabel")
C.barText.Name = "Text"
C.barText.Size = UDim2.new(1, 0, 1, 0)
C.barText.BackgroundTransparency = 1
C.barText.TextColor3 = Color3.fromRGB(255, 255, 255)
C.barText.Font = Enum.Font.GothamBold
C.barText.TextSize = 11
C.barText.Text = ""
C.barText.Parent = C.barFrame
local function updateCooldownBar()
if not C.running then
C.barFrame.Visible = false
return
end
C.barFrame.Visible = true
local now = os.clock()
if C.state == "RELOAD" then
local remain = C.reloadUntil - now
if remain < 0 then remain = 0 end
local ratio = 1 - (remain / C.RELOAD_TIME)
if ratio < 0 then ratio = 0 end
if ratio > 1 then ratio = 1 end
C.barFill.Size = UDim2.new(ratio, 0, 1, 0)
C.barFill.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
C.barText.Text = string.format("换弹冷却 %.1fs", remain)
else
C.barFill.Size = UDim2.new(1, 0, 1, 0)
C.barFill.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
C.barText.Text = "可射击"
end
end
 C._playerOf = setmetatable({}, { __mode = "k" })
 C._humOf = setmetatable({}, { __mode = "k" })
 C._isNpc = setmetatable({}, { __mode = "k" })
 C._rootsTick = 0
 C._rootSig = ""
local function resolveRoots()
local mc = workspace:FindFirstChild("MapContainer")
if not mc then return false end
local sig = ""
local newEx, newWl = {}, {}
local sp = mc:FindFirstChild("Special")
if sp then
local nd = sp:FindFirstChild("NPC_Data")
if nd then
newWl[#newWl + 1] = nd
sig = sig .. "W" .. tostring(nd)
end
local nc = sp:FindFirstChild("NPC_Container")
if nc then C.NPC_ROOT = nc end
end
local misc = mc:FindFirstChild("Miscellaneous")
if misc then
local cb = misc:FindFirstChild("Special_ColonistBodies")
if cb then
newEx[#newEx + 1] = cb
sig = sig .. "E" .. tostring(cb)
end
end
local gi = workspace:FindFirstChild("GameInfo")
if gi then
local bf = gi:FindFirstChild("LivingBotPlayers")
if bf then C.BOT_FOLDER = bf end
end
if sig == C._rootSig then return false end
C._rootSig = sig
C.EXCLUDE_ROOTS = newEx
C.WHITELIST_GROUP_ROOTS = newWl
table.clear(C._excludeCache)
table.clear(C._isNpc)
table.clear(C._aimPick)
table.clear(C._losCache)
table.clear(C._humOf)
return true
end
local function playerOf(c)
if not c then return nil end
local v = C._playerOf[c]
if v ~= nil then return v end
v = C.Players:GetPlayerFromCharacter(c)
C._playerOf[c] = v
return v
end
local function humOf(c)
if not c then return nil end
local h = C._humOf[c]
if h and h.Parent then return h end
h = c:FindFirstChildWhichIsA("Humanoid")
if h then C._humOf[c] = h end
return h
end
local function isTeam(c)
if not C.TEAM_CHECK then return false end
if not c or c == C.lp.Character then return false end
if workspace:GetAttribute("Round_FriendlyFire") then return false end
local p = playerOf(c)
if not p then return false end
if p == C.lp then return false end
local mt, pt = C.lp.Team, p.Team
if mt and pt then return mt == pt end
return C.lp.TeamColor == p.TeamColor
end
local function isBotModel(model)
if not model or not model:IsA("Model") then return false end
if C.Players:GetPlayerFromCharacter(model) then return false end
if isExcludedModel(model) then return false end
local name = model.Name and model.Name:lower() or ""
for _, kw in ipairs(C.BOT_KEYWORDS) do
if name:find(kw) then return true end
end
if model:FindFirstChildOfClass("Humanoid") then return true end
return false
end
local function isNPC(c)
if not c then return false end
local cached = C._isNpc[c]
if cached ~= nil then return cached end
if playerOf(c) then C._isNpc[c] = false; return false end
if isExcludedModel(c) then C._isNpc[c] = false; return false end
if C._botSet[c] then C._isNpc[c] = true; return true end
local res = false
if C.NPC_ROOT and c:IsDescendantOf(C.NPC_ROOT) then
res = true
else
local name = c.Name:lower()
for _, k in ipairs(C.NPC_KEYS) do
if string.find(name, k, 1, true) then res = true; break end
end
if not res then res = humOf(c) ~= nil end
end
if not res then res = isBotModel(c) end
C._isNpc[c] = res
return res
end
local function alive(c)
if not c or not c.Parent then return false end
local h = humOf(c)
if not h or not h.Parent then return false end
if h.Health <= 0 then return false end
if c:IsA("Model") then
if not c:FindFirstChildOfClass("Humanoid") then return false end
if not c:FindFirstChild("HumanoidRootPart") and not c.PrimaryPart then return false end
end
return true
end
 C._teamAttackers = nil
local _teamDefenders
 C._teamsTried = false
local function ensureTeams()
if C._teamsTried then return end
C._teamsTried = true
if C.QuickCreate and type(C.QuickCreate.GetTeam) == "function" then
pcall(function()
C._teamAttackers = C.QuickCreate:GetTeam("Attackers")
_teamDefenders = C.QuickCreate:GetTeam("Defenders")
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
if C.PlayerUtility and type(C.PlayerUtility.IsPVERound) == "function" then
local ok, r = pcall(function() return C.PlayerUtility:IsPVERound() end)
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
if C._teamAttackers and myTeam == C._teamAttackers then return t ~= "Attackers" end
if _teamDefenders and myTeam == _teamDefenders then return t ~= "Defenders" end
return false
end
 C._enemyCache = setmetatable({}, { __mode = "k" })
local function isEnemyChar(c)
if not c then return false end
local v = C._enemyCache[c]
if v ~= nil then return v end
local res
local p = playerOf(c)
if p then
if C.PlayerUtility and type(C.PlayerUtility.AreEnemies) == "function" then
local ok, r = pcall(function() return C.PlayerUtility:AreEnemies(C.lp, p) end)
if ok and type(r) == "boolean" then res = r end
end
end
if res == nil then res = localAreEnemies(C.lp, c) end
C._enemyCache[c] = res
return res
end
local function invalidateTeamCache()
table.clear(C._enemyCache)
end
pcall(function()
workspace:GetAttributeChangedSignal("Round_Truce"):Connect(invalidateTeamCache)
workspace:GetAttributeChangedSignal("Round_FriendlyFire"):Connect(invalidateTeamCache)
C.lp:GetPropertyChangedSignal("Team"):Connect(invalidateTeamCache)
end)
local function canAttack(c)
if not c then return false end
if not alive(c) then return false end
if c:GetAttribute("Immortal") then return false end
if c:GetAttribute("epoch") then return false end
if C.TEAM_CHECK and not isEnemyChar(c) then return false end
local plr = playerOf(c)
if plr then return C.ATTACK_PLAYERS end
if isNPC(c) then return C.ATTACK_BOTS end
return false
end
local function hasMuzzle(tool)
if not tool then return false end
return tool:FindFirstChild("Muzzle", true) ~= nil
end
 C.LIMB_OK = {
Head = true, UpperTorso = true, Torso = true, LowerTorso = true,
HumanoidRootPart = true, LeftArm = true, RightArm = true,
LeftLeg = true, RightLeg = true, LeftUpperArm = true, RightUpperArm = true,
LeftLowerArm = true, RightLowerArm = true, LeftUpperLeg = true,
RightUpperLeg = true, LeftLowerLeg = true, RightLowerLeg = true,
LeftHand = true, RightHand = true, LeftFoot = true, RightFoot = true,
}
 C._lastStamp = 0
 C._seedIdx = math.random(0, 1000000)
local function nextStamp()
local s = (type(C.nowStamp) == "function") and C.nowStamp() or nil
if type(s) ~= "number" or s <= 0 then s = os.clock() end
if s <= C._lastStamp then s = C._lastStamp + 0.0015 end
C._lastStamp = s
return s
end
local function nextSeed()
C._seedIdx = (C._seedIdx + 1) % 2147483647
return C._seedIdx
end
 C._gunCache, _gunCacheAt = nil, 0
 C._gunMissReason = "未扫描"
local function getGun()
local now = os.clock()
if C._gunCache and C._gunCache.Parent and (now - _gunCacheAt) < 1 then
return C._gunCache
end
_gunCacheAt = now
local c = C.lp.Character
local found = nil
if c then
local equipped = c:FindFirstChildWhichIsA("Tool")
if equipped and hasMuzzle(equipped) then found = equipped end
end
if not found then
local backpack = C.lp:FindFirstChildOfClass("Backpack")
if backpack then
for _, tool in ipairs(backpack:GetChildren()) do
if tool:IsA("Tool") and hasMuzzle(tool) then found = tool; break end
end
end
end
if not found then
local cam = C.Workspace:FindFirstChild("Camera")
if cam then
for _, desc in ipairs(cam:GetDescendants()) do
if desc:IsA("Tool") and hasMuzzle(desc) then found = desc; break end
end
end
end
if not found then
local plrGui = C.lp:FindFirstChildOfClass("PlayerGui")
if plrGui then
for _, tool in ipairs(C.lp:GetDescendants()) do
if tool:IsA("Tool") and hasMuzzle(tool) then found = tool; break end
end
end
end
C._gunCache = found
C._gunMissReason = found and "" or "无Muzzle/AmmoLoaded的Tool"
return found
end
 C._aimPart = setmetatable({}, { __mode = "k" })
local function getAimPart(c)
if not c then return nil end
local p = C._aimPart[c]
if p and p.Parent then return p end
p = c:FindFirstChild("Head")
or c:FindFirstChild("UpperTorso")
or c:FindFirstChild("Torso")
or c:FindFirstChild("HumanoidRootPart")
or c:FindFirstChild("Head", true)
or c.PrimaryPart
or c:FindFirstChildWhichIsA("BasePart")
if p then C._aimPart[c] = p end
return p
end
 C.tracerFolder = Instance.new("Folder")
C.tracerFolder.Name = "AimTracers"
C.tracerFolder.Parent = C.Workspace
 C.TRACER_TEXTURE = "rbxassetid://6060542021"
 C._beamFade = {}
do
local steps = 8
for i = 0, steps do
local a = 1 - i / steps
C._beamFade[i + 1] = {
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
 C.TRACER_DURATION = C.TRACER_LIFETIME
 C.TRACER_HOLD = C.TRACER_LIFETIME * 0.6
 C.TRACER_FADE_STEP = (C.TRACER_LIFETIME - C.TRACER_HOLD) / 4
local function drawTracer(fromPos, toPos)
if not C.FX_ENABLED then return end
if (toPos - fromPos).Magnitude < 0.5 then return end
local a0 = Instance.new("Attachment")
a0.WorldCFrame = CFrame.new(fromPos)
a0.Parent = C.tracerFolder
local a1 = Instance.new("Attachment")
a1.WorldCFrame = CFrame.new(toPos)
a1.Parent = C.tracerFolder
local outerBeam = Instance.new("Beam")
outerBeam.Attachment0 = a0
outerBeam.Attachment1 = a1
outerBeam.Texture = C.TRACER_TEXTURE
outerBeam.TextureSpeed = 5
outerBeam.Width0 = 1.2
outerBeam.Width1 = 1.2
outerBeam.Transparency = C._beamFade[1].outer
outerBeam.Color = ColorSequence.new(Color3.fromRGB(85, 150, 255))
outerBeam.LightEmission = 1
outerBeam.LightInfluence = 0
outerBeam.FaceCamera = true
outerBeam.Parent = C.tracerFolder
local coreBeam = Instance.new("Beam")
coreBeam.Attachment0 = a0
coreBeam.Attachment1 = a1
coreBeam.Texture = C.TRACER_TEXTURE
coreBeam.TextureSpeed = 8
coreBeam.Width0 = 0.25
coreBeam.Width1 = 0.25
coreBeam.Transparency = C._beamFade[1].core
coreBeam.Color = ColorSequence.new(Color3.fromRGB(230, 240, 255))
coreBeam.LightEmission = 1.5
coreBeam.LightInfluence = 0
coreBeam.FaceCamera = true
coreBeam.Parent = C.tracerFolder
C.Debris:AddItem(outerBeam, C.TRACER_DURATION)
C.Debris:AddItem(coreBeam, C.TRACER_DURATION)
C.Debris:AddItem(a0, C.TRACER_DURATION)
C.Debris:AddItem(a1, C.TRACER_DURATION)
task.spawn(function()
task.wait(C.TRACER_HOLD)
for i = 2, 5 do
local f = C._beamFade[i]
if f then
pcall(function()
outerBeam.Transparency = f.outer
coreBeam.Transparency = f.core
end)
end
task.wait(C.TRACER_FADE_STEP)
end
end)
end
 C.lockFolder = Instance.new("Folder")
C.lockFolder.Name = "LockMarkers"
C.lockFolder.Parent = C.Workspace
 C.LOCK_APPEAR_TIME = 0.12
 C.LOCK_APPEAR_SCALE = 1.8
 C.LOCK_BURST_TIME = 0.35
 C.LOCK_BURST_SCALE = 2.2
C.startLockSpin = function(bg)
if not C.FX_ENABLED or C._lockTw[bg] then return end
local ring = bg:FindFirstChild("Ring")
local innerRing = bg:FindFirstChild("InnerRing")
if not ring or not innerRing then return end
local tw1 = C.TweenService:Create(ring,
TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
{ Rotation = 360 })
local tw2 = C.TweenService:Create(innerRing,
TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
{ Rotation = -360 })
tw1:Play()
tw2:Play()
C._lockTw[bg] = { tw1, tw2 }
end
stopLockSpin = function(bg)
local tws = C._lockTw[bg]
if not tws then return end
for _, tw in ipairs(tws) do pcall(tw.Cancel, tw) end
C._lockTw[bg] = nil
end
local function playAppearLockUI(ui)
if not ui or C.LOCK_APPEAR_TIME <= 0 or not C.FX_ENABLED then return end
pcall(function()
local px = ui.Size.X.Offset
if px <= 0 then return end
ui.Size = UDim2.new(0, px * C.LOCK_APPEAR_SCALE, 0, px * C.LOCK_APPEAR_SCALE)
C.TweenService:Create(ui,
TweenInfo.new(C.LOCK_APPEAR_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
{ Size = UDim2.new(0, px, 0, px) }):Play()
end)
end
local function burstLockUI(ui)
if not ui then return end
stopLockSpin(ui)
pcall(function()
local px = ui.Size.X.Offset
if px <= 0 then px = C.LOCK_UI_SIZE end
local info = TweenInfo.new(C.LOCK_BURST_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
C.TweenService:Create(ui, info, {
Size = UDim2.new(0, px * C.LOCK_BURST_SCALE, 0, px * C.LOCK_BURST_SCALE)
}):Play()
for _, d in ipairs(ui:GetDescendants()) do
if d:IsA("UIStroke") then
C.TweenService:Create(d, info, { Transparency = 1 }):Play()
elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
C.TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
elseif d:IsA("TextLabel") then
C.TweenService:Create(d, info, { TextTransparency = 1 }):Play()
end
end
end)
task.delay(C.LOCK_BURST_TIME + 0.08, function()
pcall(ui.Destroy, ui)
end)
end
local function makeLockUI(part, offsetY)
local bg = Instance.new("BillboardGui")
bg.Name = "LockUI"
bg.Adornee = part
bg.Size = UDim2.new(0, C.LOCK_UI_SIZE, 0, C.LOCK_UI_SIZE)
bg.StudsOffset = Vector3.new(0, offsetY or 0, 0)
bg.AlwaysOnTop = true
bg.MaxDistance = C.MAX_DIST + 100
bg.LightInfluence = 0
bg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
bg.Enabled = true
bg.Parent = part.Parent or C.Workspace
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
C.startLockSpin(bg)
return bg
end
updateLockUIMaxDistance = function()
for _, ui in pairs(C.lockUI) do
pcall(function() ui.MaxDistance = C.MAX_DIST + 100 end)
end
end
updateLockUISize = function()
local myChar = C.lp.Character
local mh = myChar and getAimPart(myChar)
if not mh then return end
local myPos = mh.Position
for t, ui in pairs(C.lockUI) do
local ap = getAimPart(t)
if ap then
local px = C.LOCK_UI_SIZE * (30 / math.max((ap.Position - myPos).Magnitude, 8))
if px < C.LOCK_UI_MIN then px = C.LOCK_UI_MIN end
if px > C.LOCK_UI_MAX then px = C.LOCK_UI_MAX end
pcall(function() ui.Size = UDim2.new(0, px, 0, px) end)
end
end
end
showLockUI = function(t)
if C.lockUI[t] then return end
local aimPart = getAimPart(t)
if not aimPart then return end
local root = t:FindFirstChild("HumanoidRootPart")
if root then
C.lockUI[t] = makeLockUI(root, 2.2)
else
C.lockUI[t] = makeLockUI(aimPart, 0)
end
updateLockUISize()
playAppearLockUI(C.lockUI[t])
local hum = humOf(t)
if hum and not C._deathConn[t] then
C._deathConn[t] = hum.Died:Connect(function()
if C.target == t then
C.target = nil
C._targetReady = false
C._lockStart = 0
C._scanValid = false
C._scanRefreshAt = 0
end
hideLockUI(t)
end)
end
end
hideLockUI = function(t, burst)
local conn = C._deathConn[t]
if conn then
pcall(conn.Disconnect, conn)
C._deathConn[t] = nil
end
local ui = C.lockUI[t]
if ui then
C.lockUI[t] = nil
C.lockReady[t] = nil
if burst and C.FX_ENABLED then
burstLockUI(ui)
else
stopLockSpin(ui)
pcall(ui.Destroy, ui)
end
end
C._losCache[t] = nil
end
C.clearAllLockUI = function()
for t, _ in pairs(C.lockUI) do hideLockUI(t) end
table.clear(C._losCache)
end
C.setLockState = function(t, ready)
if C.lockReady[t] == ready then return end
C.lockReady[t] = ready
local ui = C.lockUI[t]
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
 C._filterCache = nil
 C._filterDirty = true
local function invalidateFilterCache()
C._filterDirty = true
C._filterCache = nil
end
C.Players.PlayerAdded:Connect(function()
invalidateFilterCache()
end)
C.Players.PlayerRemoving:Connect(function()
invalidateFilterCache()
end)
 C.MAX_FILTER_ITEMS = 200
 C.USE_ZONE_CACHE_IN_FILTER = false
 C.OBSTRUCTION_BLACKLIST = {}
local function getObstructionBlacklist()
if #C.OBSTRUCTION_BLACKLIST > 0 then return C.OBSTRUCTION_BLACKLIST end
if C.SharedModuleFunctions
and type(C.SharedModuleFunctions._GunshotObstructionBlacklist) == "function" then
local ok2, r = pcall(function()
return C.SharedModuleFunctions._GunshotObstructionBlacklist()
end)
if ok2 and type(r) == "table" then
for _, v in ipairs(r) do
if v then C.OBSTRUCTION_BLACKLIST[#C.OBSTRUCTION_BLACKLIST + 1] = v end
end
end
end
if #C.OBSTRUCTION_BLACKLIST == 0 then
pcall(function()
local mc = C.Workspace:FindFirstChild("MapContainer")
if not mc then return end
for _, name in ipairs({ "Barriers", "Zones", "Spawn" }) do
local c = mc:FindFirstChild(name)
if c then C.OBSTRUCTION_BLACKLIST[#C.OBSTRUCTION_BLACKLIST + 1] = c end
end
end)
end
return C.OBSTRUCTION_BLACKLIST
end
local function buildFilterList()
if not C._filterDirty and C._filterCache then
return C._filterCache
end
C._filterDirty = false
local friendly, cursorFiltered = {}, {}
if C.PlayerUtility and type(C.PlayerUtility.GetFriendlyCharactersOfPlayer) == "function" then
local ok2, r = pcall(function() return C.PlayerUtility:GetFriendlyCharactersOfPlayer(C.lp, true) end)
if ok2 and type(r) == "table" then friendly = r end
end
if C.PlayerUtility and type(C.PlayerUtility.GetFriendlyPlayersOfPlayer) == "function" then
local ok2, r = pcall(function() return C.PlayerUtility:GetFriendlyPlayersOfPlayer(C.lp, true) end)
if ok2 and type(r) == "table" then
for _, p in ipairs(r) do
if p and p.Character then friendly[#friendly + 1] = p.Character end
end
end
end
if C.ClientCursor and type(C.ClientCursor.GetCursorRayFilteredDescendants) == "function" then
local ok2, r = pcall(function() return C.ClientCursor.GetCursorRayFilteredDescendants() end)
if ok2 and type(r) == "table" then cursorFiltered = r end
end
local combined
if C.QuickCreate and type(C.QuickCreate.CombineArrays) == "function" then
local ok2, r = pcall(function() return C.QuickCreate:CombineArrays(friendly, cursorFiltered) end)
if ok2 and type(r) == "table" then combined = r end
end
if not combined then
combined = {}
for _, v in ipairs(friendly) do combined[#combined + 1] = v end
for _, v in ipairs(cursorFiltered) do combined[#combined + 1] = v end
end
local list = {}
local n = 0
if C.lp.Character then n = n + 1; list[n] = C.lp.Character end
local bp = C.lp:FindFirstChildOfClass("Backpack")
if bp then n = n + 1; list[n] = bp end
for _, v in ipairs(getObstructionBlacklist()) do
n = n + 1; list[n] = v
end
local cosmetic = C.Workspace:FindFirstChild("CosmeticContainer")
if cosmetic then n = n + 1; list[n] = cosmetic end
if C.USE_ZONE_CACHE_IN_FILTER then
local zoneCache = nil
if C.ClientUtilities and type(C.ClientUtilities.GetZoneCache) == "function" then
local ok2, r = pcall(function() return C.ClientUtilities:GetZoneCache() end)
if ok2 and type(r) == "table" then zoneCache = r end
end
if zoneCache then
for _, v in ipairs(zoneCache) do
if n >= C.MAX_FILTER_ITEMS then break end
n = n + 1; list[n] = v
end
end
end
for _, v in ipairs(combined) do
if n >= C.MAX_FILTER_ITEMS then break end
n = n + 1; list[n] = v
end
if #combined == 0 and C.TEAM_CHECK then
for _, p in ipairs(C.Players:GetPlayers()) do
local c = p.Character
if n >= C.MAX_FILTER_ITEMS then break end
if c and c ~= C.lp.Character then n = n + 1; list[n] = c end
end
end
C._filterCache = list
return list
end
 C._rayParams = nil
 C._rayParamsAt = 0
local function getRaycastParams()
local now = os.clock()
if C._rayParams and not C._filterDirty and (now - C._rayParamsAt) < C._RAYPARAMS_REBUILD then
return C._rayParams
end
C._rayParamsAt = now
local list = buildFilterList()
if not C._rayParams then
local ok2, p = pcall(function()
if C.QuickCreate and type(C.QuickCreate.FastRaycastParams) == "function" then
return C.QuickCreate:FastRaycastParams(list, Enum.RaycastFilterType.Exclude, false, nil, false, false)
end
end)
if ok2 and typeof(p) == "RaycastParams" then
C._rayParams = p
else
C._rayParams = RaycastParams.new()
end
end
pcall(function()
C._rayParams.FilterType = Enum.RaycastFilterType.Exclude
C._rayParams.FilterDescendantsInstances = list
C._rayParams.IgnoreWater = false
C._rayParams.RespectCanCollide = false
end)
return C._rayParams
end
 C._LOS_CACHE_TTL_BLOCKED = 0.06
 C._LOS_CACHE_THRESH = 2
 C._losSource = "-"
 C._rayCount = 0
local function ballisticPos(origin, v0, accel, t)
return origin + v0 * t + Vector3.new(accel.X * t * t / 2, accel.Y * t * t / 2, accel.Z * t * t / 2)
end
 C._gravityVal = nil
local function getGravity()
if C.BALLISTIC_GRAVITY ~= 0 then return C.BALLISTIC_GRAVITY end
if not C._gravityVal then
local okG, g = pcall(function() return C.Workspace.Gravity end)
C._gravityVal = (okG and type(g) == "number") and g or 196.2
end
return C._gravityVal
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
C._rayCount = C._rayCount + 1
local hit = C.Workspace:Raycast(origin, delta, params)
if not C.PIERCE_ENABLED or not hit then return hit end
local from, rest = origin, delta
for _ = 1, C.PIERCE_MAX do
if not canBulletPierce(hit) then return hit end
rest = rest - (hit.Position - from)
local len = rest.Magnitude
if len <= C.PIERCE_STEP then return nil end
local unit = rest / len
from = hit.Position + unit * C.PIERCE_STEP
rest = rest - unit * C.PIERCE_STEP
C._rayCount = C._rayCount + 1
hit = C.Workspace:Raycast(from, rest, params)
if not hit then return nil end
end
return hit
end
local function ballisticRay(fromPos, toPos, params)
local delta = toPos - fromPos
local dist = delta.Magnitude
if dist < 0.01 then return nil end
local speed = C.BULLET_VELOCITY
if not speed or speed <= 0 then speed = C.BULLET_SPEED end
if not speed or speed <= 0 then speed = 1600 end
if C.RAY_ACCURACY <= 0 then
return raySegment(fromPos, delta, params)
end
local g = getGravity()
if g <= 0 then
return raySegment(fromPos, delta, params)
end
local tTotal = dist / speed
local drop = 0.5 * g * tTotal * tTotal
if drop <= C.DROP_SKIP_EPS then
return raySegment(fromPos, delta, params)
end
local segs = math.ceil(drop / C.SEG_DROP_STEP)
if segs < 2 then segs = 2 end
if segs > C.BALLISTIC_MAX_SEGMENTS then segs = C.BALLISTIC_MAX_SEGMENTS end
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
if not C.ClientPlayerWrapper then return nil end
local ok2, ci = pcall(function() return C.ClientPlayerWrapper.CharacterInfo end)
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
local c = C.lp.Character
if not c then return nil end
local tool = c:FindFirstChildWhichIsA("Tool")
if tool and hasMuzzle(tool) then return tool end
return nil
end
 C._muzzleCache, _muzzleCacheAt, _muzzleCached = nil, 0, false
local function invalidateMuzzle()
C._muzzleCache = nil
_muzzleCached = false
end
local function getMuzzlePart()
local now = os.clock()
if _muzzleCached and (now - _muzzleCacheAt) < 0.5 then
return C._muzzleCache
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
C._muzzleCache = m
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
hookMuzzleEvents(C.lp.Character)
 C._lastVerifyTime = 0
local function onMyRespawn(c)
invalidateFilterCache()
invalidateMuzzle()
C._rayParams = nil
C._rayParamsAt = 0
if C._aimPart then table.clear(C._aimPart) end
table.clear(C._losCache)
table.clear(C._aimPick)
if C.target then hideLockUI(C.target) end
C.target = nil
C._targetReady = false
C._lockStart = 0
C._losLostAt = 0
C._lastLosTime = 0
C._lastVerifyTime = 0
C._scanValid = false
C._scanRefreshAt = 0
end
C.lp.CharacterAdded:Connect(function(c)
onMyRespawn(c)
hookMuzzleEvents(c)
end)
local function getShootOrigin(myChar)
local ok1, gp = pcall(getGameBodyHead)
if ok1 and typeof(gp) == "Vector3" then return gp, "HEAD" end
local h = myChar and getAimPart(myChar)
if h then return h.Position, "HEAD" end
return nil, "-"
end
local function aimPartPos(model, name)
local p = model:FindFirstChild(name)
if p and p:IsA("BasePart") then return p end
local alt = C.PART_ALIAS[name]
if alt then
p = model:FindFirstChild(alt)
if p and p:IsA("BasePart") then return p end
end
return nil
end
local function aimOrder(model)
local first = C.AIM_PART_MAIN
if not C.AIM_PART_FALLBACK then
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
if not C.AIM_PART_FALLBACK then
return first, false
end
if C.EARLY_OUT_HEAD_BLOCK and i == 1 then
return first, false
end
end
end
return first, false
end
local function clearShotShooterStyle(myChar, targetModel, force)
if not myChar or not targetModel then return false end
if not C.RAY_ENABLED then
local ap = getAimPart(targetModel)
if ap then C._aimPick[targetModel] = ap end
C._losSource = "OFF"
return ap ~= nil
end
local origin, originTag = getShootOrigin(myChar)
if not origin then return false end
local tgAim = getAimPart(targetModel)
if not tgAim then return false end
local rough = tgAim.Position - origin
if rough.Magnitude > C.MAX_DIST then return false end
if rough.Magnitude < 0.5 then
C._aimPick[targetModel] = tgAim
return true
end
local params = getRaycastParams()
local now = os.clock()
if not force then
local cache = C._losCache[targetModel]
if cache then
local ttl = C.LOS_CACHE_TTL
if not cache.ready then ttl = C.LOS_CACHE_TTL * 1.2 end
if (now - cache.time) < ttl
and (cache.pos - tgAim.Position).Magnitude < C._LOS_CACHE_THRESH
and (cache.my - origin).Magnitude < C._LOS_CACHE_THRESH then
C._losSource = "CACHE"
if cache.ready and cache.part then C._aimPick[targetModel] = cache.part end
return cache.ready
end
end
end
C._losSource = originTag
local part, ready = findVisiblePart(origin, targetModel, params)
if ready then
C._aimPick[targetModel] = part
end
C._losCache[targetModel] = {
ready = ready, part = part, pos = tgAim.Position, my = origin, time = now
}
return ready
end
local function getTargetHitPart(t)
local p = C._aimPick[t]
if p and p.Parent then return p end
return getAimPart(t)
end
 C._playerChars, _playerSet = {}, {}
 C._npcChars, _npcSet = {}, {}
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
 C._reviveConn = setmetatable({}, { __mode = "k" })
local function onNewCandidate()
if C.requestScan then C.requestScan() end
end
local function hookEnemyRespawn(c)
if not c or C._reviveConn[c] then return end
local hum = humOf(c)
if not hum then return end
C._reviveConn[c] = hum.Died:Connect(function()
C._reviveConn[c] = nil
C._losCache[c] = nil
C._aimPick[c] = nil
C._aimPart[c] = nil
if C.target == c then
hideLockUI(c)
C.target = nil
C._targetReady = false
C._lockStart = 0
C._losLostAt = 0
C._scanValid = false
C._scanRefreshAt = 0
end
task.defer(function()
if not c.Parent then return end
local nh = humOf(c)
if nh and nh.Health > 0 then
C._losCache[c] = nil
C._aimPick[c] = nil
hookEnemyRespawn(c)
onNewCandidate()
end
end)
end)
end
local function hookPlayer(p)
if p.Character then poolAdd(C._playerChars, _playerSet, p.Character) end
p.CharacterAdded:Connect(function(c)
poolAdd(C._playerChars, _playerSet, c)
invalidateFilterCache()
C._losCache[c] = nil
C._aimPick[c] = nil
hookEnemyRespawn(c)
onNewCandidate()
end)
p.CharacterRemoving:Connect(function(c)
poolRemove(C._playerChars, _playerSet, c)
C._losCache[c] = nil
C._aimPick[c] = nil
end)
end
for _, p in ipairs(C.Players:GetPlayers()) do hookPlayer(p) end
C.Players.PlayerAdded:Connect(function(p)
hookPlayer(p)
invalidateFilterCache()
onNewCandidate()
end)
C.Players.PlayerRemoving:Connect(function(p)
if p.Character then poolRemove(C._playerChars, _playerSet, p.Character) end
invalidateFilterCache()
end)
local function addNpcModel(m)
if not m or not m:IsA("Model") then return false end
if playerOf(m) then return false end
if m == C.lp.Character then return false end
if isExcludedModel(m) then return false end
if poolAdd(C._npcChars, _npcSet, m) then onNewCandidate(); return true end
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
C._botSet[m] = true
addNpcModel(m)
end
end
if C.BOT_FOLDER then
for _, ov in ipairs(C.BOT_FOLDER:GetChildren()) do addBotFromValue(ov) end
C.BOT_FOLDER.ChildAdded:Connect(function(ov)
addBotFromValue(ov)
invalidateTeamCache()
onNewCandidate()
end)
C.BOT_FOLDER.ChildRemoved:Connect(function(ov)
if ov:IsA("ObjectValue") and ov.Value then
poolRemove(C._npcChars, _npcSet, ov.Value)
end
end)
for _, ov in ipairs(C.BOT_FOLDER:GetChildren()) do
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
for _, h in ipairs(C.CollectionService:GetTagged(C.TAG_DYN)) do
addTagHumanoid(h)
end
C.CollectionService:GetInstanceAddedSignal(C.TAG_DYN):Connect(function(h)
addTagHumanoid(h)
invalidateTeamCache()
onNewCandidate()
end)
C.CollectionService:GetInstanceRemovedSignal(C.TAG_DYN):Connect(function(h)
local m = h.Parent
if not m or not m:IsA("Model") then return end
poolRemove(C._npcChars, _npcSet, m)
C._losCache[m] = nil
C._aimPick[m] = nil
C._aimPart[m] = nil
if C.target == m then
hideLockUI(m)
C.target = nil
C._targetReady = false
C._lockStart = 0
C._losLostAt = 0
C._scanValid = false
C._scanRefreshAt = 0
end
end)
end)
if C.NPC_ROOT then
scanNpcTree(C.NPC_ROOT, 0)
C.NPC_ROOT.DescendantAdded:Connect(function(d)
if d:IsA("Model") then addNpcModel(d) end
end)
C.NPC_ROOT.DescendantRemoving:Connect(function(d)
if d:IsA("Model") then poolRemove(C._npcChars, _npcSet, d) end
end)
end
C.Workspace.DescendantAdded:Connect(function(d)
if d:IsA("Model") and isBotModel(d) then addNpcModel(d) end
end)
C.Workspace.DescendantRemoving:Connect(function(d)
if d:IsA("Model") then poolRemove(C._npcChars, _npcSet, d) end
end)
local function ensureEnemyHooked(c)
if not C._reviveConn[c] then hookEnemyRespawn(c) end
end
 C._candBuf = {}
local function collectCandidates()
table.clear(C._candBuf)
local myChar = C.lp.Character
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
if d > C.MAX_DIST then return end
n = n + 1
C._candBuf[n] = {
c = c,
d = d,
dot = aimPart.Position - fromPos,
}
end
for _, c in ipairs(C._playerChars) do collect(c) end
for _, c in ipairs(C._npcChars) do collect(c) end
if n > 1 then
table.sort(C._candBuf, function(a, b) return a.d < b.d end)
end
return n
end
 C._scanQueue = {}
 C._scanIdx = 1
 C._lastFullScan = 0
local function refreshNpcPool()
resolveRoots()
for i = #C._npcChars, 1, -1 do
local m = C._npcChars[i]
if isExcludedModel(m) then
poolRemove(C._npcChars, _npcSet, m)
end
end
if C.BOT_FOLDER then
pcall(function()
for _, ov in ipairs(C.BOT_FOLDER:GetChildren()) do
if ov:IsA("ObjectValue") and ov.Value and ov.Value:IsA("Model") and not isExcludedModel(ov.Value) then
C._botSet[ov.Value] = true
poolAdd(C._npcChars, _npcSet, ov.Value)
end
end
end)
end
pcall(function()
for _, h in ipairs(C.CollectionService:GetTagged(C.TAG_DYN)) do
if h.Health > 0 then
local m = h.Parent
if m and m:IsA("Model") and not playerOf(m) and not isExcludedModel(m) then
poolAdd(C._npcChars, _npcSet, m)
end
end
end
end)
local now = os.clock()
if now - C._lastFullScan >= 1 then
C._lastFullScan = now
pcall(function()
for _, desc in ipairs(C.Workspace:GetDescendants()) do
if desc:IsA("Humanoid") then
local m = desc.Parent
if m and m:IsA("Model") and isBotModel(m) then
poolAdd(C._npcChars, _npcSet, m)
end
end
end
end)
end
end
local function rebuildScanQueue()
refreshNpcPool()
local n = collectCandidates()
table.clear(C._scanQueue)
for i = 1, n do C._scanQueue[i] = C._candBuf[i] end
C._scanIdx = 1
C._scanValid = (n > 0)
C._scanRefreshAt = os.clock()
end
local function stepScan(myChar)
if not C._scanValid then
if SCAN_REFRESH > 0 and (os.clock() - C._scanRefreshAt) < SCAN_REFRESH then
return nil
end
rebuildScanQueue()
if not C._scanValid then return nil end
end
local deadline = os.clock() + C.SCAN_BUDGET
local q = C._scanQueue
local n = #q
while C._scanIdx <= n do
local e = q[C._scanIdx]
C._scanIdx = C._scanIdx + 1
if e and e.c and e.c.Parent and alive(e.c) then
if clearShotShooterStyle(myChar, e.c) then
return e.c
end
end
if os.clock() >= deadline then break end
end
if C._scanIdx > n then
C._scanValid = false
end
return nil
end
 C.PR, PR_OK = nil, false
pcall(function()
local refs = C.Replicated:FindFirstChild("REFERENCES")
if refs then
C.PR = require(refs:FindFirstChild("PacketReference"))
PR_OK = C.PR ~= nil
end
end)
C.nowStamp = function()
local ok, t = pcall(function() return C.Workspace:GetServerTimeNow() end)
if ok and type(t) == "number" and t > 0 then return t end
return tick()
end
 C._fireCalls = 0
 C._packetsSent = 0
 C._packetsFail = 0
 C._lastSendErr = ""
 C._lastFail = "未开火"
 C._lastGun = "无"
local function fire(t)
C._fireCalls = C._fireCalls + 1
if not alive(t) then C._lastFail = "F1目标非存活"; return false end
if isExcludedModel(t) then C._lastFail = "F2目标被过滤"; return false end
if not canAttack(t) then C._lastFail = "F3目标不可攻击"; return false end
local gun = getEquippedGun() or getGun()
if not gun then
C._lastFail = "F4无枪械(" .. tostring(C._gunMissReason) .. ")"
return false
end
local mH = C.lp.Character and getAimPart(C.lp.Character)
local tH = getTargetHitPart(t) or getAimPart(t)
if not mH or not tH then C._lastFail = "F5无瞄准部件"; return false end
local origin = getShootOrigin(C.lp.Character)
if not origin then origin = mH.Position end
local shootDir = tH.Position - origin
if shootDir.Magnitude < 0.001 then C._lastFail = "F6方向无效"; return false end
shootDir = shootDir.Unit
local realDir = shootDir
local stamp = nextStamp()
C._lastGun = gun.Name
pcall(function()
local shootSound = Instance.new("Sound")
shootSound.SoundId = "rbxassetid://8679627751"
shootSound.Volume = 1
shootSound.PlayOnRemove = false
shootSound.Parent = C.Workspace
shootSound:Play()
task.delay(3, function()
pcall(shootSound.Destroy, shootSound)
end)
end)
if C.FX_ENABLED then
local tracerStart
local hrp = C.lp.Character and C.lp.Character:FindFirstChild("HumanoidRootPart")
if hrp then
local randomDir = Vector3.new(
math.random(-100, 100) / 100,
math.random(-30, 30) / 100,
math.random(-100, 100) / 100
).Unit
local randomDist = math.random(1, 10)
tracerStart = hrp.Position + (randomDir * randomDist)
else
tracerStart = origin + (shootDir * math.min(C.TRACER_LENGTH, 10))
end
drawTracer(tracerStart, tH.Position)
end
local limbName = tH.Name
if not C.LIMB_OK[limbName] then
if t:FindFirstChild("UpperTorso") then
limbName = "UpperTorso"
elseif t:FindFirstChild("Torso") then
limbName = "Torso"
elseif t:FindFirstChild("Head") then
limbName = "Head"
end
end
local victimPos = (t.PrimaryPart and t.PrimaryPart.Position) or tH.Position
local data = {
Gun = gun,
Vector = realDir,
epoch = stamp,
bulletOrigin = origin,
bulletEnd = tH.Position,
rngSeed = nextSeed(),
otherCharacter = t,
hitLimb = limbName,
hitTimestamp = stamp,
clientHitPosition = tH.Position,
clientVictimPosition = victimPos
}
C.sent = C.sent + 1
if PR_OK then
C._lastFail = "OK"
task.spawn(function()
local names = { "ShootRegistration", "ReplicateGunShot", "gunshotCharacterHit" }
for _, n in ipairs(names) do
local ok, err = pcall(function()
local r = C.PR[n]
if r and r.send then r.send(data) end
end)
if ok then
C._packetsSent = C._packetsSent + 1
else
C._packetsFail = C._packetsFail + 1
C._lastSendErr = tostring(err)
end
task.wait(C.PACKET_DELAY)
end
end)
else
C._lastFail = "PR缺失(仅本地伤害)"
pcall(function()
local h = t:FindFirstChildWhichIsA("Humanoid")
if h then h:TakeDamage(10) end
end)
end
return true
end
local function releaseTarget()
if C.target then hideLockUI(C.target) end
C.target = nil
C._targetReady = false
C._lockStart = 0
C._losLostAt = 0
C._lastLosTime = 0
C._lastVerifyTime = 0
end
local function startReload()
C.state = "RELOAD"
C.reloadUntil = os.clock() + C.RELOAD_TIME
end
C.requestScan = function()
C._scanValid = false
C._scanRefreshAt = 0
end
 C.isDead = false
local function resetOnDeath()
C.isDead = true
C.reloadUntil = 0
C.state = "IDLE"
C.clearAllLockUI()
C.target = nil
C._targetReady = false
C._lockStart = 0
C._losLostAt = 0
C._lastLosTime = 0
C._lastVerifyTime = 0
C._scanValid = false
C._scanRefreshAt = 0
end
local function hookMyDeath(c)
if not c then return end
local hum = c:FindFirstChildOfClass("Humanoid")
if not hum then
task.delay(0.5, function()
if c and c.Parent then
local h2 = c:FindFirstChildOfClass("Humanoid")
if h2 then hookMyDeath(c) end
end
end)
return
end
hum.Died:Connect(function()
resetOnDeath()
end)
hum.HealthChanged:Connect(function(h)
if h <= 0 then
resetOnDeath()
end
end)
end
if C.lp.Character then
C.isDead = false
hookMyDeath(C.lp.Character)
end
C.lp.CharacterAdded:Connect(function(c)
task.wait(0.3)
C.isDead = false
C.reloadUntil = 0
C.state = "IDLE"
C.clearAllLockUI()
C.target = nil
C._targetReady = false
C._lockStart = 0
C._losLostAt = 0
C._lastLosTime = 0
C._lastVerifyTime = 0
C._scanValid = false
C._scanRefreshAt = 0
hookMyDeath(c)
if C.requestScan then C.requestScan() end
end)
C.lp.CharacterRemoving:Connect(function()
resetOnDeath()
end)
C.RunService.Heartbeat:Connect(function(dt)
updateCooldownBar()
local rt = os.clock()
if rt - C._rootsTick >= 2 then
C._rootsTick = rt
if resolveRoots() then C.requestScan() end
end
if not C.running then return end
local myChar = C.lp.Character
local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
if C.isDead or not myChar or not myHum or myHum.Health <= 0 then
resetOnDeath()
return
end
local now = os.clock()
if C.state == "RELOAD" then
if now < C.reloadUntil then
if C.target then releaseTarget() end
return
end
C.state = "IDLE"
C.target = nil
C._targetReady = false
C._lockStart = 0
C._losLostAt = 0
C._lastLosTime = now
C._lastVerifyTime = now
if C.requestScan then C.requestScan() end
end
if C.target and (now - C._lastVerifyTime) >= 0.2 then
C._lastVerifyTime = now
local tH = getAimPart(C.target)
local myHeadPart = myChar:FindFirstChild("Head")
if not alive(C.target) or isTeam(C.target) or not canAttack(C.target) then
releaseTarget()
elseif not tH or (myHeadPart and (myHeadPart.Position - tH.Position).Magnitude > C.MAX_DIST) then
releaseTarget()
end
end
if not C.target then
local t = stepScan(myChar)
if t then
C.target = t
C._targetReady = true
C._lockStart = now
C._losLostAt = 0
C._lastLosTime = now
showLockUI(t)
end
end
if C.target then
if (now - C._lastLosTime) >= C._LOS_INTERVAL then
C._lastLosTime = now
C._targetReady = clearShotShooterStyle(myChar, C.target)
C.setLockState(C.target, C._targetReady)
end
if not C._targetReady then
if C._losLostAt == 0 then
C._losLostAt = now
elseif C.LOS_RELEASE_GRACE <= 0 or (now - C._losLostAt) >= C.LOS_RELEASE_GRACE then
releaseTarget()
end
else
C._losLostAt = 0
end
end
if C.state == "IDLE" and C.target then
if not C._targetReady then
C._lockStart = 0
elseif C._lockStart == 0 then
C._lockStart = now
end
local confirmed = C._targetReady and (C.LOCK_CONFIRM_TIME <= 0 or (now - C._lockStart) >= C.LOCK_CONFIRM_TIME)
if confirmed and clearShotShooterStyle(myChar, C.target, true) then
if fire(C.target) then
startReload()
end
end
end
end)
C.UserInput.InputBegan:Connect(function(i, g)
if g then return end
if i.KeyCode == Enum.KeyCode.P then
C.running = not C.running
if not C.running then
C.clearAllLockUI()
C.target = nil
C._targetReady = false
C.state = "IDLE"
end
end
end)
task.spawn(function()
while true do
task.wait(0.5)
pcall(function()
if not C.diagLabel then return end
local g = getEquippedGun() or getGun()
local ammoStr, fireStr = "-", "-"
if g then
local al = g:FindFirstChild("AmmoLoaded")
if al and (al:IsA("IntValue") or al:IsA("NumberValue")) then
ammoStr = tostring(al.Value)
end
local cf = g:GetAttribute("CanFire")
if type(cf) == "boolean" then fireStr = tostring(cf) end
end
local tg = C.target and (C.target.Name or "?") or "无"
C.diagLabel:SetText(string.format(
"状态:%s | 启动:%s | 死亡:%s\n目标:%s | 视线:%s\n枪:%s | 弹:%s | 可开火:%s\nPR:%s | 开火:%d | 包成:%d 败:%d\n最后:%s",
tostring(C.state),
C.running and "开" or "关",
C.isDead and "是" or "否",
tg,
C._targetReady and "通" or "断",
C._lastGun, ammoStr, fireStr,
PR_OK and "已连接" or "缺失",
C._fireCalls, C._packetsSent, C._packetsFail,
C._lastFail))
end)
end
end)
Library:Notify("GR 功能已加载", 3)
if GHub and GHub.RegisterModule then
GHub.RegisterModule("莱克星顿与康科德", { Name = "莱克星顿与康科德", AimTab = AimTab, MiscTab = MiscTab, Options = Library.Options, Unload = function() C.running = false; C.state = "IDLE"; C.target = nil; C._targetReady = false; pcall(C.clearAllLockUI) end })
end
if GHub and GHub.RegisterTab then
GHub.RegisterTab("枪械", AimTab)
GHub.RegisterTab("杂项", MiscTab)
end
return { Name = "莱克星顿与康科德", AimTab = AimTab, MiscTab = MiscTab, Options = Library.Options, Unload = function() C.running = false; C.state = "IDLE"; C.target = nil; C._targetReady = false; pcall(C.clearAllLockUI) end }
end
