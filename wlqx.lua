return function(Library, Window, GHub)
    local C = {}
    C.genv = (type(getgenv) == "function") and getgenv() or _G
    GHub = GHub or C.genv.GRHub

    C.RunService   = game:GetService("RunService")
    C.UserInput    = game:GetService("UserInputService")
    C.Workspace    = game:GetService("Workspace")
    C.Players      = game:GetService("Players")
    C.Replicated   = game:GetService("ReplicatedStorage")
    C.CoreGui      = game:GetService("CoreGui")

    C.lp = C.Players.LocalPlayer
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
    C.ESP_MAX_DISTANCE  = 500

    C.FIRE_ENABLED    = false
    C.FIRE_INTERVAL   = 0.4
    C.FIRE_BATCH_MAX  = 8
    C.FIRE_RANGE      = 500
    C._fireConn       = nil
    C._fireLast       = 0

    C.SHOOT_ENABLED   = false
    C.SHOOT_INTERVAL  = 0.3
    C.SHOOT_BATCH_MAX = 8
    C.SHOOT_RANGE     = 500
    C._shootConn      = nil
    C._shootLast      = 0
    C._shootTool      = nil

    C.STAMINA_ENABLED = false
    C.STAMINA_MAX     = 100
    C._staminaConn    = nil

    C.SPEED_ENABLED   = false
    C.SPEED_VALUE     = 16
    C._speedConn      = nil
    C._speedConn2     = nil
    C._speedConn3     = nil
    C._speedHum       = nil

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

    local function getChar() return C.lp.Character end
    local function humOf(m) return m and m:FindFirstChildWhichIsA("Humanoid") end
    local function isIgnored(m) return C.IGNORE_NAMES[m.Name] == true end
    local function playerOf(m) return C.Players:GetPlayerFromCharacter(m) end

    local function isZombie(m)
        if not m or not m.Parent then return false end
        if isIgnored(m) then return false end
        if playerOf(m) then return false end
        return m:IsDescendantOf(C.ENTITIES)
    end

    local function isFireTarget(m)
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

    local function startStamina()
        if C._staminaConn then C._staminaConn:Disconnect() end
        C._staminaConn = C.RunService.Heartbeat:Connect(function()
            local char = C.lp.Character
            if not char then return end
            local MAX = C.STAMINA_MAX
            if char:GetAttribute("stamina") ~= MAX then
                char:SetAttribute("stamina", MAX)
            end
            if char:GetAttribute("maxStamina") ~= MAX then
                char:SetAttribute("maxStamina", MAX)
            end
        end)
    end

    local function stopStamina()
        if C._staminaConn then C._staminaConn:Disconnect(); C._staminaConn = nil end
    end

    local function applySpeed()
        local char = C.lp.Character
        local h = char and char:FindFirstChildOfClass("Humanoid")
        if not h then return end
        if h.WalkSpeed ~= C.SPEED_VALUE then
            h.WalkSpeed = C.SPEED_VALUE
        end
        if char:GetAttribute("WalkSpeed") ~= C.SPEED_VALUE then
            pcall(function() char:SetAttribute("WalkSpeed", C.SPEED_VALUE) end)
        end
    end

    local function bindSpeedHum(h)
        if not h then return end
        if C._speedHum == h then return end
        if C._speedConn2 then C._speedConn2:Disconnect(); C._speedConn2 = nil end
        C._speedHum = h
        C._speedConn2 = h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if not C.SPEED_ENABLED then return end
            if h.WalkSpeed ~= C.SPEED_VALUE then
                h.WalkSpeed = C.SPEED_VALUE
            end
        end)
    end

    local function startSpeed()
        if C._speedConn then C._speedConn:Disconnect() end
        if C._speedConn3 then C._speedConn3:Disconnect(); C._speedConn3 = nil end

        applySpeed()
        bindSpeedHum(humOf(C.lp.Character))

        C._speedConn = C.RunService.Heartbeat:Connect(function()
            if not C.SPEED_ENABLED then return end
            applySpeed()
        end)

        C._speedConn3 = C.RunService.RenderStepped:Connect(function()
            if not C.SPEED_ENABLED then return end
            applySpeed()
        end)

        local char = C.lp.Character
        if char then bindSpeedHum(humOf(char)) end
    end

    local function stopSpeed()
        if C._speedConn then C._speedConn:Disconnect(); C._speedConn = nil end
        if C._speedConn2 then C._speedConn2:Disconnect(); C._speedConn2 = nil end
        if C._speedConn3 then C._speedConn3:Disconnect(); C._speedConn3 = nil end
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
        C._cfConn = C.RunService.Heartbeat:Connect(function(dt)
            local char = C.lp.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then return end
            local dir = getMoveVector()
            if dir.Magnitude < 0.01 then return end
            local step = C.CF_SPEED_VALUE * 60 * dt
            root.CFrame = root.CFrame + dir.Unit * step
        end)
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
        C._spinConn = C.RunService.Heartbeat:Connect(function(dt) spinStep(dt, true) end)
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

    local function findFlamethrower()
        local char = getChar()
        if char then
            for _, t in ipairs(char:GetChildren()) do
                if t:IsA("Tool") and t.Name == "Flamethrower" then return t end
            end
        end
        local bp = C.lp:FindFirstChild("Backpack")
        if bp then
            for _, t in ipairs(bp:GetChildren()) do
                if t:IsA("Tool") and t.Name == "Flamethrower" then return t end
            end
        end
        return nil
    end

    local function equipFlamethrower()
        local tool = findFlamethrower()
        if not tool then return nil end
        wearTool(tool)
        return tool
    end

    local function isGunTool(t)
        if not t or not t:IsA("Tool") then return false end
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

    local function fireAllZombies()
        local weapon = equipFlamethrower()
        if not weapon then return end

        local myRoot = getChar() and getChar():FindFirstChild("HumanoidRootPart")
        local origin = myRoot and myRoot.Position or Vector3.zero

        local zombies = {}
        for _, e in ipairs(C.ENTITIES:GetChildren()) do
            if isFireTarget(e) and isAlive(e) then
                local hitPart = e:FindFirstChild("Torso") or e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart
                if hitPart then
                    local dist = (hitPart.Position - origin).Magnitude
                    if dist <= C.FIRE_RANGE then
                        zombies[#zombies + 1] = { entity = e, part = hitPart, dist = dist }
                    end
                end
            end
        end
        if #zombies == 0 then return end

        table.sort(zombies, function(a, b) return a.dist < b.dist end)

        local batch = {}
        for i = 1, math.min(C.FIRE_BATCH_MAX, #zombies) do
            local z = zombies[i]
            local dir = (z.part.Position - origin).Unit
            batch[#batch + 1] = {
                hitArmor = false,
                direction = dir,
                penetrationCount = 1,
                projectile = fakeProjectile(),
                result = {
                    Normal = -dir,
                    Position = z.part.Position,
                    Instance = z.part,
                    Material = Enum.Material.Plastic,
                    Distance = z.dist
                },
                target = z.entity
            }
        end

        if #batch > 0 then
            pcall(function()
                C.GunSys:FireServer("DamageBatch", weapon, batch)
            end)
        end
    end

    local function startFireLoop()
        if C._fireConn then return end
        C._fireConn = C.RunService.Heartbeat:Connect(function()
            if not C.FIRE_ENABLED then return end
            local now = os.clock()
            if now - C._fireLast >= C.FIRE_INTERVAL then
                C._fireLast = now
                pcall(fireAllZombies)
            end
        end)
    end

    local function stopFireLoop()
        if C._fireConn then C._fireConn:Disconnect(); C._fireConn = nil end
    end

    local function shootAllZombies()
        local weapon = equipGun()
        if not weapon then return end

        local myRoot = getChar() and getChar():FindFirstChild("HumanoidRootPart")
        local origin = myRoot and myRoot.Position or Vector3.zero

        local zombies = {}
        for _, e in ipairs(C.ENTITIES:GetChildren()) do
            if isFireTarget(e) and isAlive(e) then
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
            pcall(function()
                C.GunSys:FireServer("DamageBatch", weapon, batch)
            end)
        end
    end

    local function startShootLoop()
        if C._shootConn then return end
        C._shootConn = C.RunService.Heartbeat:Connect(function()
            if not C.SHOOT_ENABLED then return end
            local now = os.clock()
            if now - C._shootLast >= C.SHOOT_INTERVAL then
                C._shootLast = now
                pcall(shootAllZombies)
            end
        end)
    end

    local function stopShootLoop()
        if C._shootConn then C._shootConn:Disconnect(); C._shootConn = nil end
    end

    local function makeNameTag(z)
        local body = z:FindFirstChild("HumanoidRootPart") or z:FindFirstChild("Torso") or z.PrimaryPart
        if not body then return nil end
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
        name.TextColor3 = Color3.fromRGB(0, 255, 100)
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
        local h = Instance.new("Highlight")
        h.Name = "ZombieHL"
        h.FillColor = C.ESP_FILL_COLOR
        h.OutlineColor = C.ESP_OUTLINE_COLOR
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
            if isZombie(e) then list[#list + 1] = e end
        end
        return list
    end

    local function refreshESP()
        for z in pairs(C._espData) do
            if not z or not z.Parent or not isZombie(z) then clearESP(z) end
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
            task.wait(0.2)
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
        h.Died:Connect(function() C.isDead = true end)
        h.HealthChanged:Connect(function(v) if v <= 0 then C.isDead = true end end)
    end
    if getChar() then hookDeath(getChar()) end
    C.lp.CharacterAdded:Connect(function(c)
        task.wait(0.3)
        C.isDead = false
        C._cachedMelee = nil
        C._lastScan = 0
        hookDeath(c)
        if C.SPEED_ENABLED then
            bindSpeedHum(humOf(c))
            applySpeed()
        end
    end)

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
        Callback = function(v)
            if v then C.IGNORE_NAMES.Bomber = true else C.IGNORE_NAMES.Bomber = nil end
        end })

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

    local Fire = MainTab:AddRightGroupbox("全图火烧", "flame")
    Fire:AddToggle("fireEnable", {
        Text = "启用火烧",
        Default = false,
        Tooltip = "自动装备喷火器并伪装 DamageBatch 发包",
        Callback = function(v)
            C.FIRE_ENABLED = v
            if v then
                startFireLoop()
                Library:Notify("火烧：自动装备喷火器并伪装发包", 2)
            else
                stopFireLoop()
            end
        end,
    })
    Fire:AddSlider("fireInterval", {
        Text = "火烧冷却",
        Default = C.FIRE_INTERVAL,
        Min = 0.2, Max = 3, Rounding = 2, Suffix = " s",
        Callback = function(v) C.FIRE_INTERVAL = v end,
    })
    Fire:AddSlider("fireBatch", {
        Text = "单包目标数",
        Default = C.FIRE_BATCH_MAX,
        Min = 1, Max = 20, Rounding = 0,
        Callback = function(v) C.FIRE_BATCH_MAX = v end,
    })
    Fire:AddSlider("fireRange", {
        Text = "火烧距离",
        Default = C.FIRE_RANGE,
        Min = 100, Max = 1000, Rounding = 0, Suffix = " studs",
        Callback = function(v) C.FIRE_RANGE = v end,
    })

    local Shoot = MainTab:AddRightGroupbox("全图枪击", "crosshair")
    Shoot:AddToggle("shootEnable", {
        Text = "启用枪击",
        Default = false,
        Tooltip = "自动装备枪械并伪装 DamageBatch 发包",
        Callback = function(v)
            C.SHOOT_ENABLED = v
            if v then
                startShootLoop()
                Library:Notify("枪击：自动装备枪械并伪装发包", 2)
            else
                stopShootLoop()
            end
        end,
    })
    Shoot:AddSlider("shootInterval", {
        Text = "枪击冷却",
        Default = C.SHOOT_INTERVAL,
        Min = 0.1, Max = 3, Rounding = 2, Suffix = " s",
        Callback = function(v) C.SHOOT_INTERVAL = v end,
    })
    Shoot:AddSlider("shootBatch", {
        Text = "单包目标数",
        Default = C.SHOOT_BATCH_MAX,
        Min = 1, Max = 20, Rounding = 0,
        Callback = function(v) C.SHOOT_BATCH_MAX = v end,
    })
    Shoot:AddSlider("shootRange", {
        Text = "枪击距离",
        Default = C.SHOOT_RANGE,
        Min = 100, Max = 1000, Rounding = 0, Suffix = " studs",
        Callback = function(v) C.SHOOT_RANGE = v end,
    })

    local LocalTab = Window:AddTab("本地", "user")
    local PL = LocalTab:AddLeftGroupbox("玩家功能", "user")
    local PR = LocalTab:AddRightGroupbox("参数", "sliders-horizontal")

    PL:AddToggle("localSpeed", {
        Text = "移速调节",
        Default = false,
        Tooltip = "锁定 WalkSpeed，被改写会立刻改回",
        Callback = function(v)
            C.SPEED_ENABLED = v
            if v then startSpeed() else stopSpeed() end
        end,
    })
    PL:AddToggle("localCfSpeed", {
        Text = "坐标加速",
        Default = false,
        Tooltip = "直接改 HumanoidRootPart 坐标位移",
        Callback = function(v)
            C.CF_SPEED_ENABLED = v
            if v then startCoordSpeed() else stopCoordSpeed() end
        end,
    })
    PL:AddToggle("localStamina", {
        Text = "无限体力",
        Default = false,
        Tooltip = "仅本地锁 stamina / maxStamina 属性",
        Callback = function(v)
            C.STAMINA_ENABLED = v
            if v then startStamina() else stopStamina() end
        end,
    })

    PR:AddSlider("localSpeedValue", {
        Text = "移速值",
        Default = C.SPEED_VALUE,
        Min = 1, Max = 50, Rounding = 0, Suffix = " ws",
        Callback = function(v)
            C.SPEED_VALUE = v
            if C.SPEED_ENABLED then applySpeed() end
        end,
    })
    PR:AddSlider("localCfValue", {
        Text = "坐标加速倍率",
        Default = C.CF_SPEED_VALUE,
        Min = 0.1, Max = 10, Rounding = 1, Suffix = " ×",
        Callback = function(v) C.CF_SPEED_VALUE = v end,
    })
    PR:AddSlider("localStaminaMax", {
        Text = "体力上限",
        Default = C.STAMINA_MAX,
        Min = 1, Max = 500, Rounding = 0,
        Callback = function(v) C.STAMINA_MAX = v end,
    })

    local FunTab = Window:AddTab("娱乐", "gamepad-2")
    local FL = FunTab:AddLeftGroupbox("转圈", "rotate-cw")
    local FR = FunTab:AddRightGroupbox("参数", "sliders-horizontal")

    FL:AddToggle("funSpin", {
        Text = "角色转圈",
        Default = false,
        Tooltip = "纯本地表现，只旋转朝向，不改移速/跳跃",
        Callback = function(v)
            C.SPIN_ENABLED = v
            if v then startSpin() else stopSpin() end
        end,
    })
    FL:AddButton({
        Text = "切换方向",
        Func = function()
            C.SPIN_DIR = -C.SPIN_DIR
            Library:Notify(C.SPIN_DIR == 1 and "方向：正转" or "方向：反转", 2)
        end,
    })

    FR:AddSlider("funSpinSpeed", {
        Text = "转速",
        Default = C.SPIN_SPEED,
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
            if O.fireEnable    then O.fireEnable:SetValue(false) end
            if O.fireInterval  then O.fireInterval:SetValue(0.4) end
            if O.fireBatch     then O.fireBatch:SetValue(8) end
            if O.fireRange     then O.fireRange:SetValue(500) end
            if O.shootEnable   then O.shootEnable:SetValue(false) end
            if O.shootInterval then O.shootInterval:SetValue(0.3) end
            if O.shootBatch    then O.shootBatch:SetValue(8) end
            if O.shootRange    then O.shootRange:SetValue(500) end
            if O.localSpeed       then O.localSpeed:SetValue(false) end
            if O.localCfSpeed     then O.localCfSpeed:SetValue(false) end
            if O.localStamina     then O.localStamina:SetValue(false) end
            if O.localSpeedValue  then O.localSpeedValue:SetValue(16) end
            if O.localCfValue     then O.localCfValue:SetValue(1.5) end
            if O.localStaminaMax  then O.localStaminaMax:SetValue(100) end
            if O.funSpin          then O.funSpin:SetValue(false) end
            if O.funSpinSpeed     then O.funSpinSpeed:SetValue(250) end
            Library:Notify("已恢复默认", 3)
        end,
    })

    C.UserInput.InputBegan:Connect(function(i, g)
        if g then return end
        if i.KeyCode == Enum.KeyCode.P then
            C.running = not C.running
            if Library.Options.killFire then Library.Options.killFire:SetValue(C.running) end
        elseif i.KeyCode == Enum.KeyCode.L then
            C.ESP_ENABLED = not C.ESP_ENABLED
            if Library.Options.killEsp then Library.Options.killEsp:SetValue(C.ESP_ENABLED) end
        elseif i.KeyCode == Enum.KeyCode.K then
            C.STAMINA_ENABLED = not C.STAMINA_ENABLED
            if Library.Options.localStamina then
                Library.Options.localStamina:SetValue(C.STAMINA_ENABLED)
            end
        end
    end)

    Library:Notify("杀戮 / 透视 / 火烧 / 枪击 / 本地玩家 / 娱乐模块已加载", 3)

    local function unload()
        C.running = false
        stopStamina(); stopSpeed(); stopCoordSpeed(); stopSpin(); stopFireLoop(); stopShootLoop()
        for z in pairs(C._espData) do clearESP(z) end
    end

    if GHub and GHub.RegisterModule then
        GHub.RegisterModule("僵尸杀戮", {
            Name = "僵尸杀戮",
            MainTab = MainTab, MiscTab = MiscTab, LocalTab = LocalTab, FunTab = FunTab,
            Options = Library.Options, Unload = unload,
        })
    end

    return {
        Name = "僵尸杀戮",
        MainTab = MainTab, MiscTab = MiscTab, LocalTab = LocalTab, FunTab = FunTab,
        Options = Library.Options, Unload = unload,
    }
end
