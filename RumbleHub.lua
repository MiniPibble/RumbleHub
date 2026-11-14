--[[
    RumbleHub  |  Auto Code Redeemer  |  v2.1
    Brand-new UI, live stats, history, manual redeem, themes, keybinds & more.
]]

-- ============================================================
--  SERVICES
-- ============================================================
local cloneref = cloneref or function(x) return x end
local function svc(name) return cloneref(game:GetService(name)) end

local Players       = svc("Players")
local RunService    = svc("RunService")
local UIS           = svc("UserInputService")
local TweenService  = svc("TweenService")
local HttpService   = svc("HttpService")
local RepStorage    = svc("ReplicatedStorage")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local GUI_NAME = "RumbleHub"

-- ============================================================
--  CLEANUP OLD INSTANCES
-- ============================================================
pcall(function()
    if getgenv and getgenv().RumbleHubUnload then getgenv().RumbleHubUnload() end
end)
local function getUiParent()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h then return h end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then return cg end
    return PG
end
local UI_PARENT = getUiParent()
for _, holder in ipairs({ UI_PARENT, PG }) do
    for _, n in ipairs({ GUI_NAME, "LevithonCodeRedeemer", "ACECodeSniperUI", "AutoTypeCodesUI" }) do
        local old = holder:FindFirstChild(n)
        if old then old:Destroy() end
    end
end

-- ============================================================
--  CONFIG (auto-saved)
-- ============================================================
local CONFIG_FILE = "RumbleHub_config.json"
local Defaults = {
    AutoCode       = true,
    AutoSubmit     = true,
    RetypeInvalid  = false,
    SubmitAfter    = 3,
    SubmitDelay    = 0.05,
    Toasts         = true,
    AntiAfk        = false,
    AccentIndex    = 1,
    Scale          = 1,
    Opacity        = 0,
    Keybind        = "RightShift",
}
local Config = {}
for k, v in pairs(Defaults) do Config[k] = v end

pcall(function()
    if type(isfile) == "function" and type(readfile) == "function" and isfile(CONFIG_FILE) then
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(data) == "table" then
            for k, v in pairs(Defaults) do
                if type(data[k]) == type(v) then Config[k] = data[k] end
            end
        end
    end
end)
Config.SubmitAfter = math.max(1, math.floor(Config.SubmitAfter))

local function saveConfig()
    if type(writefile) ~= "function" then return end
    pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(Config)) end)
end

-- ============================================================
--  THEME
-- ============================================================
local Accents = {
    { Name = "Crimson", Color = Color3.fromRGB(255, 77, 94)  },
    { Name = "Violet",  Color = Color3.fromRGB(139, 108, 255) },
    { Name = "Ocean",   Color = Color3.fromRGB(56, 189, 248) },
    { Name = "Mint",    Color = Color3.fromRGB(52, 211, 153) },
    { Name = "Amber",   Color = Color3.fromRGB(251, 191, 36) },
}
local T = {
    Accent = (Accents[Config.AccentIndex] or Accents[1]).Color,
    Bg     = Color3.fromRGB(12, 12, 17),
    Card   = Color3.fromRGB(21, 21, 29),
    Card2  = Color3.fromRGB(33, 33, 44),
    Off    = Color3.fromRGB(52, 52, 68),
    Text   = Color3.fromRGB(244, 244, 248),
    Sub    = Color3.fromRGB(150, 152, 170),
    Dim    = Color3.fromRGB(100, 102, 120),
    Good   = Color3.fromRGB(74, 222, 128),
    Bad    = Color3.fromRGB(248, 81, 96),
    Warn   = Color3.fromRGB(251, 191, 36),
}
local WHITE = Color3.new(1, 1, 1)
local FONT   = Enum.Font.GothamMedium
local FONT_S = Enum.Font.GothamSemibold
local FONT_B = Enum.Font.GothamBold
local FONT_M = Enum.Font.RobotoMono
local EASE_BACK = Enum.EasingStyle.Back
local EASE_EXP  = Enum.EasingStyle.Exponential

-- ============================================================
--  HELPERS
-- ============================================================
local function new(class, props, kids)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    for _, c in ipairs(kids or {}) do c.Parent = o end
    return o
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function stroke(col, th, tr)
    return new("UIStroke", { Color = col or WHITE, Thickness = th or 1, Transparency = tr or 0.93,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function pad(l, t, r, b)
    return new("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
        PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b) })
end
local function tween(o, t, props, style, dir)
    local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end
local function text(parent, props)
    local d = {
        BackgroundTransparency = 1, Font = FONT, TextSize = 12, TextColor3 = T.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = "",
    }
    for k, v in pairs(props) do d[k] = v end
    d.Parent = parent
    return new("TextLabel", d)
end
local function lighten(c, a) return c:Lerp(WHITE, a) end
local function lum(c) return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B end
local function rgbTag(c)
    return string.format("rgb(%d,%d,%d)", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function esc(s)
    s = tostring(s)
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    return s
end

local accentFns = {}
local function onAccent(fn) accentFns[#accentFns + 1] = fn; fn(T.Accent) end
local function setAccent(c)
    T.Accent = c
    for _, fn in ipairs(accentFns) do pcall(fn, c) end
end

local connections = {}
local function track(conn) connections[#connections + 1] = conn; return conn end

local function clip(str)
    if type(setclipboard) == "function" then pcall(setclipboard, str); return true end
    if type(toclipboard) == "function" then pcall(toclipboard, str); return true end
    return false
end

-- ============================================================
--  STATE
-- ============================================================
local S = {
    Pending = {}, Seen = {}, Captured = 0, Redeemed = 0, Failed = 0, StartTime = os.clock(),
    History = {}, FocusedBox = nil, CodeBox = nil, Watched = nil, TextConn = nil, AncConn = nil,
    OtherConns = {}, LastTyped = "", RetryText = nil, RetryBox = nil, RetryExpiry = 0, RetryToken = 0,
    LastLog = nil, RemoteHooked = false,
}
local UI = {}                    -- all UI references live here (keeps local count low)
local masterToggle = {}
local remoteText
local setAuto, redeemCode, pasteToBox, clearHistory, unload

-- ============================================================
--  WINDOW
-- ============================================================
local gui = new("ScreenGui", {
    Name = GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
if not pcall(function() gui.Parent = UI_PARENT end) then gui.Parent = PG end

local W, H = 280, 360
local root = new("Frame", {
    Name = "Root", Size = UDim2.fromOffset(W, H), Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2),
    BackgroundTransparency = 1, Parent = gui,
})
local uiScale = new("UIScale", { Scale = 0.88, Parent = root })

new("ImageLabel", {                                  -- soft drop shadow
    Name = "Shadow", BackgroundTransparency = 1, Image = "rbxassetid://6014261993",
    ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0.45, ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(49, 49, 450, 450), Size = UDim2.new(1, 56, 1, 56), Position = UDim2.fromOffset(-28, -22),
    ZIndex = 0, Parent = root,
})

local main = new("Frame", {
    Name = "Window", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = Config.Opacity,
    BorderSizePixel = 0, ClipsDescendants = true, Active = true, Parent = root,
}, {
    corner(16),
    new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(19, 19, 26), Color3.fromRGB(9, 9, 13)) }),
})

-- animated accent border
local borderStroke = new("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.25,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = main })
local borderGrad = new("UIGradient", { Parent = borderStroke })
onAccent(function(c)
    local dark = Color3.fromRGB(30, 30, 40)
    borderGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, c), ColorSequenceKeypoint.new(0.25, dark),
        ColorSequenceKeypoint.new(0.5, c), ColorSequenceKeypoint.new(0.75, dark),
        ColorSequenceKeypoint.new(1, c),
    })
end)

-- top glow
local glow = new("Frame", { Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = main },
    { new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.84), NumberSequenceKeypoint.new(1, 1) }) }) })
onAccent(function(c) glow.BackgroundColor3 = c end)

-- Header
local header = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Active = true, Parent = main })
local logo = new("Frame", { Size = UDim2.fromOffset(110, 46), BackgroundTransparency = 1, Parent = header }, {
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center }),
    pad(16, 0, 0, 0),
})
new("TextLabel", { Text = "Rumble", Font = FONT_B, TextSize = 17, TextColor3 = T.Text, BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 46), Parent = logo })
local logoHub = new("TextLabel", { Text = "Hub", Font = FONT_B, TextSize = 17, TextColor3 = T.Accent, BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 46), Parent = logo })
onAccent(function(c) logoHub.TextColor3 = c end)

local perf = text(header, { Text = "-- fps | -- ms", Font = FONT_M, TextSize = 9, TextColor3 = T.Dim,
    TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(84, 46), Position = UDim2.new(1, -150, 0, 0) })

local function iconButton(xOff, kind, hoverColor)
    local b = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(26, 26),
        Position = UDim2.new(1, xOff, 0, 10), BackgroundColor3 = T.Card2, BackgroundTransparency = 0.4, Parent = header }, { corner(13) })
    local sc = new("UIScale", { Parent = b })
    local parts = {}
    local function bar(rot, w)
        local f = new("Frame", { Size = UDim2.fromOffset(w, 2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Rotation = rot, BackgroundColor3 = T.Sub, BorderSizePixel = 0, Parent = b }, { corner(1) })
        parts[#parts + 1] = f
    end
    if kind == "min" then bar(0, 10) else bar(45, 11); bar(-45, 11) end
    b.MouseEnter:Connect(function()
        tween(b, 0.18, { BackgroundColor3 = hoverColor, BackgroundTransparency = 0 })
        for _, p in ipairs(parts) do tween(p, 0.18, { BackgroundColor3 = WHITE }) end
    end)
    b.MouseLeave:Connect(function()
        tween(b, 0.22, { BackgroundColor3 = T.Card2, BackgroundTransparency = 0.4 })
        for _, p in ipairs(parts) do tween(p, 0.22, { BackgroundColor3 = T.Sub }) end
        tween(sc, 0.2, { Scale = 1 })
    end)
    b.MouseButton1Down:Connect(function() tween(sc, 0.1, { Scale = 0.88 }) end)
    b.MouseButton1Up:Connect(function() tween(sc, 0.3, { Scale = 1 }, EASE_BACK) end)
    return b
end
local closeBtn = iconButton(-36, "close", T.Bad)
local minBtn = iconButton(-68, "min", Color3.fromRGB(60, 60, 78))

-- ============================================================
--  TOASTS
-- ============================================================
local toastHolder = new("Frame", { Size = UDim2.fromOffset(236, 320), Position = UDim2.new(1, -248, 0, 16),
    BackgroundTransparency = 1, Parent = gui }, {
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local toastOrder = 0
local function toast(title, body, color)
    if not Config.Toasts then return end
    color = color or T.Accent
    toastOrder = toastOrder + 1
    local kids = {}
    for _, c in ipairs(toastHolder:GetChildren()) do if c:IsA("Frame") then kids[#kids + 1] = c end end
    if #kids >= 4 then kids[1]:Destroy() end

    local wrap = new("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = toastOrder, Parent = toastHolder })
    local f = new("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.new(1.2, 0, 0, 0), BackgroundColor3 = T.Card,
        BorderSizePixel = 0, ClipsDescendants = true, Parent = wrap }, { corner(12), stroke(color, 1, 0.7) })
    new("Frame", { Size = UDim2.fromOffset(3, 26), Position = UDim2.fromOffset(12, 11), BackgroundColor3 = color,
        BorderSizePixel = 0, Parent = f }, { corner(2) })
    text(f, { Text = title, Font = FONT_B, TextSize = 12, Position = UDim2.fromOffset(26, 9), Size = UDim2.new(1, -36, 0, 16) })
    text(f, { Text = body, TextSize = 10, TextColor3 = T.Sub, TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(26, 26), Size = UDim2.new(1, -36, 0, 14) })
    local timer = new("Frame", { Size = UDim2.new(1, -24, 0, 2), Position = UDim2.new(0, 12, 1, -5), BackgroundColor3 = color,
        BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = f }, { corner(1) })
    tween(f, 0.5, { Position = UDim2.new(0, 0, 0, 0) }, EASE_EXP)
    TweenService:Create(timer, TweenInfo.new(3, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
    task.delay(3.1, function()
        if not wrap.Parent then return end
        tween(f, 0.35, { Position = UDim2.new(1.2, 0, 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.wait(0.4)
        wrap:Destroy()
    end)
end

-- ============================================================
--  TABS (sliding pill) + PAGES (fade/slide)
-- ============================================================
local tabNames = { "Home", "Auto", "Codes", "Settings" }
local tabIndex = {}
for i, n in ipairs(tabNames) do tabIndex[n] = i end
local pages, tabBtns, currentTab = {}, {}, nil

local tabBar = new("Frame", { Position = UDim2.fromOffset(12, 52), Size = UDim2.new(1, -24, 0, 34),
    BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = main }, { corner(12), stroke(WHITE, 1, 0.93) })
local tabInd = new("Frame", { Size = UDim2.new(0.25, -4, 1, -6), Position = UDim2.new(0, 2, 0, 3),
    BackgroundColor3 = T.Accent, BackgroundTransparency = 0.8, BorderSizePixel = 0, Parent = tabBar },
    { corner(9), new("UIStroke", { Color = T.Accent, Thickness = 1, Transparency = 0.5 }) })
onAccent(function(c) tabInd.BackgroundColor3 = c; tabInd.UIStroke.Color = c end)

local pagesHolder = new("Frame", { Position = UDim2.fromOffset(12, 94), Size = UDim2.new(1, -24, 1, -102),
    BackgroundTransparency = 1, Parent = main })

local function makePage(name)
    local cg = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1,
        Visible = false, Parent = pagesHolder })
    local sf = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = T.Dim, ScrollBarImageTransparency = 0.4,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = cg }, {
        new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
        pad(1, 2, 6, 10),
    })
    pages[name] = { cg = cg, sf = sf }
    return sf
end

local function selectTab(name)
    if currentTab == name then return end
    local old = currentTab
    local dir = (old and tabIndex[name] < tabIndex[old]) and -1 or 1
    currentTab = name
    if old then
        local og = pages[old].cg
        tween(og, 0.16, { GroupTransparency = 1, Position = UDim2.fromOffset(-14 * dir, 0) })
        task.delay(0.17, function() if currentTab ~= old then og.Visible = false end end)
    end
    local ng = pages[name].cg
    ng.Position = UDim2.fromOffset(16 * dir, 0)
    ng.Visible = true
    tween(ng, 0.4, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, EASE_EXP)
    tween(tabInd, 0.4, { Position = UDim2.new((tabIndex[name] - 1) * 0.25, 2, 0, 3) }, EASE_EXP)
    for n, b in pairs(tabBtns) do tween(b, 0.25, { TextColor3 = (n == name) and T.Text or T.Sub }) end
end

for i, n in ipairs(tabNames) do
    local b = new("TextButton", { Text = n, Font = FONT_S, TextSize = 11, TextColor3 = T.Sub, AutoButtonColor = false,
        BackgroundTransparency = 1, Size = UDim2.new(0.25, 0, 1, 0), Position = UDim2.new((i - 1) * 0.25, 0, 0, 0), Parent = tabBar })
    tabBtns[n] = b
    b.MouseEnter:Connect(function() if currentTab ~= n then tween(b, 0.15, { TextColor3 = lighten(T.Sub, 0.35) }) end end)
    b.MouseLeave:Connect(function() if currentTab ~= n then tween(b, 0.2, { TextColor3 = T.Sub }) end end)
    b.MouseButton1Click:Connect(function() selectTab(n) end)
    makePage(n)
end

-- ============================================================
--  COMPONENTS
-- ============================================================
local order = 0
local function nextOrder() order = order + 1; return order end

local function caption(parent, str)
    return text(parent, { Text = string.upper(str), Font = FONT_B, TextSize = 9, TextColor3 = T.Dim,
        Size = UDim2.new(1, 0, 0, 12), LayoutOrder = nextOrder() })
end

-- grouped list card (iOS-style rows with hairline dividers)
local function group(parent)
    local g = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Card,
        BorderSizePixel = 0, LayoutOrder = nextOrder(), Parent = parent }, {
        corner(14), stroke(WHITE, 1, 0.93),
        new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
    })
    local count = 0
    local function row(h)
        local idx = count + 1
        if count > 0 then
            new("Frame", { Size = UDim2.new(1, -28, 0, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.93,
                BorderSizePixel = 0, LayoutOrder = idx * 2 - 1, Parent = g })
        end
        count = idx
        return new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = idx * 2, Parent = g })
    end
    return g, row
end

local function makeButton(parent, str, size, pos, kind)
    kind = kind or "ghost"
    local function base()
        if kind == "primary" then return T.Accent elseif kind == "danger" then return Color3.fromRGB(58, 24, 30) end
        return T.Card2
    end
    local function hov()
        if kind == "primary" then return lighten(T.Accent, 0.18) elseif kind == "danger" then return Color3.fromRGB(86, 30, 40) end
        return Color3.fromRGB(46, 46, 60)
    end
    local b = new("TextButton", { Text = str, Font = FONT_B, TextSize = 11, AutoButtonColor = false, Size = size, Position = pos,
        BackgroundColor3 = base(), TextColor3 = (kind == "danger") and T.Bad or T.Text, Parent = parent }, { corner(10) })
    local sc = new("UIScale", { Parent = b })
    if kind == "primary" then
        onAccent(function(c)
            b.BackgroundColor3 = c
            b.TextColor3 = (lum(c) > 0.62) and Color3.fromRGB(22, 22, 22) or WHITE
        end)
    end
    b.MouseEnter:Connect(function() tween(b, 0.18, { BackgroundColor3 = hov() }) end)
    b.MouseLeave:Connect(function() tween(b, 0.22, { BackgroundColor3 = base() }); tween(sc, 0.2, { Scale = 1 }) end)
    b.MouseButton1Down:Connect(function() tween(sc, 0.1, { Scale = 0.95 }) end)
    b.MouseButton1Up:Connect(function() tween(sc, 0.35, { Scale = 1 }, EASE_BACK) end)
    return b
end

local function linkButton(parent, str, w, pos)
    local b = new("TextButton", { Text = str, Font = FONT_S, TextSize = 10, TextColor3 = T.Sub, AutoButtonColor = false,
        BackgroundTransparency = 1, Size = UDim2.fromOffset(w, 16), Position = pos, Parent = parent })
    b.MouseEnter:Connect(function() tween(b, 0.15, { TextColor3 = T.Text }) end)
    b.MouseLeave:Connect(function() tween(b, 0.2, { TextColor3 = T.Sub }) end)
    return b
end

local function switchVisual(parent, w, h, pos)
    local kn = h - 6
    local trackF = new("Frame", { Size = UDim2.fromOffset(w, h), Position = pos, BackgroundColor3 = T.Off, BorderSizePixel = 0, Parent = parent }, { corner(h / 2) })
    local knob = new("Frame", { Size = UDim2.fromOffset(kn, kn), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = WHITE,
        BorderSizePixel = 0, Parent = trackF }, { corner(kn / 2) })
    local function render(on, animate)
        local col = on and T.Accent or T.Off
        local p = on and UDim2.fromOffset(w - kn - 3, 3) or UDim2.fromOffset(3, 3)
        if animate then
            tween(trackF, 0.25, { BackgroundColor3 = col })
            tween(knob, 0.35, { Position = p }, EASE_BACK)
        else
            trackF.BackgroundColor3 = col
            knob.Position = p
        end
    end
    return render
end

local function toggleRow(row, title, desc, init, cb)
    text(row, { Text = title, Font = FONT_S, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -84, 0, 16) })
    text(row, { Text = desc or "", TextSize = 10, TextColor3 = T.Sub, TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(14, 25), Size = UDim2.new(1, -84, 0, 14) })
    local render = switchVisual(row, 40, 22, UDim2.new(1, -54, 0.5, -11))
    local state = init
    render(state, false)
    onAccent(function() render(state, false) end)
    local obj = {}
    function obj.Set(v, silent)
        state = v
        render(state, true)
        if not silent and cb then cb(v) end
    end
    local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = row })
    hit.MouseButton1Click:Connect(function() obj.Set(not state) end)
    return obj
end

local function stepperRow(row, title, desc, init, min, max, cb)
    text(row, { Text = title, Font = FONT_S, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -130, 0, 16) })
    text(row, { Text = desc or "", TextSize = 10, TextColor3 = T.Sub, TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(14, 25), Size = UDim2.new(1, -130, 0, 14) })
    local val = init
    local minus = makeButton(row, "-", UDim2.fromOffset(26, 26), UDim2.new(1, -112, 0.5, -13))
    local num = text(row, { Text = tostring(val), Font = FONT_B, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.fromOffset(30, 26), Position = UDim2.new(1, -84, 0.5, -13) })
    local numScale = new("UIScale", { Parent = num })
    local plus = makeButton(row, "+", UDim2.fromOffset(26, 26), UDim2.new(1, -40, 0.5, -13))
    local function set(v)
        val = math.clamp(v, min, max)
        num.Text = tostring(val)
        numScale.Scale = 1.25
        tween(numScale, 0.35, { Scale = 1 }, EASE_BACK)
        if cb then cb(val) end
    end
    minus.MouseButton1Click:Connect(function() set(val - 1) end)
    plus.MouseButton1Click:Connect(function() set(val + 1) end)
    return { Set = set }
end

local function sliderRow(row, title, min, max, init, decimals, cb)
    text(row, { Text = title, Font = FONT_S, Position = UDim2.fromOffset(14, 9), Size = UDim2.new(1, -90, 0, 16) })
    local valLbl = text(row, { Font = FONT_M, TextSize = 10, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(1, -74, 0, 9), Size = UDim2.fromOffset(60, 16) })
    local bar = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = T.Off, Size = UDim2.new(1, -28, 0, 5),
        Position = UDim2.fromOffset(14, 36), Parent = row }, { corner(3) })
    local fill = new("Frame", { BackgroundColor3 = T.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), Parent = bar }, { corner(3) })
    local knob = new("Frame", { Size = UDim2.fromOffset(13, 13), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = bar }, { corner(7) })
    local ks = new("UIScale", { Parent = knob })
    onAccent(function(c) fill.BackgroundColor3 = c end)
    local mult = 10 ^ (decimals or 0)
    local function setValue(v, fire)
        v = math.clamp(v, min, max)
        v = math.floor(v * mult + 0.5) / mult
        local a = (v - min) / (max - min)
        tween(fill, 0.08, { Size = UDim2.fromScale(a, 1) })
        tween(knob, 0.08, { Position = UDim2.new(a, 0, 0.5, 0) })
        valLbl.Text = tostring(v)
        if fire and cb then cb(v) end
    end
    setValue(init, false)
    local dragging = false
    local function fromInput(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
        setValue(min + (max - min) * a, true)
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            tween(ks, 0.2, { Scale = 1.35 }, EASE_BACK)
            fromInput(i.Position.X)
        end
    end)
    track(UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            fromInput(i.Position.X)
        end
    end))
    track(UIS.InputEnded:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            tween(ks, 0.25, { Scale = 1 }, EASE_BACK)
        end
    end))
    return { Set = function(v) setValue(v, false) end }
end

-- ============================================================
--  LOG / STATS / BUFFER / HISTORY  (engine-facing API)
-- ============================================================
local logLines, logCount = {}, 0
local shown, countTok = { Captured = 0, Redeemed = 0, Failed = 0 }, {}
local prevCount = 0

local function log(msg, color)
    if msg == S.LastLog then return end
    S.LastLog = msg
    color = color or T.Sub
    local stamp = os.date("%H:%M:%S")
    logLines[#logLines + 1] = "[" .. stamp .. "] " .. msg
    if #logLines > 200 then table.remove(logLines, 1) end
    if not UI.logFrame then return end
    logCount = logCount + 1
    local l = new("TextLabel", {
        Text = string.format('<font color="%s">%s</font>  <font color="%s">%s</font>', rgbTag(T.Dim), stamp, rgbTag(color), esc(msg)),
        RichText = true, Font = FONT_M, TextSize = 10, TextColor3 = T.Sub, BackgroundTransparency = 1, TextTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, -4, 0, 12), LayoutOrder = logCount, Parent = UI.logFrame,
    })
    tween(l, 0.3, { TextTransparency = 0 })
    local kids = {}
    for _, c in ipairs(UI.logFrame:GetChildren()) do if c:IsA("TextLabel") then kids[#kids + 1] = c end end
    if #kids > 100 then kids[1]:Destroy() end
    task.defer(function() UI.logFrame.CanvasPosition = Vector2.new(0, 1e6) end)
end

local function countTo(key, target)
    local lbl = UI.stat[key]
    local from = shown[key]
    if from == target then return end
    shown[key] = target
    local tok = (countTok[key] or 0) + 1
    countTok[key] = tok
    local sc = lbl:FindFirstChildOfClass("UIScale")
    if sc then sc.Scale = 1.22; tween(sc, 0.4, { Scale = 1 }, EASE_BACK) end
    task.spawn(function()
        local t0 = os.clock()
        while os.clock() - t0 < 0.4 and countTok[key] == tok do
            local a = (os.clock() - t0) / 0.4
            a = 1 - (1 - a) ^ 3
            lbl.Text = tostring(math.floor(from + (target - from) * a + 0.5))
            RunService.RenderStepped:Wait()
        end
        if countTok[key] == tok then lbl.Text = tostring(target) end
    end)
end

local function refreshStats()
    if not UI.stat then return end
    countTo("Captured", S.Captured)
    countTo("Redeemed", S.Redeemed)
    countTo("Failed", S.Failed)
end

local function refreshBuffer()
    local holder = UI.slots
    if not holder then return end
    local total = Config.SubmitAfter
    local count = #S.Pending
    local n = math.min(total, 10)
    for _, c in ipairs(holder:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local inner = holder.AbsoluteSize.X
    if inner <= 0 then inner = 220 end
    local size = math.clamp(math.floor((inner - (n - 1) * 5) / n), 12, 28)
    local first = math.max(1, count - n + 1)
    for i = 1, n do
        local letter = S.Pending[first + i - 1]
        local f = new("Frame", { Size = UDim2.fromOffset(size, size), LayoutOrder = i, BorderSizePixel = 0,
            BackgroundColor3 = letter and T.Accent or T.Card2, BackgroundTransparency = letter and 0.78 or 0.3, Parent = holder },
            { corner(8), new("UIStroke", { Color = letter and T.Accent or WHITE, Thickness = 1, Transparency = letter and 0.35 or 0.92 }) })
        if letter then
            text(f, { Text = letter, Font = FONT_B, TextSize = size > 18 and 12 or 10, TextXAlignment = Enum.TextXAlignment.Center,
                Size = UDim2.fromScale(1, 1) })
            if i == math.min(count, n) and count > prevCount then
                local sc = new("UIScale", { Scale = 0.5, Parent = f })
                tween(sc, 0.45, { Scale = 1 }, EASE_BACK)
            end
        end
    end
    prevCount = count
    if UI.bufCount then UI.bufCount.Text = count .. " / " .. total end
end

local function statusColor(st)
    if st == "Submitted" then return T.Good elseif st == "Failed" or st == "Invalid" then return T.Bad
    elseif st == "Not sent" then return T.Sub end
    return T.Warn
end

local function paintChip(entry, status, color)
    color = color or statusColor(status)
    if entry.Chip then
        tween(entry.Chip, 0.25, { BackgroundColor3 = color })
        entry.ChipText.Text = status
        tween(entry.ChipText, 0.25, { TextColor3 = color })
    end
end

local function addHistory(code, status, color)
    local entry = { Code = code, Time = os.date("%H:%M:%S"), Status = status }
    table.insert(S.History, 1, entry)
    if UI.histEmpty then UI.histEmpty.Visible = false end
    if UI.historyList then
        local row = new("CanvasGroup", { Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = T.Card, GroupTransparency = 1,
            LayoutOrder = -math.floor(os.clock() * 1000), Parent = UI.historyList }, { corner(12), stroke(WHITE, 1, 0.93) })
        text(row, { Text = entry.Time, Font = FONT_M, TextSize = 9, TextColor3 = T.Dim, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(48, 38) })
        text(row, { Text = code, Font = FONT_B, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(62, 0), Size = UDim2.new(1, -170, 1, 0) })
        entry.Chip = new("Frame", { Size = UDim2.fromOffset(54, 18), Position = UDim2.new(1, -102, 0.5, -9), BackgroundColor3 = color or statusColor(status),
            BackgroundTransparency = 0.84, BorderSizePixel = 0, Parent = row }, { corner(9) })
        entry.ChipText = text(entry.Chip, { Text = status, Font = FONT_B, TextSize = 9, TextColor3 = color or statusColor(status),
            TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
        entry.Chip.BackgroundColor3 = color or statusColor(status)
        local cp = makeButton(row, "Copy", UDim2.fromOffset(38, 22), UDim2.new(1, -44, 0.5, -11))
        cp.TextSize = 9
        cp.MouseButton1Click:Connect(function()
            if clip(code) then toast("Copied", code, T.Good) else toast("Clipboard unavailable", "Your executor has no clipboard", T.Warn) end
        end)
        entry.Row = row
        tween(row, 0.4, { GroupTransparency = 0 })
    end
    return entry
end

local function setEntryStatus(entry, status, color)
    if not entry then return end
    entry.Status = status
    paintChip(entry, status, color)
end

-- ============================================================
--  PAGE: HOME
-- ============================================================
do
    local p = pages.Home.sf
    order = 0

    -- hero card
    local hero = new("Frame", { Size = UDim2.new(1, 0, 0, 92), BackgroundColor3 = T.Card, BorderSizePixel = 0,
        LayoutOrder = nextOrder(), ClipsDescendants = true, Parent = p }, { corner(14), stroke(WHITE, 1, 0.93) })
    local tint = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = hero },
        { new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.96) }) }) })
    onAccent(function(c) tint.BackgroundColor3 = c end)
    text(hero, { Text = "AUTO CODE", Font = FONT_B, TextSize = 9, TextColor3 = T.Sub, Position = UDim2.fromOffset(16, 13), Size = UDim2.new(1, -90, 0, 12) })
    UI.dot = new("Frame", { Size = UDim2.fromOffset(9, 9), Position = UDim2.fromOffset(16, 40), BackgroundColor3 = T.Good, BorderSizePixel = 0, Parent = hero }, { corner(5) })
    UI.statusText = text(hero, { Text = "Scanning", Font = FONT_B, TextSize = 20, Position = UDim2.fromOffset(32, 28), Size = UDim2.new(1, -100, 0, 32) })
    UI.remote = text(hero, { Text = "Notify remote: searching...", TextSize = 10, TextColor3 = T.Sub, TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(16, 66), Size = UDim2.new(1, -90, 0, 14) })

    local render = switchVisual(hero, 54, 30, UDim2.new(1, -70, 0.5, -15))
    local function renderAll()
        local on = Config.AutoCode
        render(on, true)
        tween(UI.dot, 0.3, { BackgroundColor3 = on and T.Good or T.Bad })
        UI.statusText.Text = on and "Scanning" or "Paused"
    end
    onAccent(function() render(Config.AutoCode, false) end)
    masterToggle.Render = renderAll
    new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(0, 70, 1, 0), Position = UDim2.new(1, -78, 0, 0), Parent = hero })
        .MouseButton1Click:Connect(function() setAuto(not Config.AutoCode) end)

    -- stats
    local statsRow = new("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = p }, {
        new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    UI.stat = {}
    local defs = { { "Captured", T.Accent }, { "Redeemed", T.Good }, { "Failed", T.Bad }, { "Uptime", T.Text } }
    for i, d in ipairs(defs) do
        local c = new("Frame", { Size = UDim2.new(0.25, -5, 1, 0), BackgroundColor3 = T.Card, BorderSizePixel = 0, LayoutOrder = i, Parent = statsRow },
            { corner(12), stroke(WHITE, 1, 0.93) })
        local v = text(c, { Text = (d[1] == "Uptime") and "00:00" or "0", Font = FONT_B, TextSize = (d[1] == "Uptime") and 14 or 18,
            TextColor3 = d[2], TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 9), Size = UDim2.new(1, 0, 0, 24) })
        new("UIScale", { Parent = v })
        text(c, { Text = d[1], TextSize = 9, TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Center,
            Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 12) })
        UI.stat[d[1]] = v
        if d[1] == "Captured" then onAccent(function(col) v.TextColor3 = col end) end
    end

    -- buffer slots
    local bc = new("Frame", { Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = T.Card, BorderSizePixel = 0, LayoutOrder = nextOrder(), Parent = p },
        { corner(14), stroke(WHITE, 1, 0.93) })
    text(bc, { Text = "CODE BUFFER", Font = FONT_B, TextSize = 9, TextColor3 = T.Dim, Position = UDim2.fromOffset(14, 11), Size = UDim2.new(0.5, 0, 0, 12) })
    UI.bufCount = text(bc, { Text = "0 / 3", Font = FONT_M, TextSize = 10, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(1, -74, 0, 10), Size = UDim2.fromOffset(60, 14) })
    UI.slots = new("Frame", { Size = UDim2.new(1, -28, 0, 28), Position = UDim2.fromOffset(14, 32), BackgroundTransparency = 1, Parent = bc },
        { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }) })

    -- activity
    local ah = new("Frame", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = p })
    text(ah, { Text = "ACTIVITY", Font = FONT_B, TextSize = 9, TextColor3 = T.Dim, Size = UDim2.new(0.5, 0, 1, 0) })
    local clr = linkButton(ah, "Clear", 40, UDim2.new(1, -86, 0, -1))
    local cpy = linkButton(ah, "Copy", 40, UDim2.new(1, -42, 0, -1))
    local cc = new("Frame", { Size = UDim2.new(1, 0, 0, 116), BackgroundColor3 = T.Card, BorderSizePixel = 0, LayoutOrder = nextOrder(), Parent = p },
        { corner(14), stroke(WHITE, 1, 0.93) })
    UI.logFrame = new("ScrollingFrame", { Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(10, 8), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = T.Dim, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = cc }, { new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }) })
    clr.MouseButton1Click:Connect(function()
        logLines, S.LastLog = {}, nil
        for _, ch in ipairs(UI.logFrame:GetChildren()) do if ch:IsA("TextLabel") then ch:Destroy() end end
    end)
    cpy.MouseButton1Click:Connect(function()
        if clip(table.concat(logLines, "\n")) then toast("Console copied", #logLines .. " lines", T.Good)
        else toast("Clipboard unavailable", "Your executor has no clipboard", T.Warn) end
    end)
end
remoteText = UI.remote

-- ============================================================
--  PAGE: AUTO
-- ============================================================
do
    local p = pages.Auto.sf
    order = 0
    caption(p, "Automation")
    local g, row = group(p)
    toggleRow(row(46), "Auto submit", "Press redeem when the code is full", Config.AutoSubmit, function(v)
        Config.AutoSubmit = v; saveConfig(); log("Auto submit " .. (v and "ON" or "OFF"))
    end)
    toggleRow(row(46), "Retype invalid", "Re-paste if the game rejects it", Config.RetypeInvalid, function(v)
        Config.RetypeInvalid = v; saveConfig(); log("Retype invalid " .. (v and "ON" or "OFF"))
    end)
    caption(p, "Timing")
    local g2, row2 = group(p)
    stepperRow(row2(46), "Submit after", "Letters before submitting", Config.SubmitAfter, 1, 30, function(v)
        Config.SubmitAfter = v; saveConfig(); refreshBuffer()
    end)
    sliderRow(row2(56), "Submit delay (sec)", 0, 1, Config.SubmitDelay, 2, function(v)
        Config.SubmitDelay = v; saveConfig()
    end)
end

-- ============================================================
--  PAGE: CODES (manual + history)
-- ============================================================
do
    local p = pages.Codes.sf
    order = 0
    caption(p, "Manual redeem")
    local ic = new("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = T.Card, BorderSizePixel = 0, LayoutOrder = nextOrder(), Parent = p },
        { corner(12) })
    local ist = stroke(WHITE, 1, 0.93)
    ist.Parent = ic
    local input = new("TextBox", { Text = "", PlaceholderText = "Type or paste a code...", Font = FONT_S, TextSize = 13, TextColor3 = T.Text,
        PlaceholderColor3 = T.Dim, ClearTextOnFocus = false, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), Parent = ic })
    input.Focused:Connect(function() tween(ist, 0.25, { Color = T.Accent, Transparency = 0.2 }) end)
    input.FocusLost:Connect(function() tween(ist, 0.3, { Color = WHITE, Transparency = 0.93 }) end)

    local br = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = p })
    local redeemBtn = makeButton(br, "Redeem now", UDim2.new(0.5, -4, 1, 0), UDim2.fromOffset(0, 0), "primary")
    local pasteBtn = makeButton(br, "Paste in game", UDim2.new(0.5, -4, 1, 0), UDim2.new(0.5, 4, 0, 0))
    local result = text(p, { Text = "", TextSize = 10, TextColor3 = T.Sub, TextWrapped = true, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = nextOrder() })

    local function say(msg, col)
        result.Text = msg
        result.TextColor3 = col
        result.TextTransparency = 1
        tween(result, 0.3, { TextTransparency = 0 })
    end
    redeemBtn.MouseButton1Click:Connect(function()
        local code = input.Text:gsub("%s", "")
        if code == "" then say("Enter a code first.", T.Warn) return end
        say("Submitting...", T.Sub)
        task.spawn(function()
            local ok, msg = redeemCode(code)
            if ok then say("Submitted " .. code .. "  (" .. tostring(msg) .. ")", T.Good)
            else say("Failed: " .. tostring(msg), T.Bad) end
        end)
    end)
    pasteBtn.MouseButton1Click:Connect(function()
        local code = input.Text:gsub("%s", "")
        if code == "" then say("Enter a code first.", T.Warn) return end
        if pasteToBox(code) then say("Pasted into the game's code box.", T.Good)
        else say("No visible code box. Open the codes menu in-game.", T.Warn) end
    end)

    local hh = new("Frame", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = p })
    text(hh, { Text = "HISTORY", Font = FONT_B, TextSize = 9, TextColor3 = T.Dim, Size = UDim2.new(0.5, 0, 1, 0) })
    local copyAll = linkButton(hh, "Copy all", 50, UDim2.new(1, -96, 0, -1))
    local clearBtn = linkButton(hh, "Clear", 40, UDim2.new(1, -42, 0, -1))
    UI.historyList = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        LayoutOrder = nextOrder(), Parent = p }, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
    UI.histEmpty = text(UI.historyList, { Text = "No codes yet. They show up here.", TextSize = 10, TextColor3 = T.Dim,
        TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1e6 })
    copyAll.MouseButton1Click:Connect(function()
        local out = {}
        for i = #S.History, 1, -1 do out[#out + 1] = S.History[i].Code end
        if #out == 0 then toast("Nothing to copy", "History is empty", T.Warn) return end
        if clip(table.concat(out, "\n")) then toast("History copied", #out .. " codes", T.Good)
        else toast("Clipboard unavailable", "Your executor has no clipboard", T.Warn) end
    end)
    function clearHistory()
        S.History = {}
        for _, ch in ipairs(UI.historyList:GetChildren()) do if ch:IsA("CanvasGroup") then ch:Destroy() end end
        UI.histEmpty.Visible = true
    end
    clearBtn.MouseButton1Click:Connect(clearHistory)
end

-- ============================================================
--  PAGE: SETTINGS
-- ============================================================
do
    local p = pages.Settings.sf
    order = 0
    caption(p, "Appearance")
    local g, row = group(p)

    local ar = row(60)
    text(ar, { Text = "Accent color", Font = FONT_S, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 16) })
    local sw = {}
    for i, a in ipairs(Accents) do
        local b = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(14 + (i - 1) * 32, 31),
            BackgroundColor3 = a.Color, Parent = ar }, { corner(11), new("UIStroke", { Color = WHITE, Thickness = 2, Transparency = (i == Config.AccentIndex) and 0.05 or 1 }) })
        local sc = new("UIScale", { Scale = (i == Config.AccentIndex) and 1.12 or 1, Parent = b })
        sw[i] = { b = b, sc = sc }
        b.MouseButton1Click:Connect(function()
            Config.AccentIndex = i; saveConfig()
            for j, s in ipairs(sw) do
                tween(s.b.UIStroke, 0.25, { Transparency = (j == i) and 0.05 or 1 })
                tween(s.sc, 0.35, { Scale = (j == i) and 1.12 or 1 }, EASE_BACK)
            end
            setAccent(a.Color)
            toast("Theme", a.Name, a.Color)
        end)
    end
    sliderRow(row(56), "UI scale", 0.7, 1.3, Config.Scale, 2, function(v)
        Config.Scale = v; saveConfig(); tween(uiScale, 0.15, { Scale = v })
    end)
    sliderRow(row(56), "Window transparency", 0, 0.6, Config.Opacity, 2, function(v)
        Config.Opacity = v; saveConfig(); main.BackgroundTransparency = v
    end)

    caption(p, "General")
    local g2, row2 = group(p)
    toggleRow(row2(46), "Notifications", "Pop-ups for captures and redeems", Config.Toasts, function(v)
        Config.Toasts = v; saveConfig()
    end)
    toggleRow(row2(46), "Anti-AFK", "Prevents the idle kick", Config.AntiAfk, function(v)
        Config.AntiAfk = v; saveConfig(); toast("Anti-AFK", v and "Enabled" or "Disabled", v and T.Good or T.Warn)
    end)
    local kr = row2(46)
    text(kr, { Text = "Toggle keybind", Font = FONT_S, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -130, 0, 16) })
    text(kr, { Text = "Click, then press a key", TextSize = 10, TextColor3 = T.Sub, Position = UDim2.fromOffset(14, 25), Size = UDim2.new(1, -130, 0, 14) })
    local kb = makeButton(kr, Config.Keybind, UDim2.fromOffset(98, 26), UDim2.new(1, -112, 0.5, -13))
    local listening = false
    kb.MouseButton1Click:Connect(function() listening = true; kb.Text = "Press a key..." end)
    track(UIS.InputBegan:Connect(function(input)
        if listening and input.UserInputType == Enum.UserInputType.Keyboard then
            listening = false
            Config.Keybind = input.KeyCode.Name
            kb.Text = Config.Keybind
            saveConfig()
            toast("Keybind set", Config.Keybind, T.Accent)
        end
    end))

    local br = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = p })
    local reset = makeButton(br, "Reset settings", UDim2.new(0.5, -4, 1, 0), UDim2.fromOffset(0, 0))
    local unl = makeButton(br, "Unload", UDim2.new(0.5, -4, 1, 0), UDim2.new(0.5, 4, 0, 0), "danger")
    reset.MouseButton1Click:Connect(function()
        for k, v in pairs(Defaults) do Config[k] = v end
        saveConfig()
        toast("Settings reset", "Re-execute RumbleHub to apply", T.Warn)
    end)
    unl.MouseButton1Click:Connect(function() unload() end)
    text(p, { Text = "RumbleHub v2.1", Font = FONT_M, TextSize = 9, TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.new(1, 0, 0, 14), LayoutOrder = nextOrder() })
end

-- ============================================================
--  CORE ENGINE (code capture + redeem logic)
-- ============================================================
local getUpvalues = (debug and debug.getupvalues) or getupvalues
local getConns = getconnections or (debug and debug.getconnections)
local setUpvalue = (debug and debug.setupvalue) or setupvalue

local function isOwn(x)
    local y = x
    for _ = 1, 12 do
        if not y then break end
        if y.Name == GUI_NAME then return true end
        y = y.Parent
    end
    return false
end

local function isVisible(x)
    local y = x
    while y do
        if y:IsA("GuiObject") and not y.Visible then return false end
        if y:IsA("ScreenGui") then return y.Enabled end
        y = y.Parent
    end
    return true
end

local function collectTextBoxes(pg)
    local r = {}
    for _, g in ipairs(pg:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled and not isOwn(g) then
            for _, d in ipairs(g:GetDescendants()) do
                if d:IsA("TextBox") and not isOwn(d) then r[#r + 1] = d end
            end
        end
    end
    return r
end

local function collectCodeButtons(pg)
    local r = {}
    for _, g in ipairs(pg:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled and not isOwn(g) then
            for _, d in ipairs(g:GetDescendants()) do
                if (d:IsA("TextButton") or d:IsA("ImageButton")) and not isOwn(d) then
                    local n = d.Name:lower()
                    local pn = (d.Parent and d.Parent.Name or ""):lower()
                    if (n:find("code") or n:find("redeem") or pn:find("code") or pn:find("redeem")) and isVisible(d) then
                        r[#r + 1] = d
                    end
                end
            end
        end
    end
    return r
end

local function fireButton(b)
    if not b then return false end
    local methods = {}
    methods[#methods + 1] = function() b.MouseButton1Click:Fire() end
    methods[#methods + 1] = function() b.Activated:Fire() end
    if typeof(firesignal) == "function" then
        methods[#methods + 1] = function() firesignal(b.MouseButton1Click) end
        methods[#methods + 1] = function() firesignal(b.Activated) end
    end
    if typeof(getConns) == "function" then
        methods[#methods + 1] = function()
            for _, sig in ipairs({ b.MouseButton1Click, b.Activated }) do
                local ok, cs = pcall(getConns, sig)
                if ok and type(cs) == "table" then
                    for _, c in ipairs(cs) do pcall(function() c:Fire() end) end
                end
            end
        end
    end
    if typeof(fireclick) == "function" then methods[#methods + 1] = function() fireclick(b) end end
    local any = false
    for _, f in ipairs(methods) do
        local ok = pcall(f)
        any = any or ok
    end
    return any
end

local function fireFocusLost(box)
    if not box then return false end
    local any = false
    if typeof(firesignal) == "function" then
        local ok = pcall(firesignal, box.FocusLost, true)
        any = any or ok
    end
    if typeof(getConns) == "function" then
        local ok, cs = pcall(getConns, box.FocusLost)
        if ok and type(cs) == "table" then
            for _, c in ipairs(cs) do
                local fn
                pcall(function() fn = c.Function end)
                if fn and typeof(getUpvalues) == "function" and typeof(setUpvalue) == "function" then
                    local uok, ups = pcall(getUpvalues, fn)
                    if uok and type(ups) == "table" then
                        for i, v in pairs(ups) do
                            if type(v) == "boolean" and v == true then pcall(setUpvalue, fn, i, false) end
                        end
                    end
                end
                local fok = pcall(function() if c.Enabled ~= false then c:Fire(true) end end)
                any = any or fok
            end
        end
    end
    return any
end

local function findCodeBox()
    for _, b in ipairs(collectTextBoxes(PG)) do
        if isVisible(b) then return b end
    end
    return nil
end

local SUBMIT_WORDS = { "submit", "redeem", "claim", "confirm", "enter", "send", "apply", "ok", "use", "go", "check" }

function redeemCode(code)
    local pg = PG or LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return false, "no PlayerGui" end
    local delay = Config.SubmitDelay

    -- Path 1: dedicated "Codes" ScreenGui
    local cg = pg:FindFirstChild("Codes")
    if cg then
        if cg:IsA("ScreenGui") then cg.Enabled = true end
        local cf = cg:FindFirstChild("Codes") or cg
        if cf:IsA("GuiObject") then cf.Visible = true end
        local cur = cf
        while cur and cur ~= cg do
            if cur:IsA("GuiObject") then cur.Visible = true end
            cur = cur.Parent
        end
        local box, btn
        for _, d in ipairs(cf:GetDescendants()) do
            if d:IsA("TextBox") and not isOwn(d) then box = d break end
        end
        for _, d in ipairs(cf:GetDescendants()) do
            if (d:IsA("TextButton") or d:IsA("ImageButton")) and not isOwn(d) then
                local n = d.Name:lower()
                local t = ""
                pcall(function() t = d.Text:lower() end)
                if n:find("submit") or t:find("submit") or n:find("redeem") or t:find("redeem")
                    or n:find("claim") or t:find("confirm") or n:find("enter") then
                    btn = d break
                end
            end
        end
        if not btn then
            for _, d in ipairs(cf:GetDescendants()) do
                if (d:IsA("TextButton") or d:IsA("ImageButton")) and not isOwn(d) then
                    local n = d.Name:lower()
                    if not n:find("close") and not n:find("x") and not n:find("toggle") then btn = d break end
                end
            end
        end
        if box then
            pcall(function() box.Text = code end)
            task.wait(delay)
            if btn then fireButton(btn) end
            fireFocusLost(box)
            return true, "PlayerGui.Codes"
        end
    end

    -- Path 2: dynamic search
    for _, b in ipairs(collectCodeButtons(pg)) do
        fireButton(b)
        task.wait(delay)
    end
    task.wait(0.2)

    local box
    local deadline = os.clock() + 2
    while os.clock() < deadline do
        local all = collectTextBoxes(pg)
        for _, d in ipairs(all) do
            if isVisible(d) then
                local n = d.Name:lower()
                local pn = (d.Parent and d.Parent.Name or ""):lower()
                if n:find("code") or pn:find("code") or n:find("redeem") or pn:find("redeem")
                    or n:find("input") or pn:find("textbox") or n:find("enter") then
                    box = d break
                end
            end
        end
        if not box then
            for _, d in ipairs(all) do if isVisible(d) then box = d break end end
        end
        if box then break end
        task.wait(0.1)
    end
    if not box then return false, "no codebox visible" end

    pcall(function() box.Text = code end)
    task.wait(delay)

    local btn
    local p = box.Parent
    for _ = 1, 8 do
        if not p then break end
        for _, d in ipairs(p:GetDescendants()) do
            if (d:IsA("TextButton") or d:IsA("ImageButton")) and not isOwn(d) and d ~= box then
                local n = d.Name:lower()
                local t = ""
                pcall(function() t = d.Text:lower() end)
                for _, sn in ipairs(SUBMIT_WORDS) do
                    if (n:find(sn) or t:find(sn)) and isVisible(d) then btn = d break end
                end
                if btn then break end
            end
        end
        if btn then break end
        p = p.Parent
    end
    if btn then fireButton(btn) end
    fireFocusLost(box)
    return true, "dynamic search"
end

function pasteToBox(text)
    local box = findCodeBox()
    if not box then return false end
    pcall(function() box.Text = text end)
    return true
end

-- Wrap redeemCode so every redeem is tracked in stats/history
local rawRedeem = redeemCode
local lastEntry
redeemCode = function(code)
    local ok, msg = rawRedeem(code)
    if ok then
        S.Redeemed = S.Redeemed + 1
        lastEntry = addHistory(code, "Submitted", T.Warn)
        log("Redeemed: " .. code, T.Good)
        toast("Code submitted", code, T.Good)
    else
        S.Failed = S.Failed + 1
        lastEntry = addHistory(code, "Failed", T.Bad)
        log("Failed: " .. tostring(msg), T.Bad)
        toast("Redeem failed", tostring(msg), T.Bad)
    end
    refreshStats()
    return ok, msg
end

-- ---------- code box watching ----------
local function resetPending()
    S.Pending = {}
    refreshBuffer()
end

local function unwatch()
    if S.TextConn then pcall(function() S.TextConn:Disconnect() end) end
    if S.AncConn then pcall(function() S.AncConn:Disconnect() end) end
    for _, c in ipairs(S.OtherConns) do pcall(function() c:Disconnect() end) end
    S.TextConn, S.AncConn, S.OtherConns, S.Watched = nil, nil, {}, nil
end

local function watch(box)
    if not box or S.Watched == box then return end
    unwatch()
    S.Watched = box
    if box.Text ~= "" then S.LastTyped = box.Text end
    S.TextConn = box:GetPropertyChangedSignal("Text"):Connect(function()
        if box.Text == "" then resetPending() else S.LastTyped = box.Text end
    end)
    S.AncConn = box.AncestryChanged:Connect(function(_, parent)
        if not parent then resetPending(); unwatch() end
    end)
end

track(UIS.TextBoxFocused:Connect(function(box)
    if box:IsDescendantOf(gui) then return end
    if box ~= findCodeBox() then return end
    S.FocusedBox = box
    S.CodeBox = box
    watch(box)
    if Config.AutoCode then log("Code box ready", T.Good) end
end))

track(UIS.TextBoxFocusReleased:Connect(function(box)
    if box:IsDescendantOf(gui) then return end
    local cb = findCodeBox()
    if box ~= cb and box ~= S.CodeBox then return end
    if Config.RetypeInvalid and (box == cb or box == S.CodeBox) then
        local text = box.Text ~= "" and box.Text or S.LastTyped
        if S.RetryText and os.clock() <= S.RetryExpiry then return end
        S.RetryToken = S.RetryToken + 1
        local token = S.RetryToken
        S.RetryText, S.RetryBox, S.RetryExpiry = text, box, os.clock() + 8
        task.delay(8, function()
            if token == S.RetryToken then S.RetryText, S.RetryBox, S.RetryExpiry = nil, nil, 0 end
        end)
    end
    if S.FocusedBox == box then
        S.FocusedBox = nil
        if Config.AutoCode then
            if S.CodeBox and S.CodeBox.Parent then log("Code box ready", T.Good)
            else log("Click the code box first", T.Sub) end
        end
    end
end))

local function repaste(box, text)
    if not Config.RetypeInvalid or not text or text == "" then return false end
    RunService.Heartbeat:Wait()
    local cb = findCodeBox() or box
    if not cb or not isVisible(cb) then return false end
    local ok = pcall(function() cb.Text = text end)
    if ok then S.CodeBox = cb; watch(cb) end
    return ok
end

local REJECT = { "invalid code", "code is invalid", "expired", "already redeemed", "already used",
    "doesn't exist", "does not exist", "not found", "rejected" }

local function checkInvalid(text, obj)
    if not Config.RetypeInvalid or not S.RetryText then return end
    if os.clock() > S.RetryExpiry then S.RetryText, S.RetryBox, S.RetryExpiry = nil, nil, 0 return end
    if obj and obj:IsDescendantOf(gui) then return end
    local lower = tostring(text or ""):lower()
    local rejected = false
    for _, w in ipairs(REJECT) do
        if lower:find(w, 1, true) then rejected = true break end
    end
    if not rejected then return end
    local prevText, prevBox = S.RetryText, S.RetryBox
    local ok = repaste(prevBox, prevText)
    S.RetryText, S.RetryBox, S.RetryExpiry = nil, nil, 0
    if lastEntry then setEntryStatus(lastEntry, "Invalid", T.Bad) end
    if ok then log("Invalid, repasted: " .. prevText, T.Warn) end
end

local function watchLabel(obj)
    if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
    checkInvalid(obj.Text or "", obj)
    obj:GetPropertyChangedSignal("Text"):Connect(function() checkInvalid(obj.Text or "", obj) end)
end
for _, o in ipairs(PG:GetDescendants()) do watchLabel(o) end
track(PG.DescendantAdded:Connect(function(o) task.wait(0.04); watchLabel(o) end))

-- ---------- letter pipeline ----------
local function onLetter(text)
    if not text or text == "" or not Config.AutoCode then return end
    if S.Watched and not isVisible(S.Watched) then resetPending(); unwatch() end

    local box = findCodeBox()
    S.Pending[#S.Pending + 1] = text
    S.Captured = S.Captured + 1
    local combined = table.concat(S.Pending)
    local count = #S.Pending

    if box then
        S.CodeBox = box
        watch(box)
        local focused = UIS:GetFocusedTextBox() == box
        box.Text = combined
        if focused then
            pcall(function() local p = #combined + 1; box.CursorPosition = p; box.SelectionStart = p end)
        end
    else
        log("Captured; open the code menu", T.Sub)
    end
    log(string.format("Pasted %d/%d  (%s)", count, Config.SubmitAfter, text), T.Good)
    refreshBuffer()
    refreshStats()
    toast("Letter captured", text .. "   (" .. count .. "/" .. Config.SubmitAfter .. ")", T.Accent)

    if count >= Config.SubmitAfter then
        S.Pending = {}
        refreshBuffer()
        if Config.AutoSubmit then
            local ok, msg = redeemCode(combined)
            if not ok then
                if repaste(box, combined) then log("Re-pasted after failure: " .. combined, T.Warn) end
            end
        else
            log("Code ready: " .. combined .. " (auto submit off)", T.Warn)
            addHistory(combined, "Not sent", T.Sub)
            toast("Code ready", combined, T.Warn)
        end
    end
end

-- ---------- notification remote hook ----------
local WORDS_PER_PART = 1
local wordBuf = {}
local function stripTags(t)
    if type(t) ~= "string" then return tostring(t) end
    return (t:gsub("<[^>]->", ""))
end

local function onNotify(...)
    if not Config.AutoCode then return end
    local text = stripTags(tostring((...) or ""))
    text = text:match("^%s*(.-)%s*$") or ""
    if text == "" or text:find("%s") then return end
    for w in text:gmatch("[%w_]+") do wordBuf[#wordBuf + 1] = w end
    if #wordBuf < WORDS_PER_PART then return end
    local parts = {}
    for i = 1, math.min(#wordBuf, WORDS_PER_PART) do parts[i] = wordBuf[i] end
    wordBuf = {}
    local captured = table.concat(parts)
    if captured == "" or S.Seen[captured] then return end
    S.Seen[captured] = true
    task.delay(1.25, function() S.Seen[captured] = nil end)
    onLetter(captured)
end

local function findNotifyRemote()
    if _G.PhiNotifyRemote then return _G.PhiNotifyRemote end
    local pk = RepStorage:WaitForChild("Packages", 10)
    local net = pk and pk:WaitForChild("Net", 10)
    if not net then return nil end
    local info = debug and (debug.getinfo or debug.info)
    if getgc and info and getConns then
        for _, d in ipairs(net:GetDescendants()) do
            if d:IsA("RemoteEvent") then
                local ok, cs = pcall(getConns, d.OnClientEvent)
                if ok then
                    for _, c in ipairs(cs) do
                        local f, fn = pcall(function() return c.Function end)
                        if f and type(fn) == "function" then
                            local i, inf = pcall(info, fn)
                            if i and tostring(inf.short_src or inf.source or ""):find("NotificationController", 1, true) then
                                return d
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local notifyConn
local perfConn
task.spawn(function()
    local remote
    for _ = 1, 3 do
        local ok, r = pcall(findNotifyRemote)
        if ok and r then remote = r break end
        task.wait(2)
    end
    if remote then
        if getgenv then
            local prev = getgenv().RumbleHubNotifyConnection
            if prev then pcall(function() prev:Disconnect() end) end
        end
        notifyConn = remote.OnClientEvent:Connect(function(...) pcall(onNotify, ...) end)
        if getgenv then getgenv().RumbleHubNotifyConnection = notifyConn end
        S.RemoteHooked = true
        remoteText.Text = "Notify remote: hooked"
        remoteText.TextColor3 = T.Good
        log("Notification remote hooked", T.Good)
        toast("RumbleHub ready", "Listening for codes", T.Good)
    else
        remoteText.Text = "Remote not found (manual mode)"
        remoteText.TextColor3 = T.Warn
        log("Notify remote not found. Use the Manual tab.", T.Warn)
        toast("Remote not found", "Manual redeem still works", T.Warn)
    end
end)

-- ---------- master controls ----------
function setAuto(v)
    Config.AutoCode = v
    saveConfig()
    masterToggle.Render()
    if not v then resetPending() end
    log("Auto Code " .. (v and "ON" or "OFF"), v and T.Good or T.Bad)
    toast("Auto Code", v and "Enabled" or "Paused", v and T.Good or T.Bad)
end

-- anti-AFK
track(LP.Idled:Connect(function()
    if not Config.AntiAfk then return end
    pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end)
end))

-- ============================================================
--  WINDOW BEHAVIOR
-- ============================================================
-- Drag (header)
do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, root.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    track(UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
end

-- Minimize
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    tween(root, 0.45, { Size = UDim2.fromOffset(W, minimized and 46 or H) }, EASE_EXP)
end)

-- Floating bubble (show / hide, mobile friendly)
local bubble = new("TextButton", {
    Text = "R", Font = FONT_B, TextSize = 16, TextColor3 = WHITE, AutoButtonColor = false, BackgroundColor3 = T.Accent,
    Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 14, 0.5, -20), ZIndex = 50, Parent = gui,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(WHITE, 1.5, 0.75),
     new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190)) }) })
local bubbleScale = new("UIScale", { Parent = bubble })
onAccent(function(c) bubble.BackgroundColor3 = c; bubble.TextColor3 = (lum(c) > 0.62) and Color3.fromRGB(22, 22, 22) or WHITE end)
bubble.MouseEnter:Connect(function() tween(bubbleScale, 0.2, { Scale = 1.1 }, EASE_BACK) end)
bubble.MouseLeave:Connect(function() tween(bubbleScale, 0.25, { Scale = 1 }) end)

local visible = true
local function setVisible(v)
    visible = v
    if v then
        root.Visible = true
        tween(uiScale, 0.5, { Scale = Config.Scale }, EASE_BACK)
    else
        tween(uiScale, 0.22, { Scale = 0.88 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(0.22, function() if not visible then root.Visible = false end end)
    end
end
bubble.MouseButton1Click:Connect(function() setVisible(not visible) end)
track(UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == Config.Keybind then
        setVisible(not visible)
    end
end))
closeBtn.MouseButton1Click:Connect(function()
    setVisible(false)
    toast("RumbleHub hidden", "Tap the R bubble or press " .. Config.Keybind, T.Sub)
end)

-- Unload
function unload()
    toast("RumbleHub", "Unloading...", T.Bad)
    task.wait(0.35)
    unwatch()
    if notifyConn then pcall(function() notifyConn:Disconnect() end) end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    if perfConn then pcall(function() perfConn:Disconnect() end) end
    if gui then gui:Destroy() end
    if getgenv then
        getgenv().RumbleHubUnload = nil
        getgenv().StopAura = nil
    end
end
if getgenv then
    getgenv().RumbleHubUnload = unload
    getgenv().StopAura = unload           -- keeps the old stop command working
end

-- ============================================================
--  LIVE UPDATES (fps, ping, uptime, border + status pulse)
-- ============================================================
local function fmtUptime(sec)
    sec = math.floor(sec)
    if sec >= 3600 then return string.format("%dh%02d", math.floor(sec / 3600), math.floor(sec / 60) % 60) end
    return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
end

local frames, lastTick = 0, os.clock()
perfConn = RunService.Heartbeat:Connect(function(dt)
    frames = frames + 1
    borderGrad.Rotation = (borderGrad.Rotation + dt * 45) % 360
    if UI.dot and Config.AutoCode then
        UI.dot.BackgroundTransparency = 0.45 + 0.45 * math.sin(os.clock() * 3)
    elseif UI.dot then
        UI.dot.BackgroundTransparency = 0
    end
    local now = os.clock()
    if now - lastTick >= 1 then
        local fps = math.floor(frames / (now - lastTick) + 0.5)
        frames, lastTick = 0, now
        local ping = 0
        pcall(function()
            ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
        end)
        perf.Text = fps .. " fps | " .. ping .. " ms"
        UI.stat.Uptime.Text = fmtUptime(now - S.StartTime)
    end
end)

-- ============================================================
--  START
-- ============================================================
masterToggle.Render()
refreshStats()
refreshBuffer()
selectTab("Home")
uiScale.Scale = 0.88
tween(uiScale, 0.7, { Scale = Config.Scale }, EASE_BACK)
log("RumbleHub v2.1 loaded", T.Accent)
log("Waiting for code letters...", T.Sub)
