--[[ AWSD 纯娱乐 · 全屏启动动画 → 超大😂旋转跳动 ]]
local CFG = {
    EMOJI       = "😂",              -- 显示成方块就换成任意字或图片
    FOOTER      = "纯娱乐  awsd制作",
    BOOT_TIME   = 3.0,              -- 启动动画总时长(秒)
    SPIN_SPEED  = 80,               -- 旋转 度/秒
    JUMP_SPEED  = 5.2,              -- 弹跳频率
    JUMP_AMP    = 0.085,            -- 弹跳幅度(屏高比例)
    ACCENT      = Color3.fromRGB(90, 240, 255),
}

local Players   = game:GetService("Players")
local RunService= game:GetService("RunService")
local Tween     = game:GetService("TweenService")
local LP        = Players.LocalPlayer
local Cam       = workspace.CurrentCamera

local parent
if type(gethui) == "function" then
    parent = gethui()
else
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    parent = ok and cg or LP:WaitForChild("PlayerGui")
end

local gui = Instance.new("ScreenGui")
gui.Name = "AWSD_Entertainment"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2147483647
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parent

-- 全屏纯黑：盖住摄像机画面
local black = Instance.new("Frame", gui)
black.Size = UDim2.fromScale(1, 1)
black.Position = UDim2.fromScale(0, 0)
black.BackgroundColor3 = Color3.new(0, 0, 0)
black.BackgroundTransparency = 0
black.BorderSizePixel = 0
black.ZIndex = 1

-- 启动层（CanvasGroup：整体一起淡出）
local boot = Instance.new("CanvasGroup", gui)
boot.Size = UDim2.fromScale(1, 1)
boot.BackgroundTransparency = 1
boot.GroupTransparency = 0
boot.ZIndex = 2

-- 主层（初始隐藏）
local main = Instance.new("CanvasGroup", gui)
main.Size = UDim2.fromScale(1, 1)
main.BackgroundTransparency = 1
main.GroupTransparency = 1
main.ZIndex = 3

-- ===== BOOT UI =====
local glitch = Instance.new("TextLabel", boot)
glitch.Size = UDim2.fromScale(1, 0.12)
glitch.Position = UDim2.fromScale(0.5, 0.16)
glitch.AnchorPoint = Vector2.new(0.5, 0.5)
glitch.BackgroundTransparency = 1
glitch.Font = Enum.Font.Code
glitch.TextColor3 = CFG.ACCENT
glitch.TextSize = 34
glitch.Text = "AWSD // ENTERTAINMENT SYSTEM"
glitch.ZIndex = 4

local logs = Instance.new("TextLabel", boot)
logs.Size = UDim2.fromScale(0.86, 0.34)
logs.Position = UDim2.fromScale(0.5, 0.40)
logs.AnchorPoint = Vector2.new(0.5, 0.5)
logs.BackgroundTransparency = 1
logs.Font = Enum.Font.Code
logs.TextColor3 = Color3.fromRGB(150, 225, 175)
logs.TextSize = 15
logs.TextXAlignment = Enum.TextXAlignment.Left
logs.TextYAlignment = Enum.TextYAlignment.Top
logs.Text = ""
logs.ZIndex = 4

local barBg = Instance.new("Frame", boot)
barBg.Size = UDim2.fromScale(0.72, 0.012)
barBg.Position = UDim2.fromScale(0.5, 0.70)
barBg.AnchorPoint = Vector2.new(0.5, 0.5)
barBg.BackgroundColor3 = Color3.fromRGB(30, 40, 46)
barBg.BorderSizePixel = 0
barBg.ZIndex = 4
local barFill = Instance.new("Frame", barBg)
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = CFG.ACCENT
barFill.BorderSizePixel = 0
barFill.ZIndex = 5
local grad = Instance.new("UIGradient", barFill)
grad.Color = ColorSequence.new(
    Color3.fromRGB(40, 120, 255),
    CFG.ACCENT
)

local pct = Instance.new("TextLabel", boot)
pct.Size = UDim2.fromScale(0.72, 0.06)
pct.Position = UDim2.fromScale(0.5, 0.745)
pct.AnchorPoint = Vector2.new(0.5, 0.5)
pct.BackgroundTransparency = 1
pct.Font = Enum.Font.Code
pct.TextColor3 = CFG.ACCENT
pct.TextSize = 14
pct.Text = "000%"
pct.ZIndex = 4

local scan = Instance.new("Frame", boot)
scan.Size = UDim2.fromScale(1, 0.0035)
scan.AnchorPoint = Vector2.new(0, 0.5)
scan.BackgroundColor3 = CFG.ACCENT
scan.BackgroundTransparency = 0.55
scan.BorderSizePixel = 0
scan.ZIndex = 6

local ready = Instance.new("TextLabel", boot)
ready.Size = UDim2.fromScale(1, 0.08)
ready.Position = UDim2.fromScale(0.5, 0.84)
ready.AnchorPoint = Vector2.new(0.5, 0.5)
ready.BackgroundTransparency = 1
ready.Font = Enum.Font.Code
ready.TextColor3 = Color3.fromRGB(255, 235, 120)
ready.TextSize = 22
ready.TextTransparency = 1
ready.Text = ">> SYSTEM READY <<"
ready.ZIndex = 4

-- ===== MAIN UI =====
local emoji = Instance.new("TextLabel", main)
emoji.Size = UDim2.fromScale(1, 1)
emoji.Position = UDim2.fromScale(0.5, 0.46)
emoji.AnchorPoint = Vector2.new(0.5, 0.5)
emoji.BackgroundTransparency = 1
emoji.Font = Enum.Font.Code
emoji.Text = CFG.EMOJI
emoji.TextColor3 = Color3.new(1, 1, 1)
emoji.TextXAlignment = Enum.TextXAlignment.Center
emoji.TextYAlignment = Enum.TextYAlignment.Center
emoji.Rotation = 0
emoji.ZIndex = 4

local footer = Instance.new("TextLabel", main)
footer.Size = UDim2.fromScale(1, 0.09)
footer.Position = UDim2.fromScale(0.5, 0.93)
footer.AnchorPoint = Vector2.new(0.5, 0.5)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.Code
footer.Text = CFG.FOOTER
footer.TextColor3 = CFG.ACCENT
footer.TextSize = 20
footer.ZIndex = 5

local vs = Cam and Cam.ViewportSize or Vector2.new(1920, 1080)
local baseSize = math.floor(math.min(vs.X, vs.Y) * 0.62)
emoji.TextSize = baseSize
footer.TextSize = math.floor(math.clamp(vs.X * 0.022, 14, 26))

print("[AWSD] boot 启动中…（看屏幕，不用盯控制台）")

-- ===== 启动动画 =====
local BOOT_LINES = {
    "初始化渲染核心 ............ OK",
    "挂载全屏覆盖层 ............ OK",
    "加载表情资源包 ............ OK",
    "校准旋转矩阵 .............. OK",
    "注入快乐因子 .............. OK",
    "权限检查 .................. AWSD",
}
local GLITCH_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#%&@*!"

task.spawn(function()
    -- 标题 glitch 抖动 0.8s
    task.spawn(function()
        local t0 = os.clock()
        local final = "AWSD // ENTERTAINMENT SYSTEM"
        while os.clock() - t0 < 0.8 do
            local s = final
            for _ = 1, 3 do
                local i = math.random(1, #s)
                local c = GLITCH_CHARS:sub(math.random(1, #GLITCH_CHARS), math.random(1, #GLITCH_CHARS))
                s = s:sub(1, i - 1) .. c .. s:sub(i + 1)
            end
            glitch.Text = s
            task.wait(0.055)
        end
        glitch.Text = final
    end)

    -- 进度条 + 扫描线
    Tween:Create(barFill, TweenInfo.new(CFG.BOOT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.fromScale(1, 1) }):Play()
    task.spawn(function()
        for _ = 1, 3 do
            scan.Position = UDim2.fromScale(0, 0)
            Tween:Create(scan, TweenInfo.new(0.9, Enum.EasingStyle.Linear),
                { Position = UDim2.fromScale(0, 1) }):Play()
            task.wait(0.95)
        end
    end)

    -- 日志打字机
    local acc = ""
    for _, line in ipairs(BOOT_LINES) do
        for i = 1, #line do
            acc = acc .. line:sub(i, i)
            logs.Text = acc
            task.wait(0.012)
        end
        acc = acc .. "\n"
        logs.Text = acc
        task.wait(0.13)
    end

    -- READY 闪三下
    for _ = 1, 3 do
        ready.TextTransparency = 0
        task.wait(0.09)
        ready.TextTransparency = 1
        task.wait(0.07)
    end
    ready.TextTransparency = 0
    task.wait(0.25)

    -- 淡出 boot / 淡入主层
    Tween:Create(boot, TweenInfo.new(0.5), { GroupTransparency = 1 }):Play()
    Tween:Create(main, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { GroupTransparency = 0 }):Play()
    task.wait(0.55)
    boot:Destroy()
    ready = false  -- 标记给主循环
    _G.AWSD_READY = true
    print("[AWSD] ready 😂")
end)

-- ===== 主循环 =====
local t, dead = 0, false
local conn
conn = RunService.RenderStepped:Connect(function(dt)
    if dead then return end
    t = t + dt

    -- 分辨率变化（转屏）自适应
    local v = Cam and Cam.ViewportSize
    if v and (v.X ~= vs.X or v.Y ~= vs.Y) then
        vs = v
        baseSize = math.floor(math.min(vs.X, vs.Y) * 0.62)
        footer.TextSize = math.floor(math.clamp(vs.X * 0.022, 14, 26))
    end

    if not _G.AWSD_READY then
        local p = math.clamp(t / CFG.BOOT_TIME, 0, 1)
        pct.Text = string.format("%03d%%  [ %s ]", math.floor(p * 100),
            string.rep("█", math.floor(p * 24)) .. string.rep("░", 24 - math.floor(p * 24)))
        return
    end

    emoji.Rotation = (t * CFG.SPIN_SPEED) % 360
    local amp = vs.Y * CFG.JUMP_AMP
    emoji.Position = UDim2.new(0.5, 0, 0.46,
        -math.abs(math.sin(t * CFG.JUMP_SPEED)) * amp)
    emoji.TextSize = math.floor(baseSize * (1 + 0.05 * math.sin(t * 4)))
    footer.TextTransparency = 0.18 + 0.14 * math.sin(t * 2.2)
end)

-- 手动关闭用
_G.AWSD_Entertainment = {
    Stop = function()
        if dead then return end
        dead = true
        _G.AWSD_READY = false
        if conn then conn:Disconnect() end
        pcall(function() gui:Destroy() end)
        print("[AWSD] 已关闭")
    end,
}
