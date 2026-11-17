local lp = game:GetService("Players").LocalPlayer
local oldKick = lp.Kick
lp.Kick = function(self, ...)
    return
end
getgenv().Kick = function(...) return end

local oldGF = getfenv
getgenv().getfenv = function(lvl)
    local ok, e = pcall(oldGF, lvl)
    if ok and type(e) == "table" then
        e.getgenv = nil e.syn = nil e.krnl = nil e.fluxus = nil
    end
    return e
end

return function(Library, Window, GHub)
    local Players = game:GetService("Players")
    local lp = Players.LocalPlayer

    local C = {}
    C.genv = (type(getgenv) == "function") and getgenv() or _G
    GHub = GHub or C.genv.GRHub

    C.RunService = game:GetService("RunService")
    C.UserInput  = game:GetService("UserInputService")
    C.Workspace  = game:GetService("Workspace")
    C.Players    = game:GetService("Players")
    C.Replicated = game:GetService("ReplicatedStorage")
    C.CoreGui    = game:GetService("CoreGui")
    C.lp    = C.Players.LocalPlayer
    C.Event = C.Replicated:WaitForChild("Events"):WaitForChild("MeleeSystem")
    C.GunSys = C.Replicated:WaitForChild("Events"):WaitForChild("GunSystem")
    C.ENTITIES = C.Workspace:WaitForChild("Game"):WaitForChild("Entities")

    C.running          = false
    C.ESP_ENABLED      = true
    C.KILL_ENABLED     = true
    C.ATTACK_RANGE     = 30
    C.ATTACK_INTERVAL  = 0.12
    C.MAX_TARGETS      = 3
    C.TARGET_SCAN_INTERVAL = 0.1
    C.DIRECTION        = "Up"

    C.SWING_PARAMS = {
        AttackDelay     = 0.05,
        BaseDamage      = 52,
        AttackStartTime = 0.26,
        Cooldown        = 0.15,
        AttackTime      = 0.30,
    }

    C.IGNORE_NAMES   = { Bomber = true }

    C.ESP_FILL_COLOR    = Color3.fromRGB(0, 255, 100)
    C.ESP_OUTLINE_COLOR = Color3.fromRGB(0, 255, 100)
    C.ESP_BOMBER_FILL   = Color3.fromRGB(255, 255, 0)
    C.ESP_BOMBER_OUTLINE= Color3.fromRGB(255, 255, 0)
    C.ESP_BOSS_FILL     = Color3.fromRGB(180, 0, 255)
    C.ESP_BOSS_OUTLINE  = Color3.fromRGB(180, 0, 255)
    C.ESP_MAX_DISTANCE  = 500

    C.SHOOT_ENABLED   = false
    C.SHOOT_INTERVAL  = 0.2
    C.SHOOT_BATCH_MAX = 50
    C.SHOOT_RANGE     = 500
    C._shootConn      = nil
    C._shootLast      = 0
    C._shootTool      = nil

    C.STAMINA_ENABLED = false
    C.STAMINA_MAX     = 100
    C.STAMINA_MIN     = 10
    C._staminaConn    = nil
    C._stamT          = 0
    C._stamPhase      = 0
    C._stamFreq       = 0.8
    C._stamNoise      = 6
    C._stamWriteInterval = 0.07
    C._stamWriteLast  = 0

    C.SPEED_ENABLED   = false
    C.SPEED_VALUE     = 16
    C._speedConn      = nil
    C._speedConn2     = nil
    C._speedConn3     = nil
    C._speedHum       = nil
    C._speedKillConn  = nil
    C._origWalkSpeed  = 16

    C.CF_SPEED_ENABLED = false
    C.CF_SPEED_VALUE   = 1.5
    C._cfConn          = nil

    C.SPIN_ENABLED    = false
    C.SPIN_SPEED      = 250
    C.SPIN_DIR        = 1
    C._spinAngle      = 0
    C._origAutoRotate = true
    C._spinConn       = nil

    C._fireCalls = 0
    C._lastFail  = "未启动"
    C._lastGun   = "无"
    C.isDead     = false

    C._cachedMelee   = nil
    C._cachedTargets = {}
    C._lastScan      = 0
    C._espData       = {}
    C._allConns      = {}

    local function track(conn)
        if conn then C._allConns[#C._allConns + 1] = conn end
        return conn
    end

    local function getChar() return C.lp.Character end
    local function humOf(m) return m and m:FindFirstChildWhichIsA("Humanoid") end
    local function isIgnored(m) return C.IGNORE_NAMES[m.Name] == true end
    local function playerOf(m) return C.Players:GetPlayerFromCharacter(m) end

    local function isBomber(m)
        return m ~= nil and string.find(m.Name, "Bomber", 1, true) ~= nil
    end
    local function isBoss(m)
        return m ~= nil and string.find(m.Name, "Boss", 1, true) ~= nil
    end
    local function isZombie(m)
        if not m or not m.Parent then return false end
        if isIgnored(m) then return false end
        if playerOf(m) then return false end
        return m:IsDescendantOf(C.ENTITIES)
    end
    local function isShootTarget(m)
        if not m or not m.Parent then return false end
        if playerOf(m) then return false end
        return m:IsDescendantOf(C.ENTITIES)
    end
    local function isAlive(m)
        local h = humOf(m)
        return h ~= nil and h.Health > 0
    end

    local function wearTool(tool)
        local char = getChar()
        if not tool or not char then return false end
        if tool.Parent == char then return true end
        local bp = C.lp:FindFirstChild("Backpack")
        if bp and tool.Parent == bp then
            tool.Parent = char
            return true
        end
        return tool.Parent == char
    end

    local AC_KEYWORDS = {
        "anticheat", "anti_cheat", "anti-cheat", "antichat",
        "ac_", "_ac", "guard", "detect", "ban", "kick",
        "cheat", "exploit", "stamina", "sprint", "fatigue",
    }
    local function nameHitsAC(name)
        if type(name) ~= "string" then return false end
        local lower = string.lower(name)
        for _, kw in ipairs(AC_KEYWORDS) do
            if string.find(lower, kw, 1, true) then return true end
        end
        return false
    end
    local function disableScriptsIn(root, depth)
        if not root or depth > 4 then return end
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                if nameHitsAC(obj.Name) then
                    pcall(function() obj.Disabled = true end)
                end
            end
        end
    end
    local function killRunServiceConns()
        if type(getconnections) ~= "function" then return end
        local services = {
            C.RunService.Heartbeat,
            C.RunService.RenderStepped,
            C.RunService.Stepped,
            C.RunService.PreSimulation,
            C.RunService.PostSimulation,
        }
        for _, sig in ipairs(services) do
            local ok, conns = pcall(getconnections, sig)
            if ok and type(conns) == "table" then
                for _, conn in ipairs(conns) do
                    local hit = false
                    local okf, fn = pcall(function() return conn.Function end)
                    if okf and fn and nameHitsAC(tostring(fn)) then hit = true end
                    if not hit then
                        local oks, sn = pcall(function() return conn.Script end)
                        if oks and sn and nameHitsAC(tostring(sn.Name or sn)) then hit = true end
                    end
                    if hit then
                        pcall(function() conn:Disconnect() end)
                    end
                end
            end
        end
    end
    local function killAntiCheat()
        pcall(killRunServiceConns)
        pcall(function() disableScriptsIn(C.Replicated, 0) end)
        pcall(function() disableScriptsIn(C.lp:FindFirstChild("PlayerScripts"), 0) end)
        pcall(function() disableScriptsIn(C.lp, 0) end)
        pcall(function()
            local ch = getChar()
            if ch then disableScriptsIn(ch, 0) end
        end)
        pcall(function()
            if game:FindService("ServerStorage") then
                disableScriptsIn(game:GetService("ServerStorage"), 0)
            end
        end)
        pcall(function() disableScriptsIn(C.CoreGui, 0) end)
    end

    local function startStamina()
        if C._staminaConn then C._staminaConn:Disconnect(); C._staminaConn = nil end
        C._stamT = 0
        C._stamPhase = math.random() * 10
        C._stamWriteLast = 0
        C._staminaConn = track(C.RunService.Heartbeat:Connect(function(dt)
            local char = C.lp.Character
            if not char then return end

            C._stamT = C._stamT + dt
            C._stamWriteLast = C._stamWriteLast + dt
            if C._stamWriteLast < C._stamWriteInterval then return end
            C._stamWriteLast = 0

            local MAX = C.STAMINA_MAX
            local MIN = math.min(C.STAMINA_MIN, MAX)

            local wave = (math.sin((C._stamT * C._stamFreq + C._stamPhase) * math.pi) + 1) / 2
            local noise = (math.random() - 0.5) * C._stamNoise
            local val = MIN + (MAX - MIN) * wave + noise
            val = math.clamp(val, MIN, MAX)

            pcall(function() char:SetAttribute("stamina", val) end)
            pcall(function() char:SetAttribute("maxStamina", MAX) end)
        end))
    end
    local function stopStamina()
        if C._staminaConn then C._staminaConn:Disconnect(); C._staminaConn = nil end
    end

    local function applySpeed()
        local char = C.lp.Character
        local h = char and char:FindFirstChildOfClass("Humanoid")
        if not h then return end
        if h.WalkSpeed ~= C.SPEED_VALUE then h.WalkSpeed = C.SPEED_VALUE end
        if char:GetAttribute("WalkSpeed") ~= C.SPEED_VALUE then
            pcall(function() char:SetAttribute("WalkSpeed", C.SPEED_VALUE) end)
        end
    end
    local function killSpeedWatchers(h)
        if not h then return end
        if C._speedKillConn then C._speedKillConn:Disconnect(); C._speedKillConn = nil end
        C._speedKillConn = track(h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if not C.SPEED_ENABLED then return end
            if h.WalkSpeed ~= C.SPEED_VALUE then
                h.WalkSpeed = C.SPEED_VALUE
            end
        end))
        h.WalkSpeed = C.SPEED_VALUE
    end
    local function bindSpeedHum(h)
        if not h then return end
        if C._speedHum == h then return end
        if C._speedConn2 then C._speedConn2:Disconnect(); C._speedConn2 = nil end
        C._speedHum = h
        C._origWalkSpeed = h.WalkSpeed
        C._speedConn2 = track(h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if not C.SPEED_ENABLED then return end
            if h.WalkSpeed ~= C.SPEED_VALUE then h.WalkSpeed = C.SPEED_VALUE end
        end))
        killSpeedWatchers(h)
    end
    local function startSpeed()
        if C._speedConn then C._speedConn:Disconnect() end
        if C._speedConn3 then C._speedConn3:Disconnect(); C._speedConn3 = nil end
        applySpeed()
        bindSpeedHum(humOf(C.lp.Character))
        C._speedConn = track(C.RunService.Heartbeat:Connect(function()
            if not C.SPEED_ENABLED then return end
            applySpeed()
        end))
        C._speedConn3 = track(C.RunService.RenderStepped:Connect(function()
            if not C.SPEED_ENABLED then return end
            applySpeed()
        end))
        local char = C.lp.Character
        if char then bindSpeedHum(humOf(char)) end
    end
    local function stopSpeed()
        if C._speedConn then C._speedConn:Disconnect(); C._speedConn = nil end
        if C._speedConn2 then C._speedConn2:Disconnect(); C._speedConn2 = nil end
        if C._speedConn3 then C._speedConn3:Disconnect(); C._speedConn3 = nil end
        if C._speedKillConn then C._speedKillConn:Disconnect(); C._speedKillConn = nil end
        C._speedHum = nil
        local char = C.lp.Character
        local h = char and char:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = 16 end
        if char then pcall(function() char:SetAttribute("WalkSpeed", 16) end) end
    end

    local function getMoveVector()
        local char = C.lp.Character
        local h = char and char:FindFirstChildOfClass("Humanoid")
        if not h then return Vector3.zero end
        return h.MoveDirection
    end
    local function startCoordSpeed()
        if C._cfConn then C._cfConn:Disconnect() end
        C._cfConn = track(C.RunService.Heartbeat:Connect(function(dt)
            local char = C.lp.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then return end
            local dir = getMoveVector()
            if dir.Magnitude < 0.01 then return end
            local step = C.CF_SPEED_VALUE * 60 * dt
            root.CFrame = root.CFrame + dir.Unit * step
        end))
    end
    local function stopCoordSpeed()
        if C._cfConn then C._cfConn:Disconnect(); C._cfConn = nil end
    end

    local function spinStep(dt, advance)
        if not C.SPIN_ENABLED then return end
        local char = C.lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hrp.Parent or not hum or hum.Health <= 0 then return end
        if advance then
            C._spinAngle = (C._spinAngle + C.SPIN_SPEED * C.SPIN_DIR * dt) % 360
        end
        pcall(function()
            hum.AutoRotate = false
            local rx, _, rz = hrp.CFrame:ToOrientation()
            hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(rx, math.rad(C._spinAngle), rz)
        end)
    end
    local function startSpin()
        if C._spinConn then C._spinConn:Disconnect() end
        local char = C.lp.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hum then C._origAutoRotate = hum.AutoRotate end
        if hrp then
            local _, ry = hrp.CFrame:ToOrientation()
            C._spinAngle = math.deg(ry) % 360
        end
        C._spinConn = track(C.RunService.Heartbeat:Connect(function(dt) spinStep(dt, true) end))
    end
    local function stopSpin()
        if C._spinConn then C._spinConn:Disconnect(); C._spinConn = nil end
        local char = C.lp.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        pcall(function() if hum then hum.AutoRotate = C._origAutoRotate end end)
        pcall(function() if hrp then hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0) end end)
    end

    local function isMeleeTool(tool)
        if not tool or not tool:IsA("Tool") then return false end
        local a = tool:FindFirstChild("Animations")
        return a ~= nil and a:FindFirstChild("SwingUpEnd") ~= nil
    end
    local function ensureMelee()
        local c, ch = C._cachedMelee, getChar()
        if c and c.Parent == ch and isMeleeTool(c) then return c end
        if ch then
            for _, t in ipairs(ch:GetChildren()) do
                if isMeleeTool(t) then C._cachedMelee = t; wearTool(t); return t end
            end
        end
        local bp = C.lp:FindFirstChild("Backpack")
        if bp then
            for _, t in ipairs(bp:GetChildren()) do
                if isMeleeTool(t) then
                    local h = ch and humOf(ch)
                    if h then pcall(function() wearTool(t) end) end
                    task.wait()
                    C._cachedMelee = t
                    return t
                end
            end
        end
        C._cachedMelee = nil
        return nil
    end

    local function isGunTool(t)
        if not t or not t:IsA("Tool") then return false end
        if t.Name == "Flamethrower" then return true end
        local values = t:FindFirstChild("Values")
        if not values or not values:FindFirstChild("Ammo") then return false end
        return true
    end
    local function findGun()
        local char = getChar()
        if char then
            for _, t in ipairs(char:GetChildren()) do
                if isGunTool(t) then return t end
            end
        end
        local bp = C.lp:FindFirstChild("Backpack")
        if bp then
            for _, t in ipairs(bp:GetChildren()) do
                if isGunTool(t) then return t end
            end
        end
        return nil
    end
    local function equipGun()
        local tool = findGun()
        if not tool then return nil end
        C._shootTool = tool
        wearTool(tool)
        return tool
    end

    local function fakeProjectile()
        local p = Instance.new("Part")
        p.Name = "Part"
        p.Anchored = true
        p.CanCollide = false
        p.Transparency = 1
        p.Size = Vector3.new(0.2, 0.2, 0.2)
        p.CFrame = CFrame.new(0, -9999, 0)
        p.Parent = C.Workspace.CurrentCamera
        task.delay(0.05, function() p:Destroy() end)
        return p
    end

    local function shootAllZombies()
        local weapon = equipGun()
        if not weapon then return end
        local myRoot = getChar() and getChar():FindFirstChild("HumanoidRootPart")
        local origin = myRoot and myRoot.Position or Vector3.zero
        local zombies = {}
        for _, e in ipairs(C.ENTITIES:GetChildren()) do
            if isShootTarget(e) and isAlive(e) then
                local hitPart = e:FindFirstChild("Head") or e:FindFirstChild("Torso") or e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart
                if hitPart then
                    local dist = (hitPart.Position - origin).Magnitude
                    if dist <= C.SHOOT_RANGE then
                        zombies[#zombies + 1] = { entity = e, part = hitPart, dist = dist }
                    end
                end
            end
        end
        if #zombies == 0 then return end
        table.sort(zombies, function(a, b) return a.dist < b.dist end)
        local batch = {}
        for i = 1, math.min(C.SHOOT_BATCH_MAX, #zombies) do
            local z = zombies[i]
            local dir = (z.part.Position - origin).Unit
            batch[#batch + 1] = {
                hitArmor = false,
                direction = dir,
                penetrationCount = 0,
                projectile = fakeProjectile(),
                result = {
                    Normal = Vector3.new(0, 1, 0),
                    Position = z.part.Position,
                    Instance = z.part,
                    Material = Enum.Material.Plastic,
                    Distance = z.dist
                },
                target = z.entity
            }
        end
        if #batch > 0 then
            pcall(function() C.GunSys:FireServer("DamageBatch", weapon, batch) end)
        end
    end
    local function startShootLoop()
        if C._shootConn then return end
        C._shootConn = track(C.RunService.Heartbeat:Connect(function()
            if not C.SHOOT_ENABLED then return end
            local now = os.clock()
            if now - C._shootLast >= C.SHOOT_INTERVAL then
                C._shootLast = now
                pcall(shootAllZombies)
            end
        end))
    end
    local function stopShootLoop()
        if C._shootConn then C._shootConn:Disconnect(); C._shootConn = nil end
    end

    local function espColors(z)
        if isBomber(z) then
            return C.ESP_BOMBER_FILL, C.ESP_BOMBER_OUTLINE
        end
        if isBoss(z) then
            return C.ESP_BOSS_FILL, C.ESP_BOSS_OUTLINE
        end
        return C.ESP_FILL_COLOR, C.ESP_OUTLINE_COLOR
    end

    local function makeNameTag(z)
        local body = z:FindFirstChild("HumanoidRootPart") or z:FindFirstChild("Torso") or z.PrimaryPart
        if not body then return nil end
        local _, outline = espColors(z)
        local bg = Instance.new("BillboardGui")
        bg.Name = "ZombieName"
        bg.Adornee = body
        bg.Size = UDim2.new(0, 120, 0, 16)
        bg.StudsOffset = Vector3.new(0, 1.2, 0)
        bg.AlwaysOnTop = true
        bg.LightInfluence = 0
        bg.ResetOnSpawn = false
        local name = Instance.new("TextLabel")
        name.Size = UDim2.new(1, 0, 1, 0)
        name.BackgroundTransparency = 1
        name.TextColor3 = outline
        name.TextStrokeTransparency = 0.3
        name.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        name.Font = Enum.Font.GothamBold
        name.TextSize = 13
        name.Text = z.Name
        name.Parent = bg
        bg.Parent = C.CoreGui
        return { gui = bg, name = name, body = body }
    end

    local function makeHighlight(z)
        local fill, outline = espColors(z)
        local h = Instance.new("Highlight")
        h.Name = "ZombieHL"
        h.FillColor = fill
        h.OutlineColor = outline
        h.FillTransparency = 0.55
        h.OutlineTransparency = 0.1
        h.Adornee = z
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = z
        return h
    end

    local function clearESP(z)
        local d = C._espData[z]
        if d then
            if d.gui then d.gui:Destroy() end
            if d.hl and d.hl.Parent then d.hl:Destroy() end
            C._espData[z] = nil
        end
    end

    local function collectZombies()
        local list = {}
        for _, e in ipairs(C.ENTITIES:GetChildren()) do
            if e.Parent and not playerOf(e) and e:IsDescendantOf(C.ENTITIES) then
                list[#list + 1] = e
            end
        end
        return list
    end

    local function refreshESP()
        for z in pairs(C._espData) do
            if not z or not z.Parent then clearESP(z) end
        end
        local ch = getChar()
        local myRoot = ch and ch:FindFirstChild("HumanoidRootPart")
        for _, z in ipairs(collectZombies()) do
            if isAlive(z) then
                local d = C._espData[z]
                if not d then
                    local tag = makeNameTag(z)
                    d = {
                        gui = tag and tag.gui,
                        name = tag and tag.name,
                        hl  = makeHighlight(z),
                    }
                    C._espData[z] = d
                end
                if myRoot and d.gui then
                    local root = z:FindFirstChild("HumanoidRootPart") or z.PrimaryPart
                    local dd = root and (root.Position - myRoot.Position).Magnitude or 0
                    local vis = dd <= C.ESP_MAX_DISTANCE
                    d.gui.Enabled = vis
                    if d.hl then d.hl.Enabled = vis end
                end
            else
                clearESP(z)
            end
        end
    end

    local function getHead(m)
        local h = m:FindFirstChild("Head")
        return (h and h:IsA("BasePart")) and h or nil
    end

    local function scanTargets()
        local ch = getChar()
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if not root then return {} end
        local out, seen = {}, {}
        for _, e in ipairs(C.ENTITIES:GetChildren()) do
            if e ~= ch and not seen[e] and isZombie(e) and isAlive(e) then
                seen[e] = true
                local head = getHead(e)
                if head then
                    local d = (head.Position - root.Position).Magnitude
                    if d <= C.ATTACK_RANGE then
                        out[#out + 1] = { entity = e, part = head, dist = d }
                    end
                end
            end
        end
        table.sort(out, function(a, b) return a.dist < b.dist end)
        local cut = {}
        for i = 1, math.min(C.MAX_TARGETS, #out) do cut[i] = out[i] end
        return cut
    end

    local function getTargets()
        local now = os.clock()
        if now - C._lastScan >= C.TARGET_SCAN_INTERVAL then
            C._cachedTargets = scanTargets()
            C._lastScan = now
        end
        return C._cachedTargets
    end

    local function attackOnce()
        C._fireCalls = C._fireCalls + 1
        local weapon = ensureMelee()
        if not weapon then C._lastFail = "无近战武器"; return false end
        C._lastGun = weapon.Name
        local targets = getTargets()
        if #targets == 0 then C._lastFail = "无目标"; return false end
        C.Event:FireServer("Windup", weapon, C.DIRECTION)
        C.Event:FireServer("Swing", weapon, C.DIRECTION, C.SWING_PARAMS)
        local hit = {}
        for _, t in ipairs(targets) do
            if t.entity.Parent and isAlive(t.entity) then
                hit[#hit + 1] = { hitPart = t.part, targetCharacter = t.entity }
            end
        end
        if #hit == 0 then C._lastFail = "目标已死"; return false end
        C.Event:FireServer("Hit", weapon, "Right", hit)
        C._lastFail = "OK"
        return true
    end

    task.spawn(function()
        while true do
            if C.running and C.KILL_ENABLED and not C.isDead then
                local ok = pcall(attackOnce)
                task.wait(ok and C.ATTACK_INTERVAL or 0.5)
            else
                task.wait(0.1)
            end
        end
    end)

    task.spawn(function()
        while true do
            task.wait(0.3)
            if C.ESP_ENABLED and not C.isDead then pcall(refreshESP) end
        end
    end)

    task.spawn(function()
        while true do
            task.wait(1)
            if not C.ESP_ENABLED then
                for z in pairs(C._espData) do clearESP(z) end
            end
        end
    end)

    local function hookDeath(c)
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if not h then return end
        track(h.Died:Connect(function() C.isDead = true end))
        track(h.HealthChanged:Connect(function(v) if v <= 0 then C.isDead = true end end))
    end

    if getChar() then hookDeath(getChar()) end
    track(C.lp.CharacterAdded:Connect(function(c)
        task.wait(0.3)
        C.isDead = false
        C._cachedMelee = nil
        C._lastScan = 0
        hookDeath(c)
        pcall(killAntiCheat)
        if C.SPEED_ENABLED then
            bindSpeedHum(humOf(c))
            applySpeed()
        end
    end))

    local MainTab = Window:AddTab("杀戮", "sword")
    local L = MainTab:AddLeftGroupbox("杀戮 / 透视", "power")
    local R = MainTab:AddRightGroupbox("参数", "sliders-horizontal")

    L:AddToggle("killFire", {
        Text = "启动杀戮", Default = false,
        Tooltip = "自动攻击范围内的僵尸",
        Callback = function(v) C.running = v; if not v then C._lastFail = "已停止" end end,
    })
    L:AddToggle("killKill", { Text = "杀戮模式", Default = true,
        Callback = function(v) C.KILL_ENABLED = v end })
    L:AddToggle("killEsp", { Text = "透视僵尸", Default = true,
        Callback = function(v)
            C.ESP_ENABLED = v
            if not v then for z in pairs(C._espData) do clearESP(z) end end
        end })
    L:AddToggle("killBomber", { Text = "忽略 Bomber", Default = true,
        Tooltip = "仅影响杀戮与透视过滤（透视仍会黄色显示）",
        Callback = function(v)
            if v then C.IGNORE_NAMES.Bomber = true else C.IGNORE_NAMES.Bomber = nil end
        end })

    local Shoot = MainTab:AddLeftGroupbox("全图枪击", "crosshair")
    Shoot:AddToggle("shootEnable", {
        Text = "启用枪击", Default = false,
        Tooltip = "自动装备枪械/喷火器并伪装 DamageBatch 发包",
        Callback = function(v)
            C.SHOOT_ENABLED = v
            if v then
                startShootLoop()
                Library:Notify("枪击：自动装备枪械/喷火器并伪装发包", 2)
            else
                stopShootLoop()
            end
        end,
    })
    Shoot:AddSlider("shootInterval", {
        Text = "枪击冷却", Default = C.SHOOT_INTERVAL,
        Min = 0.01, Max = 0.2, Rounding = 2, Suffix = " s",
        Callback = function(v) C.SHOOT_INTERVAL = v end,
    })
    Shoot:AddSlider("shootBatch", {
        Text = "单包目标数", Default = C.SHOOT_BATCH_MAX,
        Min = 1, Max = 50, Rounding = 0,
        Callback = function(v) C.SHOOT_BATCH_MAX = v end,
    })
    Shoot:AddSlider("shootRange", {
        Text = "枪击距离", Default = C.SHOOT_RANGE,
        Min = 100, Max = 1000, Rounding = 0, Suffix = " studs",
        Callback = function(v) C.SHOOT_RANGE = v end,
    })

    R:AddSlider("killRange", { Text = "杀戮范围", Default = C.ATTACK_RANGE,
        Min = 5, Max = 30, Rounding = 0, Suffix = " studs",
        Callback = function(v) C.ATTACK_RANGE = v end })
    R:AddSlider("killSpeed", { Text = "攻击间隔", Default = math.floor(C.ATTACK_INTERVAL * 100),
        Min = 1, Max = 100, Rounding = 0, Suffix = " ×0.01s",
        Callback = function(v) C.ATTACK_INTERVAL = v / 100 end })
    R:AddSlider("killMax", { Text = "单次目标数", Default = C.MAX_TARGETS,
        Min = 1, Max = 5, Rounding = 0,
        Callback = function(v) C.MAX_TARGETS = v end })
    R:AddSlider("killEspDist", { Text = "透视最大距离", Default = C.ESP_MAX_DISTANCE,
        Min = 50, Max = 1000, Rounding = 0, Suffix = " studs",
        Callback = function(v) C.ESP_MAX_DISTANCE = v end })

    local LocalTab = Window:AddTab("本地", "user")
    local PL = LocalTab:AddLeftGroupbox("玩家功能", "user")
    local PR = LocalTab:AddRightGroupbox("参数", "sliders-horizontal")

    PL:AddToggle("localSpeed", {
        Text = "移速调节", Default = false,
        Tooltip = "锁定 WalkSpeed，被改写会立刻改回",
        Callback = function(v) C.SPEED_ENABLED = v; if v then startSpeed() else stopSpeed() end end,
    })
    PL:AddToggle("localCfSpeed", {
        Text = "坐标加速", Default = false,
        Tooltip = "直接改 HumanoidRootPart 坐标位移",
        Callback = function(v) C.CF_SPEED_ENABLED = v; if v then startCoordSpeed() else stopCoordSpeed() end end,
    })
    PL:AddToggle("localStamina", {
        Text = "无限体力", Default = false,
        Tooltip = "体力在最低值与上限之间起伏，避免恒定值特征",
        Callback = function(v) C.STAMINA_ENABLED = v; if v then startStamina() else stopStamina() end end,
    })

    PR:AddSlider("localSpeedValue", {
        Text = "移速值", Default = C.SPEED_VALUE,
        Min = 1, Max = 50, Rounding = 0, Suffix = " ws",
        Callback = function(v) C.SPEED_VALUE = v; if C.SPEED_ENABLED then applySpeed() end end,
    })
    PR:AddSlider("localCfValue", {
        Text = "坐标加速倍率", Default = C.CF_SPEED_VALUE,
        Min = 0.1, Max = 3, Rounding = 1, Suffix = " ×",
        Callback = function(v) C.CF_SPEED_VALUE = v end,
    })
    PR:AddSlider("localStaminaMax", {
        Text = "体力上限", Default = C.STAMINA_MAX,
        Min = 1, Max = 500, Rounding = 0,
        Callback = function(v) C.STAMINA_MAX = v end,
    })
    PR:AddSlider("localStaminaMin", {
        Text = "体力最低值", Default = C.STAMINA_MIN,
        Min = 1, Max = 500, Rounding = 0,
        Callback = function(v) C.STAMINA_MIN = v end,
    })
    PR:AddSlider("localStaminaFreq", {
        Text = "体力起伏速度", Default = C._stamFreq,
        Min = 0.1, Max = 3, Rounding = 1, Suffix = " Hz",
        Callback = function(v) C._stamFreq = v end,
    })

    local FunTab = Window:AddTab("娱乐", "gamepad-2")
    local FL = FunTab:AddLeftGroupbox("转圈", "rotate-cw")
    local FR = FunTab:AddRightGroupbox("参数", "sliders-horizontal")

    FL:AddToggle("funSpin", {
        Text = "角色转圈", Default = false,
        Tooltip = "纯本地表现，只旋转朝向，不改移速/跳跃",
        Callback = function(v) C.SPIN_ENABLED = v; if v then startSpin() else stopSpin() end end,
    })
    FL:AddButton({
        Text = "切换方向",
        Func = function()
            C.SPIN_DIR = -C.SPIN_DIR
            Library:Notify(C.SPIN_DIR == 1 and "方向：正转" or "方向：反转", 2)
        end,
    })
    FR:AddSlider("funSpinSpeed", {
        Text = "转速", Default = C.SPIN_SPEED,
        Min = 250, Max = 1000, Rounding = 0, Suffix = " °/s",
        Callback = function(v) C.SPIN_SPEED = v end,
    })

    local MiscTab = Window:AddTab("杂项", "settings")
    local MR = MiscTab:AddLeftGroupbox("操作", "wrench")

    MR:AddButton({
        Text = "立即重扫",
        Func = function() C._lastScan = 0; Library:Notify("已请求重新扫描", 3) end,
    })
    MR:AddButton({
        Text = "清反作弊/体力连接",
        Func = function()
            pcall(killAntiCheat)
            Library:Notify("已尝试断开反作弊/体力相关连接", 3)
        end,
    })
    MR:AddButton({
        Text = "恢复默认",
        Func = function()
            local O = Library.Options
            if O.killFire      then O.killFire:SetValue(false) end
            if O.killKill      then O.killKill:SetValue(true) end
            if O.killEsp       then O.killEsp:SetValue(true) end
            if O.killBomber    then O.killBomber:SetValue(true) end
            if O.killRange     then O.killRange:SetValue(30) end
            if O.killSpeed     then O.killSpeed:SetValue(12) end
            if O.killMax       then O.killMax:SetValue(3) end
            if O.killEspDist   then O.killEspDist:SetValue(500) end
            if O.shootEnable   then O.shootEnable:SetValue(false) end
            if O.shootInterval then O.shootInterval:SetValue(0.2) end
            if O.shootBatch    then O.shootBatch:SetValue(50) end
            if O.shootRange    then O.shootRange:SetValue(500) end
            if O.localSpeed       then O.localSpeed:SetValue(false) end
            if O.localCfSpeed     then O.localCfSpeed:SetValue(false) end
            if O.localStamina     then O.localStamina:SetValue(false) end
            if O.localSpeedValue  then O.localSpeedValue:SetValue(16) end
            if O.localCfValue     then O.localCfValue:SetValue(1.5) end
            if O.localStaminaMax  then O.localStaminaMax:SetValue(100) end
            if O.localStaminaMin  then O.localStaminaMin:SetValue(10) end
            if O.localStaminaFreq then O.localStaminaFreq:SetValue(0.8) end
            if O.funSpin          then O.funSpin:SetValue(false) end
            if O.funSpinSpeed     then O.funSpinSpeed:SetValue(250) end
            Library:Notify("已恢复默认设置", 3)
        end,
    })
end
