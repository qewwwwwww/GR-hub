return function(Library, Window, GHub)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")

local C = {}
C.genv = (type(getgenv) == "function") and getgenv() or _G
GHub = GHub or C.genv.GRHub
C.lp = Players.LocalPlayer
C.cam = Workspace.CurrentCamera
C.Events = ReplicatedStorage:WaitForChild("Events")
C.Weapons = ReplicatedStorage:WaitForChild("Weapons")

C.CFG = {
    Enabled = false,
    RayCheck = false,
    ThirdPerson = false,
    TeamCheck = false,
    ESP = false,
    BackTurn = false,
    MaxSpeed = false,
    Tracer = false,
    MineESP = false,
    AntiDrone = false,
    SmokeBlock = false,
    HeadCtrl = false,
    Spin = false,
    Stealth = false,
}
C.SPD = { WalkSpeed = 32, Accl = 2 }
C.SPIN = { Dir = "顺时针", Speed = 180 }
C.HEAD = { Mode = "低头" }
C._spinAngle = 0
C._hip = nil
C._lastFire = 0
C._espT = 0
C._optT = 0
C._espCache = {}
C._reg = {}
C._smoke = {}
C._rt = 0
C._st2 = 0
C._dLast = 0
C._air = 0
C._lookRemote = nil
C._intRunning = false
C._cr = nil
C._tracerFolder = nil
C._sl = nil
C._slGui = nil
C._sound = nil
C._targetSel = nil
C._blockedTargets = {}
C._targetFilter = false

C._hlVis = (function()
    local ok = pcall(function()
        local t = Instance.new("Highlight")
        local _ = t.Visible
        t:Destroy()
    end)
    if ok then return "Visible" end
    return "Enabled"
end)()

local FIRE_SOUND_ID = "rbxassetid://8679627751"
local LOOK_REMOTE = "RE_0R5lsPxqfSH3"
local HEAD_UP = 1
local HEAD_DOWN = -1
local LOOK_ARG2 = 0
local LOOK_GAP = 0.1
local function headPitch()
    return (C.HEAD.Mode == "抬头") and HEAD_UP or HEAD_DOWN
end

local function ss(i, p, v)
    if i then pcall(function() i[p] = v end) end
end
local function si(i, p, c)
    if i then pcall(function() i:GetPropertyChangedSignal(p):Connect(c) end) end
end
local function rn(n) return math.round(n * 1000) / 1000 end
local function o3(v) return Vector3.new(rn(v.X), rn(v.Y), rn(v.Z)) end
local function setSl(s)
    local lb = C._sl
    if not lb or not lb.Parent then return end
    pcall(function() lb.Text = s end)
end
local function setHlVisible(h, v)
    if not h then return end
    pcall(function() h[C._hlVis] = v end)
end

local function ensureSound()
    if C._sound and C._sound.Parent then return C._sound end
    local s = Instance.new("Sound")
    s.Name = "def_fire"
    s.SoundId = FIRE_SOUND_ID
    s.Volume = 0.6
    s.RollOffMode = Enum.RollOffMode.Inverse
    s.Parent = SoundService
    C._sound = s
    return s
end
local function playFireSound()
    local s = ensureSound()
    if not s then return end
    pcall(function()
        s.TimePosition = 0
        s:Play()
    end)
end

local function lookRemote()
    if C._lookRemote and C._lookRemote.Parent then return C._lookRemote end
    local r = ReplicatedStorage:FindFirstChild(LOOK_REMOTE)
    if r then C._lookRemote = r end
    return r
end
local function startHeadCtrl()
    if C._intRunning then return end
    C._intRunning = true
    task.spawn(function()
        while C.CFG.HeadCtrl do
            local r = lookRemote()
            if r then
                pcall(function() r:FireServer(headPitch(), LOOK_ARG2) end)
            end
            task.wait(LOOK_GAP)
        end
        C._intRunning = false
    end)
end

local PN = { "GameOver", "WinBoard", "Warmup", "Preparation", "Freezetime", "RoundOver", "Halftime", "Timeout" }
local PHN = {
    GameOver = "终局", WinBoard = "胜利", Warmup = "预热", Preparation = "部署",
    Freezetime = "冻结", RoundOver = "回合终", Halftime = "中场", Timeout = "超时",
    Round = "交战", Vote = "投票",
}
local function phase()
    for _, n in ipairs(PN) do
        if ReplicatedStorage:GetAttribute(n) then return n end
    end
    if ReplicatedStorage:GetAttribute("GameActive") then return "Round" end
    return "Vote"
end
local function phaseName() return PHN[phase()] or phase() end
local function canFire()
    local p = phase()
    return p == "Warmup" or p == "Round" or p == "Halftime" or p == "WinBoard" or p == "GameOver"
end

local function remoteName(seed)
    local v = math.max(1, math.floor(seed) % 2147483647)
    local t = {}
    for i = 1, 24 do
        v = v * 48271 % 2147483647
        local k = v % 62 + 1
        t[i] = string.sub("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", k, k)
    end
    return "sus_" .. table.concat(t)
end
local function fireRemote()
    if C._cr and C._cr.Parent then return C._cr end
    local s = ReplicatedStorage:GetAttribute("AmongUsSauce")
    if typeof(s) ~= "number" then return nil end
    local r = C.Events:FindFirstChild(remoteName(s))
    if r then C._cr = r end
    return r
end

local TN = { "Team", "team", "TEAM", "TeamID", "TeamName", "Group", "Side" }
local function team(p)
    if not p then return nil end
    for _, n in ipairs(TN) do
        local v = p:GetAttribute(n)
        if v ~= nil then return tostring(v) end
    end
    local c = p.Character
    if c then
        for _, n in ipairs(TN) do
            local v = c:GetAttribute(n)
            if v ~= nil then return tostring(v) end
        end
    end
    if p.Team then return p.Team.Name end
    return nil
end
local function enemy(p)
    if p == C.lp then return false end
    if not C.CFG.TeamCheck then return true end
    local a, b = team(C.lp), team(p)
    if not a or not b then return false end
    return a ~= b
end
local function alive(p)
    local a = p:GetAttribute("Alive")
    if a ~= nil then return a end
    local c = p.Character
    if c then
        a = c:GetAttribute("Alive")
        if a ~= nil then return a end
    end
    return true
end
local function valid(p)
    local c = p.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    if h and h.Health <= 0 then return false end
    return alive(p)
end
local function tpart(p)
    local c = p.Character
    if not c then return nil end
    local h = c:FindFirstChild("Head")
    if h then return h, h.Position end
    local r = c:FindFirstChild("HumanoidRootPart")
    if r then return r, r.Position end
    return nil
end
local function myRoot()
    local c = C.lp.Character
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart")
end

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.IgnoreWater = true
rp.RespectCanCollide = false
local function rebuildIgnore()
    local ig = {}
    if C.lp.Character then table.insert(ig, C.lp.Character) end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= C.lp and p.Character then table.insert(ig, p.Character) end
    end
    if C.cam then table.insert(ig, C.cam) end
    local m = Workspace:FindFirstChild("Map")
    if m then
        for _, n in ipairs({ "Ignore", "Clips", "Markers" }) do
            local c = m:FindFirstChild(n)
            if c then table.insert(ig, c) end
        end
    end
    local d = Workspace:FindFirstChild("Debris")
    if d then
        local s = d:FindFirstChild("ShuckyHax")
        if s then table.insert(ig, s) end
    end
    if C._tracerFolder then table.insert(ig, C._tracerFolder) end
    rp.FilterDescendantsInstances = ig
end
rebuildIgnore()

local SK = { "smoke", "fog", "gas", "cloud", "mist", "vape" }
local function smokeName(i)
    if not i then return false end
    local n = string.lower(i.Name or "")
    for _, k in ipairs(SK) do
        if string.find(n, k, 1, true) then return true end
    end
    return false
end
local function rebuildSmoke()
    local l = {}
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("BasePart") and smokeName(d) then
            local ok, t = pcall(function() return d.Transparency end)
            if ok and t and t < 0.98 then
                local r = math.max(d.Size.X, d.Size.Y, d.Size.Z) * 0.5
                if r >= 1 then l[#l + 1] = { part = d, radius = r } end
            end
        end
    end
    C._smoke = l
end
rebuildSmoke()
local function hitSphere(a, b, c, r)
    local ab = b - a
    local l2 = ab:Dot(ab)
    if l2 < 1e-6 then return (a - c).Magnitude <= r end
    local t = math.clamp((c - a):Dot(ab) / l2, 0, 1)
    return ((a + ab * t) - c).Magnitude <= r
end
local function smokeBlock(a, b)
    if not C.CFG.SmokeBlock then return false end
    for i = 1, #C._smoke do
        local s = C._smoke[i]
        if s.part and s.part.Parent and hitSphere(a, b, s.part.Position, s.radius) then return true end
    end
    return false
end

local function tickIgnore(dt)
    C._rt = C._rt + dt
    if C._rt >= 0.5 then
        C._rt = 0
        rebuildIgnore()
        rebuildSmoke()
    end
end

local function los(a, b)
    if smokeBlock(a, b) then return false end
    local d = b - a
    local dist = d.Magnitude
    if dist < 0.5 then return true end
    local u = d.Unit
    local cur = a
    local rem = dist
    local g = 0
    while rem > 0.1 and g < 12 do
        g = g + 1
        local res = Workspace:Raycast(cur, u * rem, rp)
        if not res then return true end
        if (res.Position - b).Magnitude < 1.5 then return true end
        local inst = res.Instance
        if inst.CanCollide then return false end
        if smokeName(inst) then return false end
        local ok, tr = pcall(function() return inst.Transparency end)
        if not ok or tr == nil or tr < 0.85 then return false end
        local st = (res.Position - cur).Magnitude + 0.15
        cur = cur + u * st
        rem = rem - st
    end
    return true
end

local function scan()
    local mr = myRoot()
    if not mr then return nil, nil end
    local mp = mr.Position
    local near, nd = nil, math.huge
    local vis, vd = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= C.lp and valid(p) and enemy(p) and not (C._targetFilter and C._blockedTargets[p]) then
            local part, pos = tpart(p)
            if part then
                local d = (pos - mp).Magnitude
                if d < nd then nd = d; near = { Player = p, Part = part, Pos = pos, Dist = d } end
                if d < vd and los(mp, pos) then vd = d; vis = { Player = p, Part = part, Pos = pos, Dist = d } end
            end
        end
    end
    return near, vis
end
local function target()
    local n, v = scan()
    if C.CFG.RayCheck then return v end
    return n
end
local function countEnemy()
    local n = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= C.lp and valid(p) and enemy(p) then n = n + 1 end
    end
    return n
end
local function curWeapon()
    local c = C.lp.Character
    if not c then return nil end
    local g = c:GetAttribute("WhatGun")
    if not g then return nil end
    if g == "Knife" then g = C.lp:GetAttribute("KnifeType") or "Knife" end
    return C.Weapons:FindFirstChild(g)
end
local function fireRate(w)
    if not w then return 0.1 end
    local f = w:GetAttribute("FireRate")
    if not f or f <= 0 then f = 0.1 end
    return f
end

local function ensureTracerFolder()
    if C._tracerFolder and C._tracerFolder.Parent then return C._tracerFolder end
    local f = Instance.new("Folder")
    f.Name = "def_Tracers"
    f.Parent = Workspace
    C._tracerFolder = f
    return f
end
local function randOff(r)
    local a = math.random() * 2 * math.pi
    local d = math.random() * r
    return Vector3.new(math.cos(a) * d, (math.random() - 0.5) * r * 0.4, math.sin(a) * d)
end
local function trace(s, e, life)
    if C.CFG.Stealth then return end
    if not C.CFG.Tracer or not s or not e then return end
    life = life or 2
    local sp = s + randOff(15)
    local len = (e - s).Magnitude
    if len < 0.5 then return end
    local mid = (sp + e) * 0.5
    local folder = ensureTracerFolder()
    local core = Instance.new("Part")
    core.Name = "def_trace"
    core.Anchored = true
    core.CanCollide = false
    core.CanQuery = false
    core.CanTouch = false
    core.CastShadow = false
    core.Material = Enum.Material.Neon
    core.Color = Color3.fromHSV(tick() % 1, 0.55, 1)
    core.Size = Vector3.new(0.06, 0.06, len)
    core.CFrame = CFrame.lookAt(mid, e)
    core.Parent = folder
    local glow = Instance.new("Part")
    glow.Name = "def_trace_glow"
    glow.Anchored = true
    glow.CanCollide = false
    glow.CanQuery = false
    glow.CanTouch = false
    glow.CastShadow = false
    glow.Material = Enum.Material.Neon
    glow.Color = core.Color
    glow.Transparency = 0.85
    glow.Size = Vector3.new(0.3, 0.3, len)
    glow.CFrame = core.CFrame
    glow.Parent = folder
    local fi = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    task.delay(life - 0.4, function()
        if core.Parent then TweenService:Create(core, fi, { Transparency = 1 }):Play() end
        if glow.Parent then TweenService:Create(glow, fi, { Transparency = 1 }):Play() end
    end)
    Debris:AddItem(core, life + 0.05)
    Debris:AddItem(glow, life + 0.05)
end

local function fireAt(t)
    local w = curWeapon()
    if not w then return end
    local r = fireRemote()
    if not r then return end
    local part = t.Part
    local cp = C.cam.CFrame.Position
    local hp = part.Position
    local dir = (hp - cp).Unit
    local v = {
        Hit = part.Parent, PartName = part.Name, Position = o3(hp), Normal = o3(-dir),
        hS = part.Size.Magnitude, hP = o3(hp), cCF = CFrame.lookAt(cp, hp),
        Headshot = (part.Name == "Head"), Wallbang = false, Ratio = 1,
        Endposition = o3(hp), Endnormal = o3(-dir),
    }
    r:FireServer(v, w, false, false, v.cCF, v.hP, nil, nil)
    local mr = myRoot()
    trace(mr and mr.Position or cp, hp, 2)
    playFireSound()
end

local function fireDrone(model, part)
    local w = curWeapon()
    if not w then return end
    local r = fireRemote()
    if not r then return end
    local cp = C.cam.CFrame.Position
    local hp = part.Position
    local dir = (hp - cp).Unit
    local size = Vector3.new(2, 2, 2)
    pcall(function()
        local _, sz = model:GetBoundingBox()
        size = sz
    end)
    local rad = math.max(size.X, size.Y, size.Z) * 0.5
    local ep = hp + dir * rad
    local v = { Normal = o3(dir), Hit = model, Position = o3(hp), Endposition = o3(ep), hS = size.Magnitude, Endnormal = o3(-dir) }
    r:FireServer(v, w, nil, false, nil, nil, nil, nil)
    local mr = myRoot()
    trace(mr and mr.Position or cp, hp, 2)
    playFireSound()
end

local CTN = { "CT", "CounterTerrorist", "Counter-Terrorist", "Counter", "Police", "Blue", "CTs" }
local TNN = { "T", "Terrorist", "Terrorists", "Red", "TR" }
local function isCT(s)
    if not s then return nil end
    local l = tostring(s):lower()
    for _, n in ipairs(CTN) do if l == n:lower() then return true end end
    for _, n in ipairs(TNN) do if l == n:lower() then return false end end
    return nil
end
local CCT = Color3.fromRGB(60, 140, 255)
local CT = Color3.fromRGB(255, 60, 60)
local function espColor(p)
    local c = isCT(team(p))
    if c == true then return CCT end
    if c == false then return CT end
    if enemy(p) then return CT end
    return CCT
end
local function createESP(p)
    if p == C.lp then return nil end
    local c = p.Character
    if not c then return nil end
    local h = Instance.new("Highlight")
    h.Name = "def_ESP"
    h.FillColor = espColor(p)
    h.FillTransparency = 0.55
    h.OutlineColor = espColor(p)
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = c
    setHlVisible(h, not C.CFG.Stealth)
    h.Parent = c
    return h
end
local function removeESP(p)
    local e = C._espCache[p]
    if e and e.hl then e.hl:Destroy() end
    C._espCache[p] = nil
end
local function refreshESP()
    if not C.CFG.ESP then
        for _, e in pairs(C._espCache) do if e.hl then e.hl:Destroy() end end
        C._espCache = {}
        return
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= C.lp then
            local c = p.Character
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if c and hum and hum.Health > 0 then
                local e = C._espCache[p]
                if not e or not e.hl or e.hl.Parent ~= c then
                    if e and e.hl then e.hl:Destroy() end
                    local h = createESP(p)
                    if h then C._espCache[p] = { hl = h, char = c } end
                else
                    local col = espColor(p)
                    e.hl.FillColor = col
                    e.hl.OutlineColor = col
                    setHlVisible(e.hl, not C.CFG.Stealth)
                end
            else
                removeESP(p)
            end
        end
    end
    for p, e in pairs(C._espCache) do
        if not p.Parent or not p.Character then
            if e.hl then e.hl:Destroy() end
            C._espCache[p] = nil
        end
    end
end

local DMIN = 15
local DMAX = 500
local MN = { "Laser Mine" }
local DK = { "drone", "uav", "breacher", "explosion", "explosive", "kamikaze", "suicide" }
local SRN = "Destroyable"
local HM = Color3.fromRGB(255, 210, 40)
local HD = Color3.fromRGB(0, 230, 255)

local lg = Instance.new("ScreenGui")
lg.Name = "def_labels"
lg.ResetOnSpawn = false
lg.IgnoreGuiInset = true
lg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
lg.Parent = CoreGui

local function mineName(i)
    if not i or i:IsA("MeshPart") then return false end
    local n = i.Name or ""
    for _, k in ipairs(MN) do if n == k then return true end end
    return string.find(string.lower(n), "mine", 1, true) ~= nil
end
local function droneName(i)
    if not i or i:IsA("MeshPart") then return false end
    if not (i:IsA("Model") or i:IsA("BasePart")) then return false end
    local n = string.lower(i.Name or "")
    for _, k in ipairs(DK) do if string.find(n, k, 1, true) then return true end end
    return false
end
local function anchorOf(i)
    if not i then return nil end
    local ok, r = pcall(function()
        if i:IsA("BasePart") then return i end
        if i:IsA("Model") then
            local pp = i.PrimaryPart
            if pp and pp:IsA("BasePart") then return pp end
            for _, n in ipairs({ "HumanoidRootPart", "Root", "Core", "Body", "Base", "Chassis" }) do
                local c = i:FindFirstChild(n)
                if c and c:IsA("BasePart") then return c end
            end
            local best, bv = nil, 0
            for _, d in ipairs(i:GetDescendants()) do
                if d:IsA("BasePart") then
                    local v = d.Size.X * d.Size.Y * d.Size.Z
                    if v > bv then bv, best = v, d end
                end
            end
            if best then return best end
            return i:FindFirstChildWhichIsA("BasePart", true)
        end
        return nil
    end)
    if ok then return r end
    return nil
end
local function adornees(i)
    local l = {}
    local function push(part)
        if not part:IsA("BasePart") then return end
        local ok, t = pcall(function() return part.Transparency end)
        if ok and (t or 0) < 0.95 then l[#l + 1] = part end
    end
    if i:IsA("BasePart") then push(i) end
    for _, d in ipairs(i:GetDescendants()) do
        if d:IsA("BasePart") then push(d) end
    end
    return l
end
local function applyHL(i, color)
    local e = C._reg[i]
    if not e then return end
    e.color = color
    for _, a in ipairs(adornees(i)) do
        local h = e.hlList[a]
        if h and h.Parent then
            h.FillColor = color
            h.OutlineColor = color
            setHlVisible(h, not C.CFG.Stealth)
        else
            h = Instance.new("Highlight")
            h.Name = "def_hl"
            h.FillColor = color
            h.FillTransparency = 0.55
            h.OutlineColor = color
            h.OutlineTransparency = 0
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Adornee = a
            setHlVisible(h, not C.CFG.Stealth)
            h.Parent = a
            e.hlList[a] = h
        end
    end
    for a, h in pairs(e.hlList) do
        if not a.Parent then
            if h then h:Destroy() end
            e.hlList[a] = nil
        end
    end
    if e.kind == "drone" and e.anchor and e.anchor.Parent then
        local mr = myRoot()
        local d = mr and (e.anchor.Position - mr.Position).Magnitude or 0
        local lb = e.label
        if not lb then
            lb = Instance.new("TextLabel")
            lb.BackgroundTransparency = 1
            lb.Font = Enum.Font.GothamBold
            lb.TextSize = 13
            lb.Parent = lg
            e.label = lb
        end
        local sp = C.cam:WorldToViewportPoint(e.anchor.Position)
        if sp.Z <= 0 then
            lb.Visible = false
        else
            lb.Visible = true
            lb.Text = string.format("%.0fm", d)
            lb.TextColor3 = HD
            lb.Position = UDim2.new(0, sp.X - 60, 0, sp.Y + 40)
            lb.Size = UDim2.new(0, 120, 0, 18)
        end
    elseif e.kind ~= "drone" then
        if e.label then e.label:Destroy(); e.label = nil end
    end
end
local function unreg(i)
    local e = C._reg[i]
    if e then
        for _, h in pairs(e.hlList) do if h then h:Destroy() end end
        if e.label then e.label:Destroy(); e.label = nil end
    end
    C._reg[i] = nil
end
local function register(i, kind)
    if C._reg[i] or not i or not i.Parent then return end
    if not C.CFG.MineESP and kind == "mine" then return end
    if not C.CFG.AntiDrone and kind == "drone" then return end
    local a = anchorOf(i)
    if not a then return end
    C._reg[i] = { kind = kind, anchor = a, hlList = {}, color = nil, label = nil }
    applyHL(i, kind == "mine" and HM or HD)
end
local function scanDestroy(dt)
    C._st2 = C._st2 + dt
    if C._st2 < 0.1 then return end
    C._st2 = 0
    local root = Workspace:FindFirstChild(SRN)
    if not root then
        for i in pairs(C._reg) do unreg(i) end
        return
    end
    local seen = {}
    for _, c in ipairs(root:GetChildren()) do
        if not c:IsA("MeshPart") and (c:IsA("Model") or c:IsA("BasePart")) then
            local kind = nil
            if mineName(c) then kind = "mine"
            elseif droneName(c) then kind = "drone" end
            if kind and ((kind == "mine" and C.CFG.MineESP) or (kind == "drone" and C.CFG.AntiDrone)) then
                seen[c] = true
                if not C._reg[c] then
                    register(c, kind)
                else
                    local a = anchorOf(c)
                    if a then C._reg[c].anchor = a end
                    applyHL(c, kind == "mine" and HM or HD)
                end
            end
        end
    end
    for i in pairs(C._reg) do
        if not seen[i] then unreg(i) end
    end
end
local function tryDrone()
    if not C.CFG.Enabled or not C.CFG.AntiDrone then return end
    local now = tick()
    local mr = myRoot()
    if not mr then return end
    local mp = mr.Position
    local bi, bp, bd = nil, nil, math.huge
    for i, e in pairs(C._reg) do
        if e.kind == "drone" and e.anchor and e.anchor.Parent then
            local d = (e.anchor.Position - mp).Magnitude
            if d > DMIN and d < DMAX and d < bd and los(mp, e.anchor.Position) then
                bd, bp, bi = d, e.anchor, i
            end
        end
    end
    if not bp or not bi then return end
    local w = curWeapon()
    if not w or now - C._dLast < fireRate(w) then return end
    C._dLast = now
    fireDrone(bi, bp)
end

local function applySpeed()
    if not C.CFG.MaxSpeed then return end
    local c = C.lp.Character
    if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return end
    if C._hip == nil then C._hip = h.HipHeight end
    if h.WalkSpeed ~= C.SPD.WalkSpeed then h.WalkSpeed = C.SPD.WalkSpeed end
    if C._hip and h.HipHeight ~= C._hip then h.HipHeight = C._hip end
    local a = c:GetAttribute("Accl")
    if a ~= nil and a ~= C.SPD.Accl then c:SetAttribute("Accl", C.SPD.Accl) end
    if h:GetState() == Enum.HumanoidStateType.Seated then h:ChangeState(Enum.HumanoidStateType.Running) end
    if h.Sit then h.Sit = false end
end
local function antiFloat(dt)
    if not C.CFG.MaxSpeed then return end
    local c = C.lp.Character
    if not c then return end
    local r = c:FindFirstChild("HumanoidRootPart")
    local h = c:FindFirstChildOfClass("Humanoid")
    if not r or not h then return end
    if r.Anchored or h.PlatformStand or h.Sit then C._air = 0; return end
    local s = h:GetState()
    local inAir = (s == Enum.HumanoidStateType.Freefall) or (s == Enum.HumanoidStateType.Jumping) or (s == Enum.HumanoidStateType.FallingDown)
    if inAir then
        C._air = C._air + dt
        if C._air > 0.5 and s ~= Enum.HumanoidStateType.Jumping then
            h:ChangeState(Enum.HumanoidStateType.Running)
            local v = r.AssemblyLinearVelocity
            r.AssemblyLinearVelocity = Vector3.new(v.X, -5, v.Z)
            C._air = 0
        end
    else
        C._air = 0
    end
end
local function hookAccl()
    local c = C.lp.Character
    if not c then return end
    pcall(function()
        c:GetAttributeChangedSignal("Accl"):Connect(function()
            if C.CFG.MaxSpeed then
                local v = c:GetAttribute("Accl")
                if v ~= nil and v ~= C.SPD.Accl then
                    task.defer(function()
                        if C.CFG.MaxSpeed and c.Parent then c:SetAttribute("Accl", C.SPD.Accl) end
                    end)
                end
            end
        end)
    end)
end
C.lp.CharacterAdded:Connect(function()
    C._hip = nil
    C._spinAngle = 0
    hookAccl()
end)
hookAccl()

local function applyTP(on)
    if not on then return end
    ss(C.lp, "CameraMode", Enum.CameraMode.Classic)
    ss(C.lp, "CameraMaxZoomDistance", 128)
    ss(C.lp, "CameraMinZoomDistance", 8)
end
RunService.Stepped:Connect(function()
    if C.CFG.ThirdPerson and C.lp.CameraMode ~= Enum.CameraMode.Classic then
        ss(C.lp, "CameraMode", Enum.CameraMode.Classic)
    end
end)
si(C.lp, "CameraMode", function()
    if C.CFG.ThirdPerson and C.lp.CameraMode ~= Enum.CameraMode.Classic then
        task.defer(function() if C.CFG.ThirdPerson then ss(C.lp, "CameraMode", Enum.CameraMode.Classic) end end)
    end
end)
si(C.lp, "CameraMaxZoomDistance", function()
    if C.CFG.ThirdPerson and C.lp.CameraMaxZoomDistance ~= 128 then
        task.defer(function() if C.CFG.ThirdPerson then ss(C.lp, "CameraMaxZoomDistance", 128) end end)
    end
end)
C.lp.CharacterAdded:Connect(function()
    if C.CFG.ThirdPerson then
        task.wait(0.1)
        applyTP(true)
    end
end)

local function backTurn()
    if not C.CFG.BackTurn then return end
    local mr = myRoot()
    if not mr or mr.Anchored then return end
    local n, v = scan()
    local t = v or n
    if not t then return end
    local mp = mr.Position
    local te = t.Pos - mp
    if te.Magnitude < 0.1 then return end
    local fb = Vector3.new(-te.X, 0, -te.Z)
    if fb.Magnitude < 0.01 then return end
    fb = fb.Unit
    mr.CFrame = CFrame.new(mp) * CFrame.lookAt(mp, mp + fb).Rotation
end

local function spin(dt)
    if not C.CFG.Spin then return end
    local mr = myRoot()
    if not mr or mr.Anchored then return end
    local sign = (C.SPIN.Dir == "逆时针") and -1 or 1
    C._spinAngle = (C._spinAngle + math.rad(C.SPIN.Speed) * dt * sign) % (math.pi * 2)
    local p = mr.Position
    local v = mr.AssemblyLinearVelocity
    mr.CFrame = CFrame.new(p) * CFrame.Angles(0, C._spinAngle, 0)
    mr.AssemblyLinearVelocity = v
end

local function targetKey(p)
    return p.Name .. " [" .. tostring(team(p) or "无队伍") .. "]"
end
local function targetOptions()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= C.lp and valid(p) and enemy(p) then
            t[#t + 1] = targetKey(p)
        end
    end
    if #t == 0 then t[1] = "暂无目标" end
    return t
end

local MainTab = Window:AddTab("防御", "shield")
local L = MainTab:AddLeftGroupbox("ragebot", "crosshair")
local R = MainTab:AddRightGroupbox("调参", "sliders-horizontal")
local D2 = MainTab:AddLeftGroupbox("反制", "shield-check")
local V = MainTab:AddRightGroupbox("视界", "eye")

L:AddToggle("defEnable", {
    Text = "开火总控",
    Default = false,
    Callback = function(v) C.CFG.Enabled = v end,
})
L:AddToggle("defRay", {
    Text = "视线校验",
    Default = false,
    Callback = function(v) C.CFG.RayCheck = v end,
})

C._targetSel = L:AddDropdown("defTargets", {
    Text = "目标清单",
    Values = targetOptions(),
    Default = {},
    Multi = true,
    Callback = function(Values)
        C._blockedTargets = {}
        if not C._targetFilter then return end
        local has = false
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= C.lp and Values and Values[targetKey(p)] then has = true end
        end
        if not has then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= C.lp and not (Values and Values[targetKey(p)]) then
                C._blockedTargets[p] = true
            end
        end
    end,
})

L:AddToggle("defTargetOn", {
    Text = "清单过滤",
    Default = false,
    Callback = function(v)
        C._targetFilter = v
        if not v then C._blockedTargets = {} end
    end,
})

L:AddToggle("defTeam", {
    Text = "敌我识别",
    Default = false,
    Callback = function(v) C.CFG.TeamCheck = v end,
})
L:AddToggle("defBack", {
    Text = "反向姿态",
    Default = false,
    Callback = function(v) C.CFG.BackTurn = v end,
})

L:AddDropdown("defSpinDir", {
    Text = "自旋方向",
    Values = { "顺时针", "逆时针" },
    Default = 1,
    Multi = false,
    Callback = function(Value)
        C.SPIN.Dir = (Value == "逆时针") and "逆时针" or "顺时针"
    end,
})
L:AddSlider("defSpinSpeed", {
    Text = "自旋速率",
    Default = C.SPIN.Speed,
    Min = 30, Max = 1080, Rounding = 0,
    Callback = function(v) C.SPIN.Speed = v end,
})
L:AddToggle("defSpin", {
    Text = "自旋同步",
    Default = false,
    Callback = function(v)
        C.CFG.Spin = v
        if not v then C._spinAngle = 0 end
    end,
})

D2:AddToggle("defMine", {
    Text = "雷区标记",
    Default = false,
    Callback = function(v)
        C.CFG.MineESP = v
        if not v then
            for i, e in pairs(C._reg) do
                if e.kind == "mine" then unreg(i) end
            end
        end
    end,
})
D2:AddToggle("defDrone", {
    Text = "无人机拦截",
    Default = false,
    Callback = function(v) C.CFG.AntiDrone = v end,
})
D2:AddToggle("defSmoke", {
    Text = "烟幕屏蔽",
    Default = false,
    Callback = function(v) C.CFG.SmokeBlock = v end,
})
D2:AddToggle("defSpeed", {
    Text = "极速驱动",
    Default = false,
    Callback = function(v) C.CFG.MaxSpeed = v end,
})

V:AddToggle("defESP", {
    Text = "敌影高亮",
    Default = false,
    Callback = function(v)
        C.CFG.ESP = v
        refreshESP()
    end,
})
V:AddToggle("defTP", {
    Text = "越肩视角",
    Default = false,
    Callback = function(v)
        C.CFG.ThirdPerson = v
        applyTP(v)
    end,
})
V:AddToggle("defTracer", {
    Text = "弹道可视",
    Default = false,
    Callback = function(v) C.CFG.Tracer = v end,
})
V:AddToggle("defHead", {
    Text = "头部控制",
    Default = false,
    Callback = function(v)
        C.CFG.HeadCtrl = v
        if v then startHeadCtrl() end
    end,
})
V:AddDropdown("defHeadMode", {
    Text = "头部方向",
    Values = { "抬头", "低头" },
    Default = 2,
    Multi = false,
    Callback = function(Value)
        if Value == 1 or Value == "抬头" then
            C.HEAD.Mode = "抬头"
        else
            C.HEAD.Mode = "低头"
        end
    end,
})
V:AddToggle("defStealth", {
    Text = "静默模式",
    Default = false,
    Callback = function(v)
        C.CFG.Stealth = v
        if lg then lg.Enabled = not v end
        if C._slGui then C._slGui.Enabled = not v end
        for _, e in pairs(C._espCache) do
            setHlVisible(e.hl, not v)
        end
        for _, e in pairs(C._reg) do
            for _, h in pairs(e.hlList) do
                setHlVisible(h, not v)
            end
        end
    end,
})

R:AddSlider("defWalkSpeed", {
    Text = "移动速率",
    Default = C.SPD.WalkSpeed,
    Min = 16, Max = 80, Rounding = 0,
    Callback = function(v) C.SPD.WalkSpeed = v end,
})

C._slGui = Instance.new("ScreenGui")
C._slGui.Name = "defense_status"
C._slGui.ResetOnSpawn = false
C._slGui.IgnoreGuiInset = true
C._slGui.Parent = CoreGui

C._sl = Instance.new("TextLabel")
C._sl.Size = UDim2.new(0, 260, 0, 76)
C._sl.Position = UDim2.new(0, 20, 0, 560)
C._sl.BackgroundColor3 = Color3.fromRGB(10, 16, 24)
C._sl.BackgroundTransparency = 0.2
C._sl.BorderSizePixel = 0
C._sl.TextColor3 = Color3.fromRGB(110, 235, 255)
C._sl.Font = Enum.Font.Code
C._sl.TextSize = 12
C._sl.TextXAlignment = Enum.TextXAlignment.Left
C._sl.TextYAlignment = Enum.TextYAlignment.Top
C._sl.Text = "SYS / 初始化"
C._sl.Parent = C._slGui
Instance.new("UICorner", C._sl).CornerRadius = UDim.new(0, 8)

local function refreshTargetOptions()
    if not C._targetSel then return end
    local keep = {}
    pcall(function()
        local v = C._targetSel.Value
        if type(v) == "table" then
            for k, on in pairs(v) do
                if on then keep[k] = true end
            end
        end
    end)
    pcall(function() C._targetSel:SetValues(targetOptions()) end)
    pcall(function() C._targetSel:SetValue(keep) end)
end

local function hookChar(p)
    p.CharacterAdded:Connect(function(c)
        task.wait(0.3)
        if C.CFG.ESP and p ~= C.lp then
            removeESP(p)
            local h = createESP(p)
            if h then C._espCache[p] = { hl = h, char = c } end
        end
    end)
end
for _, p in ipairs(Players:GetPlayers()) do hookChar(p) end
Players.PlayerAdded:Connect(function(p)
    hookChar(p)
end)
Players.PlayerRemoving:Connect(function(p)
    removeESP(p)
    C._blockedTargets[p] = nil
end)

RunService.RenderStepped:Connect(function(dt)
    applySpeed()
    antiFloat(dt)
    tickIgnore(dt)
    scanDestroy(dt)
    tryDrone()
    if C.CFG.ThirdPerson and C.lp.CameraMode ~= Enum.CameraMode.Classic then
        ss(C.lp, "CameraMode", Enum.CameraMode.Classic)
    end
    if C.CFG.Spin then spin(dt) elseif C.CFG.BackTurn then backTurn() end
    C._espT = C._espT + dt
    if C._espT >= 0.5 then
        C._espT = 0
        refreshESP()
    end
    C._optT = C._optT + dt
    if C._optT >= 1 then
        C._optT = 0
        refreshTargetOptions()
    end
    local pn = phaseName()
    local spinTxt = C.CFG.Spin and (C.SPIN.Dir .. " " .. C.SPIN.Speed) or "关"
    local headTxt = C.CFG.HeadCtrl and C.HEAD.Mode or "关"
    local listTxt = (C._targetFilter and "开" or "关") .. " | 头控 " .. headTxt
    if not C.CFG.Enabled then
        setSl(string.format("SYS / %s\n待机 | 敌 %d | 烟 %d\n清单 %s | 自旋 %s",
            pn, countEnemy(), #C._smoke, listTxt, spinTxt))
        return
    end
    if not canFire() then
        setSl(string.format("SYS / %s\n禁火 | 敌 %d | 烟 %d\n清单 %s | 自旋 %s",
            pn, countEnemy(), #C._smoke, listTxt, spinTxt))
        return
    end
    if not fireRemote() then
        setSl("SYS / 链路断开")
        return
    end
    local t = target()
    if not t then
        setSl(string.format("SYS / %s\n无锁定 | 敌 %d | 烟 %d\n清单 %s | 自旋 %s",
            pn, countEnemy(), #C._smoke, listTxt, spinTxt))
        return
    end
    local w = curWeapon()
    local now = tick()
    if now - C._lastFire >= fireRate(w) then
        C._lastFire = now
        fireAt(t)
    end
    setSl(string.format("SYS / %s\n锁定 %s %dm | 敌 %d\n烟 %d | 清单 %s | 自旋 %s",
        pn, t.Player.Name, math.floor(t.Dist), countEnemy(), #C._smoke, listTxt, spinTxt))
end)

for _, p in ipairs(Players:GetPlayers()) do
    local c = p.Character
    if c then
        for _, inst in ipairs(c:GetDescendants()) do
            if inst:IsA("Highlight") and (inst.Name == "wlqx_ESP" or inst.Name == "wlqx_hl") then
                inst:Destroy()
            end
        end
    end
end
for _, inst in ipairs(CoreGui:GetChildren()) do
    if inst.Name == "wlqx_labels" then inst:Destroy() end
end
for _, inst in ipairs(Workspace:GetChildren()) do
    if inst.Name == "wlqx_Tracers" then inst:Destroy() end
end

refreshESP()

local function unload()
    C.CFG.HeadCtrl = false
    C._lookRemote = nil
    for _, inst in ipairs(CoreGui:GetChildren()) do
        if inst.Name == "wlqx_labels" or inst.Name == "def_labels" or inst.Name == "defense_status" then
            inst:Destroy()
        end
    end
    for _, inst in ipairs(Workspace:GetChildren()) do
        if inst.Name == "wlqx_Tracers" or inst.Name == "def_Tracers" then inst:Destroy() end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p.Character
        if c then
            for _, inst in ipairs(c:GetDescendants()) do
                if inst:IsA("Highlight") and (inst.Name == "wlqx_ESP" or inst.Name == "def_ESP" or inst.Name == "wlqx_hl" or inst.Name == "def_hl") then
                    inst:Destroy()
                end
            end
        end
    end
    if C._tracerFolder then C._tracerFolder:Destroy(); C._tracerFolder = nil end
    if lg then lg:Destroy() end
    if C._slGui then C._slGui:Destroy(); C._slGui = nil; C._sl = nil end
    if C._sound then C._sound:Destroy(); C._sound = nil end
    for p in pairs(C._espCache) do removeESP(p) end
    for i in pairs(C._reg) do unreg(i) end
end

if GHub and GHub.RegisterModule then
    GHub.RegisterModule("防御", {
        Name = "防御",
        MainTab = MainTab,
        Unload = unload,
    })
end

return {
    Unload = unload,
    Config = C,
}
end
