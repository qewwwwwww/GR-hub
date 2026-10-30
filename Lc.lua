return function(Library, Window)
    local RunService = game:GetService("RunService")
    local UserInput = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local Players = game:GetService("Players")
    local Replicated = game:GetService("ReplicatedStorage")
    local TweenService = game:GetService("TweenService")

    local lp = Players.LocalPlayer

    local LOG_ENABLED = false
    local FX_ENABLED  = false
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
    local CollectionService = game:GetService("CollectionService")
    local TAG_DYN = "fx_DynamicHumanoid"

    local NPC_ROOT
    pcall(function()
        if workspace.MapContainer and workspace.MapContainer.Special then
            NPC_ROOT = workspace.MapContainer.Special:FindFirstChild("NPC_Container")
        end
    end)

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

    local requestScan = nil
    local ecoOn = false

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
        Callback = function(v) ATTACK_BOTS = v end,
    })

    aL:AddToggle("swPlr", {
        Text = "攻击玩家",
        Default = false,
        Callback = function(v) ATTACK_PLAYERS = v end,
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
        Default = true,
        Callback = function(v)
            RAY_ENABLED = v
            _losCache = setmetatable({}, { __mode = "k" })
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
        Default = true,
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
        Default = PIERCE_ENABLED,
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
            if O.swRay then O.swRay:SetValue(true) end
            if O.swFallback then O.swFallback:SetValue(true) end
            if O.swPierce then O.swPierce:SetValue(true) end
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

    local function isNPC(c)
        if not c then return false end
        local cached = _isNpc[c]
        if cached ~= nil then return cached end
        if playerOf(c) then _isNpc[c] = false; return false end
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
        if ok and type(v) == "string" then return v end
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
        if workspace:GetAttribute("Round_Truce") then
            if isPVERound() and not playerOf(c) then return true end
            return false
        end
        if workspace:GetAttribute("Round_FriendlyFire") then return true end
        local myTeam = myPlayer.Team
        local p = playerOf(c)
        if p then
            return myTeam ~= p.Team
        end
        local t = teamAttrOf(c)
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
        if PlayerUtility and type(PlayerUtility.AreEnemies) == "function" then
            local other = playerOf(c) or c
            local ok, r = pcall(function() return PlayerUtility:AreEnemies(lp, other) end)
            if ok and type(r) == "boolean" then res = r end
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
        if TEAM_CHECK and not isEnemyChar(c) then return false end
        if c:GetAttribute("Immortal") then return false end
        if c:GetAttribute("epoch") then return false end
        if playerOf(c) then return ATTACK_PLAYERS end
        return isNPC(c) and ATTACK_BOTS
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

    local Debris = game:GetService("Debris")
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

    local _lockTw = setmetatable({}, { __mode = "k" })
    local function startLockSpin(bg)
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

    local function stopLockSpin(bg)
        local tws = _lockTw[bg]
        if not tws then return end
        for _, tw in ipairs(tws) do pcall(tw.Cancel, tw) end
        _lockTw[bg] = nil
    end

    local LOCK_APPEAR_TIME = 0.12
    local LOCK_APPEAR_SCALE = 1.8
    local LOCK_BURST_TIME = 0.35
    local LOCK_BURST_SCALE = 2.2

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

    local lockUI = {}
    local lockReady = {}
    local _deathConn = setmetatable({}, { __mode = "k" })

    updateLockUIMaxDistance = function()
        for _, ui in pairs(lockUI) do
            pcall(function() ui.MaxDistance = MAX_DIST + 100 end)
        end
    end

    local function updateLockUISize()
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

    local _losCache = setmetatable({}, { __mode = "k" })
    local _aimPick = setmetatable({}, { __mode = "k" })

    local function showLockUI(t)
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

    local function hideLockUI(t, burst)
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

    local function clearAllLockUI()
        for t, _ in pairs(lockUI) do hideLockUI(t) end
        table.clear(_losCache)
    end

    local function setLockState(t, ready)
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

    local BOOT_OK, BOOT_ERR = pcall(function()
        local ClientCursor = nil
        local PlayerUtility = nil
        local QuickCreate = nil
        local CrossPlatformMethods = nil
        local ClientUtilities = nil
        local SharedModuleFunctions = nil

        local ok, mod = pcall(function() return require(Replicated.MODULES.ClientCursor) end)
        if ok and mod then ClientCursor = mod end

        ok, mod = pcall(function() return require(Replicated.MODULES.PlayerUtility) end)
        if ok and mod then PlayerUtility = mod end

        ok, mod = pcall(function() return require(Replicated.MODULES.QuickCreate) end)
        if ok and mod then QuickCreate = mod end

        ensureTeams()

        ok, mod = pcall(function() return require(Replicated.MODULES.CrossPlatformMethods) end)
        if ok and mod then CrossPlatformMethods = mod end

        ok, mod = pcall(function() return require(Replicated.MODULES.ClientUtilities) end)
        if ok and mod then ClientUtilities = mod end

        local ProjectileUtility = nil
        ok, mod = pcall(function() return require(Replicated.MODULES.ProjectileUtility) end)
        if ok and mod then ProjectileUtility = mod end

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

        local ActiveCast = nil
        local ActiveCastPath = nil
        do
            local paths = {
                "MODULES.ProjectileUtility.ActiveCast",
                "MODULES.ActiveCast",
                "MODULES.FastCast",
                "MODULES.ToolModule.ActiveCast"
            }
            for _, path in ipairs(paths) do
                local node = Replicated
                local okwalk = true
                for seg in string.gmatch(path, "[^%.]+") do
                    node = node and node:FindFirstChild(seg)
                    if not node then okwalk = false; break end
                end
                if okwalk and node then
                    local okR, m = pcall(function() return require(node) end)
                    if okR and m ~= nil then ActiveCast, ActiveCastPath = m, path; break end
                end
            end
        end

        local ClientPlayerWrapper = nil
        ok, mod = pcall(function() return require(Replicated.MODULES.ClientPlayerWrapper) end)
        if ok and mod then ClientPlayerWrapper = mod end

        local _filterCache = nil
        local _filterCacheVersion = 0
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
            _filterCacheVersion = _filterCacheVersion + 1
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

        local _LOS_CACHE_TTL = 0.05
        local _LOS_CACHE_TTL_BLOCKED = 0.06
        local _LOS_CACHE_THRESH = 2
        local _losSource = "-"
        local _rayCount = 0
        local _rayCountShown = 0

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
            if not speed or spee
