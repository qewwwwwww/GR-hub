return function(Library, Window, GHub)
    local C = {}
    C.genv = (type(getgenv) == "function") and getgenv() or _G
    GHub = GHub or C.genv.GRHub

    C.RunService   = game:GetService("RunService")
    C.UserInput    = game:GetService("UserInputService")
    C.Workspace    = game:GetService("Workspace")
    C.Players      = game:GetService("Players")
    C.Replicated   = game:GetService("ReplicatedStorage")
    C.TweenService = game:GetService("TweenService")

    C.lp = C.Players.LocalPlayer
    C.Event = C.Replicated:WaitForChild("Events"):WaitForChild("MeleeSystem")
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
    C.ESP_FILL_COLOR    = Color3.fromRGB(255, 60, 60)
    C.ESP_OUTLINE_COLOR = Color3.fromRGB(255, 200, 60)
    C.ESP_MAX_DISTANCE  = 500

    C.STAMINA_ENABLED = false
    C.STAMINA_MAX     = 100
    C._staminaConn    = nil

    C.SPEED_ENABLED   = false
    C.SPEED_VALUE     = 16
    C._speedConn      = nil

    C.CF_SPEED_ENABLED = false
    C.CF_SPEED_VALUE   = 1.5
    C._cfConn          = nil

    C.SPIN_ENABLED    = false
    C.SPIN_SPEED      = 180
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

    local function isAlive(m)
        local h = humOf(m)
        return h ~= nil and h.Health > 0
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

    local function startSpeed()
        if C._speedConn then C._speedConn:Disconnect() end
        C._speedConn = C.RunService.Heartbeat:Connect(function()
            local char = C.lp.Character
            local h = char and char:FindFirstChildOfClass("Humanoid")
            if not h then return end
            if h.WalkSpeed ~= C.SPEED_VALUE then
                h.WalkSpeed = C.SPEED_VALUE
            end
        end)
    end

    local function stopSpeed()
        if C._speedConn then C._speedConn:Disconnect(); C._speedConn = nil end
        local char = C.lp.Character
        local h = char and char:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = 16 end
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
                if isMeleeTool(t) then C._cachedMelee = t; return t end
            end
        end
        local bp = C.lp:FindFirstChild("Backpack")
        if bp then
            for _, t in ipairs(bp:GetChildren()) do
                if isMeleeTool(t) then
                    local h = ch and humOf(ch)
                    if h then pcall(function() h:EquipTool(t) end) end
                    task.wait()
                    C._cachedMelee = t
                    return t
                end
            end
        end
        C._cachedMelee = nil
        return nil
    end

    local function makeLabel(z)
        local root = z:FindFirstChild("HumanoidRootPart") or z.PrimaryPart
        if not root then return nil end
        local bg = Instance.new("BillboardGui")
        bg.Name = "ZombieTag"
        bg.Adornee = root
        bg.Size = UDim2.new(0, 140, 0, 40)
        bg.StudsOffset = Vector3.new(0, 2.6, 0)
        bg.AlwaysOnTop = true
        bg.LightInfluence = 0
        bg.ResetOnSpawn = false

        local fr = Instance.new("Frame")
        fr.Size = UDim2.new(1, 0, 1, 0)
        fr.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        fr.BackgroundTransparency = 0.45
        fr.BorderSizePixel = 0
        fr.Parent = bg
        Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 4)

        local name = Instance.new("TextLabel")
        name.Size = UDim2.new(1, -4, 0, 16)
        name.Position = UDim2.new(0, 2, 0, 2)
        name.BackgroundTransparency = 1
        name.TextColor3 = Color3.fromRGB(255, 120, 120)
        name.Font = Enum.Font.GothamBold
        name.TextSize = 12
        name.Text = z.Name
        name.Parent = fr

        local dist = Instance.new("TextLabel")
        dist.Size = UDim2.new(1, -4, 0, 14)
        dist.Position = UDim2.new(0, 2, 0, 18)
        dist.BackgroundTransparency = 1
        dist.TextColor3 = Color3.fromRGB(200, 200, 200)
        dist.Font = Enum.Font.Gotham
        dist.TextSize = 10
        dist.Text = "0 studs"
        dist.Parent = fr

        bg.Parent = game:GetService("CoreGui")
        return { gui = bg, name = name, dist = dist, root = root }
    end

    local function makeHighlight(z)
        local h = Instance.new("Highlight")
        h.Name = "ZombieHL"
        h.FillColor = C.ESP_FILL_COLOR
        h.OutlineColor = C.ESP_OUTLINE_COLOR
        h.FillTransparency = 0.6
        h.OutlineTransparency = 0.15
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
                    local tag = makeLabel(z)
                    d = {
                        gui  = tag and tag.gui,
                        name = tag and tag.name,
                        dist = tag and tag.dist,
                        root = tag and tag.root,
                        hl   = makeHighlight(z),
                    }
                    C._espData[z] = d
                end
                if d.dist and d.root and myRoot then
                    local dd = (d.root.Position - myRoot.Position).Magnitude
                    d.dist.Text = string.format("%.0f studs", dd)
                    local vis = dd <= C.ESP_MAX_DISTANCE
                    if d.gui then d.gui.Enabled = vis end
                    if d.hl  then d.hl.Enabled  = vis end
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
        Min = 5, Max = 100, Rounding = 0, Suffix = " studs",
        Callback = function(v) C.ATTACK_RANGE = v end })
    R:AddSlider("killSpeed", { Text = "攻击间隔", Default = math.floor(C.ATTACK_INTERVAL * 100),
        Min = 5, Max = 100, Rounding = 0, Suffix = " ×0.01s",
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
        Text = "移速调节",
        Default = false,
        Tooltip = "循环锁定 WalkSpeed，防止被顶掉",
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
        Callback = function(v) C.SPEED_VALUE = v end,
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
        Min = 1, Max = 250, Rounding = 0, Suffix = " °/s",
        Callback = function(v) C.SPIN_SPEED = v end,
    })

    local MiscTab = Window:AddTab("杂项", "settings")
    local ML = MiscTab:AddLeftGroupbox("状态", "activity")
    local MR = MiscTab:AddRightGroupbox("操作", "wrench")
    local diag = ML:AddLabel("等待数据...")

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
            if O.localSpeed       then O.localSpeed:SetValue(false) end
            if O.localCfSpeed     then O.localCfSpeed:SetValue(false) end
            if O.localStamina     then O.localStamina:SetValue(false) end
            if O.localSpeedValue  then O.localSpeedValue:SetValue(16) end
            if O.localCfValue     then O.localCfValue:SetValue(1.5) end
            if O.localStaminaMax  then O.localStaminaMax:SetValue(100) end
            if O.funSpin          then O.funSpin:SetValue(false) end
            if O.funSpinSpeed     then O.funSpinSpeed:SetValue(180) end
            Library:Notify("已恢复默认", 3)
        end,
    })

    task.spawn(function()
        while true do
            task.wait(0.5)
            pcall(function()
                local n = 0
                for _, e in ipairs(C.ENTITIES:GetChildren()) do
                    if isZombie(e) then n = n + 1 end
                end
                diag:SetText(string.format(
                    "杀戮:%s | 透视:%s | 死亡:%s\n移速:%s(%d) | 坐标加速:%s(%.1f×) | 体力:%s(%d)\n转圈:%s(%d°/s) | 武器:%s | 僵尸:%d | 锁定:%d\n范围:%d | 间隔:%.2fs | 开火:%d | 最后:%s",
                    C.running and "运行" or "待机",
                    C.ESP_ENABLED and "开" or "关",
                    C.isDead and "是" or "否",
                    C.SPEED_ENABLED and "开" or "关", C.SPEED_VALUE,
                    C.CF_SPEED_ENABLED and "开" or "关", C.CF_SPEED_VALUE,
                    C.STAMINA_ENABLED and "开" or "关", C.STAMINA_MAX,
                    C.SPIN_ENABLED and "开" or "关", C.SPIN_SPEED,
                    C._lastGun, n, #C._cachedTargets,
                    C.ATTACK_RANGE, C.ATTACK_INTERVAL, C._fireCalls, C._lastFail
                ))
            end)
        end
    end)

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

    Library:Notify("杀戮 / 透视 / 本地玩家 / 娱乐模块已加载", 3)

    local function unload()
        C.running = false
        stopStamina(); stopSpeed(); stopCoordSpeed(); stopSpin()
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
