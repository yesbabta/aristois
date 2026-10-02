-- ============================================================
-- NOBLACK HUB LITE v1.0
-- Stripped build: Fast Hits / Spam / Aim / KillAura / Magnet / Anim
-- ============================================================
-- ============================================================
-- XENO EXECUTOR COMPATIBILITY HEADER
-- ============================================================
do
    -- 1. Определяем исполнитель
    local EXEC_NAME = "unknown"
    pcall(function()
        if identifyexecutor then EXEC_NAME = tostring(identifyexecutor()) end
    end)
    local IS_XENO = EXEC_NAME:lower():find("xeno") ~= nil
    getgenv().EXEC_NAME = EXEC_NAME
    getgenv().IS_XENO  = IS_XENO

    -- 2. Универсальный HttpGet (Xeno / Synapse / KRNL / Solara / Wave)
    local function HttpGet(url)
        if game.HttpGet then
            local ok, r = pcall(function() return game:HttpGet(url) end)
            if ok and type(r) == "string" and #r > 0 then return r end
        end
        if request then
            local ok, r = pcall(function() return request({ Url = url, Method = "GET" }).Body end)
            if ok and type(r) == "string" and #r > 0 then return r end
        end
        if syn and syn.request then
            local ok, r = pcall(function() return syn.request({ Url = url, Method = "GET" }).Body end)
            if ok and type(r) == "string" and #r > 0 then return r end
        end
        if httpget then
            local ok, r = pcall(function() return httpget(url) end)
            if ok and type(r) == "string" and #r > 0 then return r end
        end
        error("[noblack lite] HTTP GET failed: " .. tostring(url))
    end
    getgenv().HttpGet = HttpGet

    -- 3. Fallback для Drawing API (если Xeno без Drawing)
    if not Drawing or not Drawing.new then
        warn("[noblack lite] Drawing API не найден — визуал (FOV круг, Range Indicator) будет отключён")
        local stub = {}
        stub.new = function(t)
            return setmetatable({ Type = t, Visible = false, __stub = true }, {
                __index    = function(_, k) return rawget(stub, k) end,
                __newindex = function() end,
            })
        end
        stub.clear = function() end
        getgenv().Drawing = stub
    end

    -- 4. Безопасный loadstring
    local LS = loadstring or load
    if not LS then
        error("[noblack lite] loadstring недоступен — запусти скрипт в Xeno, а не в обычной консоли")
    end
    getgenv().SafeLoadstring = function(code, name)
        return LS(code, name or "=noblack_lite")
    end
end
-- ============================================================
-- END XENO COMPATIBILITY HEADER
-- ============================================================
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local START_TIME = tick()

-- Cleanup old instances
pcall(function()
    for _, g in ipairs(CoreGui:GetChildren()) do
        if g.Name:find("noblackhub") then g:Destroy() end
    end
end)
pcall(function()
    local pg = player:FindFirstChild("PlayerGui")
    if pg then
        for _, g in ipairs(pg:GetChildren()) do
            if g.Name:find("noblackhub") then g:Destroy() end
        end
    end
end)

-- Metrics
local FPS = 0
local frameCount = 0
local lastFpsCheck = tick()
RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    if tick() - lastFpsCheck >= 1 then
        FPS = frameCount
        frameCount = 0
        lastFpsCheck = tick()
    end
end)

local Ping = 0
task.spawn(function()
    while true do
        pcall(function()
            local p = Stats.Network.ServerStatsItem["Data Ping"]
            if p then Ping = math.floor(p:GetValue()) end
        end)
        task.wait(0.5)
    end
end)

-- Packet + FistRemote
local Packet = require(RS:WaitForChild("Packet", 10))
local FistRemote = Packet("FistRemote", "String", "Any", "Any", "Any", "Any", "Any")
local PlayerSettings = Players:WaitForChild("PlayerSettings", 10)

-- Collections (declared early for forward refs)
local Magnets = {}
local ESPObjects = {}

-- Limited themes / accents / fonts
local THEMES = {"Dark", "Light", "Midnight", "Rose", "Crimson"}

local ACCENTS = {
    Red    = Color3.fromRGB(255, 60, 60),
    Pink   = Color3.fromRGB(255, 95, 174),
    Purple = Color3.fromRGB(124, 92, 255),
    Blue   = Color3.fromRGB(60, 130, 255),
    Cyan   = Color3.fromRGB(34, 224, 212),
    Green  = Color3.fromRGB(60, 200, 100),
    Yellow = Color3.fromRGB(255, 220, 40),
    Orange = Color3.fromRGB(255, 140, 0),
    White  = Color3.fromRGB(255, 255, 255),
    Grey   = Color3.fromRGB(160, 160, 160),
}

local FONTS = {"Gotham","GothamBold","GothamBlack","SourceSans","Roboto","Code","Ubuntu","Arial"}

-- ============================================================
-- SETTINGS (stripped)
-- ============================================================
local settings = {
    -- Aim
    aimEnabled = false, hardLock = false, teamCheck = true,
    aimPart = "Head", currentBind = Enum.KeyCode.R,
    aimMode = "Toggle", alwaysOn = true,
    radius = 200, customVisualColor = Color3.fromRGB(124, 92, 255),
    predictiveAim = false, predictiveTime = 0.15,
    toggleState = false, holdState = false, lockedTarget = nil,

    -- Fast hits (max delay 300)
    fastHits = false, hitDelay = 100,
    fastHitEnabled = false, fastHitDelay = 300,

    -- Spam
    hitESpam = false, hitESpamDelay = 400,
    hitQSpam = false, hitQSpamDelay = 400,
    hitLMBSpam = false, hitLMBSpamDelay = 400,
    hitFSpam = false, hitFSpamDelay = 400,
    mixedSpam = false, mixedSpamDelay = 400, mixedIdx = 1,

    -- Kill aura
    killAura = false, killAuraRange = 20, killAuraDelay = 150,
    killAuraTeamCheck = true, killAuraAutoFace = true,

    -- Magnet (size max 15, range max 50)
    magnet = false, showHitbox = true, magnetSize = 10, magnetRange = 25,

    -- Anim (max 3)
    animSpeedEnabled = false, animSpeed = 1.5,

    -- ESP
    espBoxes = false,

    -- Misc
    autoEquip = true,
    soundOnToggle = true, notifications = true,
    currentTheme = "Dark", currentAccent = "Purple", currentFont = "Gotham",

    rangeIndicator = false,
}

-- Drawing
local circle = Drawing.new("Circle")
circle.Visible = false
circle.Radius = settings.radius
circle.Thickness = 1.5
circle.Filled = false
circle.Color = Color3.fromRGB(255, 255, 255)
circle.Transparency = 1

local rangeCircle = Drawing.new("Circle")
rangeCircle.Visible = false
rangeCircle.Radius = 90
rangeCircle.Thickness = 2
rangeCircle.Filled = false
rangeCircle.Color = Color3.fromRGB(255, 180, 60)
rangeCircle.Transparency = 0.9

-- ============================================================
-- HELPERS
-- ============================================================
local function isAlive(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end
local function getCenter() return camera.ViewportSize / 2 end
local function insideCircle(sp)
    return (getCenter() - Vector2.new(sp.X, sp.Y)).Magnitude <= settings.radius
end
local function isEnemy(plr)
    if not settings.teamCheck then return true end
    if not plr.Team then return true end
    if player.Team and plr.Team == player.Team then return false end
    return true
end
local function getAimPart(char)
    local pn = settings.aimPart
    if pn == "Random" then
        local parts = {"Head","UpperTorso","LowerTorso","Torso"}
        pn = parts[math.random(1,#parts)]
    elseif pn == "Chest" then pn = "UpperTorso"
    elseif pn == "Body" then pn = "LowerTorso" end
    local part = char:FindFirstChild(pn)
    if not part then
        part = char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    end
    return part
end
local function getTarget()
    if settings.hardLock and settings.lockedTarget then
        local part = settings.lockedTarget
        local char = part.Parent
        if char and isAlive(char) then return part end
        settings.lockedTarget = nil
    end
    local nearest, minDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local char = plr.Character
            local part = getAimPart(char)
            if part and isAlive(char) and isEnemy(plr) then
                local sp, on = camera:WorldToViewportPoint(part.Position)
                if on and insideCircle(sp) then
                    local d = (Vector2.new(sp.X,sp.Y) - getCenter()).Magnitude
                    if d < minDist then minDist = d; nearest = part end
                end
            end
        end
    end
    if nearest and settings.hardLock then settings.lockedTarget = nearest end
    return nearest
end
local function snapAim(pos)
    local aimPos = pos
    if settings.predictiveAim and settings.lockedTarget then
        local part = settings.lockedTarget
        if part and part.AssemblyLinearVelocity then
            aimPos = pos + part.AssemblyLinearVelocity * settings.predictiveTime
        end
    end
    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, aimPos)
end

-- Sound
local SOUND_ON = "rbxassetid://6042053626"
local function playSound(pitch, vol)
    if not settings.soundOnToggle then return end
    local s = Instance.new("Sound")
    s.SoundId = SOUND_ON
    s.Volume = vol or 0.15
    s.PlaybackSpeed = (pitch and pitch / 300) or 1.2
    s.PlayOnRemove = true
    s.Parent = CoreGui
    s:Play()
    task.delay(1, function() s:Destroy() end)
end

-- ============================================================
-- WINDUI
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

pcall(function()
    WindUI:AddTheme({
        Name = "NoBlackLite",
        Accent = Color3.fromHex("#7C5CFF"),
        Background = Color3.fromHex("#0A0A0F"),
        Outline = Color3.fromHex("#FFFFFF"),
        Text = Color3.fromHex("#F0F0FF"),
        Placeholder = Color3.fromHex("#6B6B80"),
        Button = Color3.fromHex("#1A1A2E"),
        Icon = Color3.fromHex("#A1A1AA"),
    })
end)

local Window = WindUI:CreateWindow({
    Title = "noblack hub LITE",
    Icon = "rbxassetid://97479647106054",
    IconSize = 20,
    ToggleKey = Enum.KeyCode.RightShift,
    Size = UDim2.fromOffset(700, 540),
    MinSize = Vector2.new(560, 440),
    MaxSize = Vector2.new(1000, 800),
    Transparent = false,
    Acrylic = true,
    Resizable = true,
    SideBarWidth = 180,
    HideSearchBar = true,
    AutoScale = true,
    Folder = "noblackhub",
    User = { Enabled = false },
    Theme = "NoBlackLite",
})

pcall(function() WindUI:SetTheme("NoBlackLite") end)
pcall(function() WindUI:SetTheme({ Accent = Color3.fromRGB(124, 92, 255) }) end)

local function toast(msg)
    if not settings.notifications then return end
    pcall(function()
        WindUI:Notify({ Title = "noblack lite", Content = msg, Duration = 2.5 })
    end)
end

local function applyFont(fontName)
    settings.currentFont = fontName
    local enumFont = Enum.Font[fontName] or Enum.Font.Gotham
    pcall(function()
        local gui = WindUI.ScreenGui
        if not gui then return end
        for _, obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                obj.Font = enumFont
            end
        end
    end)
    toast("Font: " .. fontName)
end

local function applyAccent(name)
    local color = ACCENTS[name]
    if not color then return end
    settings.customVisualColor = color
    settings.currentAccent = name
    pcall(function() WindUI:SetTheme({ Accent = color }) end)
    toast("Accent: " .. name)
end

local function applyTheme(name)
    settings.currentTheme = name
    pcall(function() WindUI:SetTheme(name) end)
    toast("Theme: " .. name)
end

-- ============================================================
-- TABS
-- ============================================================

-- AIM
local AimTab = Window:Tab({ Title = "Aim", Icon = "crosshair" })
AimTab:Section({ Title = "Aim Settings", Opened = true })
AimTab:Toggle({ Title = "Enable Aim", Value = false, Callback = function(v)
    settings.aimEnabled = v
    if not v then
        settings.toggleState = false
        settings.holdState = false
        settings.lockedTarget = nil
    end
end })
AimTab:Toggle({ Title = "Always On", Value = true, Callback = function(v) settings.alwaysOn = v end })
AimTab:Toggle({ Title = "Hard Lock", Value = false, Callback = function(v) settings.hardLock = v end })
AimTab:Toggle({ Title = "Team Check", Value = true, Callback = function(v) settings.teamCheck = v end })
AimTab:Toggle({ Title = "Predictive Aim", Value = false, Callback = function(v) settings.predictiveAim = v end })
AimTab:Slider({ Title = "Predictive Time (ms)", Step = 1, Value = { Min = 50, Max = 400, Default = 150 },
    Callback = function(v) settings.predictiveTime = v / 1000 end })
AimTab:Dropdown({ Title = "Aim Part", Values = {"Head","Chest","Body","Random"}, Value = "Head",
    Callback = function(v) settings.aimPart = v end })
AimTab:Dropdown({ Title = "Bind", Values = {"R","E","F","Q","Shift","L-Ctrl"}, Value = "R",
    Callback = function(v)
        local map = {R=Enum.KeyCode.R,E=Enum.KeyCode.E,F=Enum.KeyCode.F,Q=Enum.KeyCode.Q,Shift=Enum.KeyCode.LeftShift,["L-Ctrl"]=Enum.KeyCode.LeftControl}
        if map[v] then settings.currentBind = map[v] end
    end })
AimTab:Dropdown({ Title = "Mode", Values = {"Toggle","Hold"}, Value = "Toggle",
    Callback = function(v)
        settings.aimMode = v
        settings.toggleState = false
        settings.holdState = false
    end })

-- VISUALS
local VisualsTab = Window:Tab({ Title = "Visuals", Icon = "eye" })
VisualsTab:Section({ Title = "Aim Visuals", Opened = true })
VisualsTab:Slider({ Title = "FOV Radius", Step = 1, Value = { Min = 30, Max = 500, Default = 200 },
    Callback = function(v) settings.radius = v; circle.Radius = v end })
VisualsTab:Toggle({ Title = "Range Indicator", Value = false, Callback = function(v)
    settings.rangeIndicator = v
    rangeCircle.Visible = v
end })
VisualsTab:Section({ Title = "ESP" })
VisualsTab:Toggle({ Title = "ESP 3D Boxes", Value = false, Callback = function(v) settings.espBoxes = v end })

-- FAST HITS
local FightTab = Window:Tab({ Title = "Fast Hits", Icon = "sword" })
FightTab:Section({ Title = "Fast Hits", Opened = true })
FightTab:Toggle({ Title = "Enable Fast Hits", Value = false, Callback = function(v) settings.fastHits = v end })
FightTab:Slider({ Title = "Hit Delay (ms)", Step = 1, Value = { Min = 1, Max = 300, Default = 100 },
    Callback = function(v) settings.hitDelay = v end })
FightTab:Toggle({ Title = "Auto-Equip Fists", Value = true, Callback = function(v) settings.autoEquip = v end })
FightTab:Button({ Title = "Quick Hit x20", Callback = function()
    for i = 1, 20 do
        local char = player.Character
        if char and char:FindFirstChild("Fists") and player:GetAttribute("canAttack") ~= false then
            pcall(function() FistRemote:Fire("lmb") end)
        end
        task.wait(0.005)
    end
    toast("20 hits")
end })
FightTab:Section({ Title = "Fast-Hit v2" })
FightTab:Toggle({ Title = "Fast-Hit v2", Value = false, Callback = function(v) settings.fastHitEnabled = v end })
FightTab:Slider({ Title = "Fast-Hit Delay (ms)", Step = 10, Value = { Min = 10, Max = 300, Default = 300 },
    Callback = function(v) settings.fastHitDelay = v end })

-- ATTACK MODES
local AttackTab = Window:Tab({ Title = "Attack Modes", Icon = "zap" })
AttackTab:Section({ Title = "Hit E Spam (Low Kick)", Opened = true })
AttackTab:Toggle({ Title = "Hit E Spam", Value = false, Callback = function(v) settings.hitESpam = v end })
AttackTab:Slider({ Title = "E Delay (ms)", Step = 10, Value = { Min = 100, Max = 2000, Default = 400 },
    Callback = function(v) settings.hitESpamDelay = v end })
AttackTab:Section({ Title = "Hit Q Spam (High Kick)" })
AttackTab:Toggle({ Title = "Hit Q Spam", Value = false, Callback = function(v) settings.hitQSpam = v end })
AttackTab:Slider({ Title = "Q Delay (ms)", Step = 10, Value = { Min = 100, Max = 2000, Default = 400 },
    Callback = function(v) settings.hitQSpamDelay = v end })
AttackTab:Section({ Title = "Hit LMB Spam (Punch)" })
AttackTab:Toggle({ Title = "Hit LMB Spam", Value = false, Callback = function(v) settings.hitLMBSpam = v end })
AttackTab:Slider({ Title = "LMB Delay (ms)", Step = 10, Value = { Min = 100, Max = 2000, Default = 400 },
    Callback = function(v) settings.hitLMBSpamDelay = v end })
AttackTab:Section({ Title = "Hit F Spam (Block)" })
AttackTab:Toggle({ Title = "Hit F Spam", Value = false, Callback = function(v) settings.hitFSpam = v end })
AttackTab:Slider({ Title = "F Delay (ms)", Step = 10, Value = { Min = 50, Max = 1000, Default = 400 },
    Callback = function(v) settings.hitFSpamDelay = v end })
AttackTab:Section({ Title = "Mixed Rotation" })
AttackTab:Toggle({ Title = "Mixed (lmb/q/e rotation)", Value = false, Callback = function(v) settings.mixedSpam = v end })
AttackTab:Slider({ Title = "Mixed Delay (ms)", Step = 10, Value = { Min = 100, Max = 2000, Default = 400 },
    Callback = function(v) settings.mixedSpamDelay = v end })
AttackTab:Button({ Title = "Disable ALL Spam Modes", Callback = function()
    settings.hitESpam = false; settings.hitQSpam = false
    settings.hitLMBSpam = false; settings.hitFSpam = false; settings.mixedSpam = false
    toast("All spam OFF")
end })

-- KILL AURA
local KATab = Window:Tab({ Title = "Kill Aura", Icon = "swords" })
KATab:Section({ Title = "Kill Aura", Opened = true })
KATab:Toggle({ Title = "Enable Kill Aura", Value = false, Callback = function(v)
    settings.killAura = v
    toast("Kill Aura: " .. (v and "ON" or "OFF"))
end })
KATab:Slider({ Title = "Speed Delay (ms)", Step = 10, Value = { Min = 30, Max = 2000, Default = 150 },
    Callback = function(v) settings.killAuraDelay = v end })
KATab:Slider({ Title = "Range (studs)", Step = 1, Value = { Min = 5, Max = 100, Default = 20 },
    Callback = function(v) settings.killAuraRange = v end })
KATab:Toggle({ Title = "Team Check", Value = true, Callback = function(v) settings.killAuraTeamCheck = v end })
KATab:Toggle({ Title = "Auto-Face Target", Value = true, Callback = function(v) settings.killAuraAutoFace = v end })

-- MAGNET (limited)
local MagTab = Window:Tab({ Title = "Magnet", Icon = "magnet" })
MagTab:Section({ Title = "Head Magnet", Opened = true })
MagTab:Toggle({ Title = "Magnet (Head Hitbox)", Value = false, Callback = function(v)
    settings.magnet = v
    if not v then
        for p, m in pairs(Magnets) do
            if m then pcall(function() m:Destroy() end) end
            Magnets[p] = nil
        end
    end
end })
MagTab:Toggle({ Title = "Show Hitboxes", Value = true, Callback = function(v)
    settings.showHitbox = v
    for _, m in pairs(Magnets) do
        if m and m.Parent then m.Transparency = v and 0.8 or 1 end
    end
end })
MagTab:Slider({ Title = "Magnet Size", Step = 1, Value = { Min = 2, Max = 15, Default = 10 },
    Callback = function(v) settings.magnetSize = v end })
MagTab:Slider({ Title = "Magnet Range", Step = 1, Value = { Min = 5, Max = 50, Default = 25 },
    Callback = function(v) settings.magnetRange = v end })

-- ANIM SPEED (limited)
local AnimTab = Window:Tab({ Title = "Anim Speed", Icon = "fast-forward" })
AnimTab:Section({ Title = "Animation Speed", Opened = true })
AnimTab:Toggle({ Title = "Anim Speed", Value = false, Callback = function(v)
    settings.animSpeedEnabled = v
    if not v then
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            for _, t in ipairs(hum:GetPlayingAnimationTracks()) do
                pcall(function() t:AdjustSpeed(1) end)
            end
        end
    end
end })
AnimTab:Slider({ Title = "Anim Speed (x)", Step = 0.1, Value = { Min = 0.5, Max = 3, Default = 1.5 },
    Callback = function(v) settings.animSpeed = v end })

-- THEME (limited)
local ThemeTab = Window:Tab({ Title = "Theme", Icon = "palette" })
ThemeTab:Section({ Title = "Theme", Opened = true })
local accentNames = {}
for k in pairs(ACCENTS) do table.insert(accentNames, k) end
table.sort(accentNames)
ThemeTab:Dropdown({ Title = "UI Theme", Values = THEMES, Value = "Dark",
    SearchBarEnabled = false, MenuWidth = 200,
    Callback = function(v) applyTheme(v) end })
ThemeTab:Dropdown({ Title = "Accent Color", Values = accentNames, Value = "Purple",
    SearchBarEnabled = false, MenuWidth = 220,
    Callback = function(v) applyAccent(v) end })
ThemeTab:Dropdown({ Title = "Font", Values = FONTS, Value = "Gotham",
    SearchBarEnabled = false, MenuWidth = 200,
    Callback = function(v) applyFont(v) end })

-- KEYBINDS
local KeybindTab = Window:Tab({ Title = "Keybinds", Icon = "keyboard" })
KeybindTab:Section({ Title = "Bind Actions", Opened = true })
local KEY_OPTIONS = {"None","Z","X","C","V","B","N","M","K","L","G","H","J","U","I","O","P","Y","T","Tab","F1","F2","F3","F4","F5","F6"}
local keybinds = {}
local function addBind(name, settingKey)
    local bind = {name = name, setting = settingKey, key = nil}
    table.insert(keybinds, bind)
    KeybindTab:Dropdown({
        Title = name, Values = KEY_OPTIONS, Value = "None",
        Callback = function(v)
            if v == "None" then bind.key = nil
            else bind.key = Enum.KeyCode[v] end
        end
    })
end
addBind("Fast Hits", "fastHits")
addBind("Kill Aura", "killAura")
addBind("Hit E Spam", "hitESpam")
addBind("Hit Q Spam", "hitQSpam")
addBind("Hit LMB Spam", "hitLMBSpam")
addBind("Hit F Spam", "hitFSpam")
addBind("Mixed Spam", "mixedSpam")
addBind("Magnet", "magnet")
addBind("Anim Speed", "animSpeedEnabled")

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    for _, b in ipairs(keybinds) do
        if b.key and input.KeyCode == b.key then
            settings[b.setting] = not settings[b.setting]
            toast(b.name .. ": " .. (settings[b.setting] and "ON" or "OFF"))
            playSound(settings[b.setting] and 500 or 200, 0.15)
        end
    end
end)

-- EXTRAS
local ExtrasTab = Window:Tab({ Title = "Extras", Icon = "settings" })
ExtrasTab:Section({ Title = "Options", Opened = true })
ExtrasTab:Toggle({ Title = "Sound on Toggle", Value = true, Callback = function(v) settings.soundOnToggle = v end })
ExtrasTab:Toggle({ Title = "Notifications", Value = true, Callback = function(v) settings.notifications = v end })
ExtrasTab:Section({ Title = "Info" })
ExtrasTab:Paragraph({ Title = "noblack hub LITE v1.0", Content = "Lightweight — fast hits, spam, magnet, anim" })

-- ============================================================
-- LOGIC
-- ============================================================

-- Auto-equip fists
local function equipFistsOnce()
    task.wait(0.5)
    if not settings.autoEquip then return end
    local char = player.Character
    if not char then return end
    if char:FindFirstChild("Fists") then return end
    local bp = player:FindFirstChild("Backpack")
    local tool = bp and bp:FindFirstChild("Fists")
    if tool then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:EquipTool(tool) end) end
    end
end
player.CharacterAdded:Connect(equipFistsOnce)
if player.Character then equipFistsOnce() end

-- Fast hits
task.spawn(function()
    while true do
        if settings.fastHits then
            local char = player.Character
            if char and char:FindFirstChild("Fists") and player:GetAttribute("canAttack") ~= false then
                pcall(function() FistRemote:Fire("lmb") end)
            end
            task.wait(settings.hitDelay / 1000)
        else
            task.wait(0.05)
        end
    end
end)

-- Fast hit v2
task.spawn(function()
    while true do
        if settings.fastHitEnabled then
            local char = player.Character
            if char and char:FindFirstChild("Fists") and player:GetAttribute("canAttack") ~= false then
                pcall(function() FistRemote:Fire("lmb") end)
            end
            task.wait(settings.fastHitDelay / 1000)
        else
            task.wait(0.1)
        end
    end
end)

-- Spam modes
task.spawn(function()
    while task.wait(0.02) do
        if player:GetAttribute("canAttack") == false then
        elseif settings.killAura then
            task.wait(0.01)
        elseif settings.hitESpam then
            pcall(function() FistRemote:Fire("keypress", "e") end)
            task.wait(settings.hitESpamDelay / 1000)
        elseif settings.hitQSpam then
            pcall(function() FistRemote:Fire("keypress", "q") end)
            task.wait(settings.hitQSpamDelay / 1000)
        elseif settings.hitLMBSpam then
            pcall(function() FistRemote:Fire("lmb") end)
            task.wait(settings.hitLMBSpamDelay / 1000)
        elseif settings.hitFSpam then
            pcall(function() FistRemote:Fire("keypress", "f") end)
            task.wait(settings.hitFSpamDelay / 1000)
        elseif settings.mixedSpam then
            local modes = {"lmb", "q", "e"}
            local mode = modes[settings.mixedIdx or 1]
            if mode == "lmb" then
                pcall(function() FistRemote:Fire("lmb") end)
            else
                pcall(function() FistRemote:Fire("keypress", mode) end)
            end
            settings.mixedIdx = ((settings.mixedIdx or 1) % 3) + 1
            task.wait(settings.mixedSpamDelay / 1000)
        else
            task.wait(0.1)
        end
    end
end)

-- Kill aura
task.spawn(function()
    while task.wait(0.01) do
        if settings.killAura then
            local myChar = player.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myRoot and player:GetAttribute("canAttack") ~= false then
                local closest, minDist = nil, settings.killAuraRange
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= player and p.Character then
                        if not settings.killAuraTeamCheck or isEnemy(p) then
                            local hum = p.Character:FindFirstChildOfClass("Humanoid")
                            local eRoot = p.Character:FindFirstChild("HumanoidRootPart")
                            if hum and hum.Health > 0 and eRoot then
                                local d = (myRoot.Position - eRoot.Position).Magnitude
                                if d < minDist then minDist = d; closest = p end
                            end
                        end
                    end
                end
                if closest then
                    local eRoot = closest.Character and closest.Character:FindFirstChild("HumanoidRootPart")
                    if eRoot and settings.killAuraAutoFace then
                        pcall(function()
                            myRoot.CFrame = CFrame.new(myRoot.Position, Vector3.new(eRoot.Position.X, myRoot.Position.Y, eRoot.Position.Z))
                        end)
                    end
                    if myChar:FindFirstChild("Fists") then
                        pcall(function() FistRemote:Fire("lmb") end)
                    else
                        local bp = player:FindFirstChild("Backpack")
                        local tool = bp and bp:FindFirstChild("Fists")
                        local hum = myChar:FindFirstChildOfClass("Humanoid")
                        if tool and hum then pcall(function() hum:EquipTool(tool) end) end
                    end
                end
            end
            task.wait(settings.killAuraDelay / 1000)
        else
            task.wait(0.05)
        end
    end
end)

-- Anim speed
local AnimHum, AnimConn
local SKIP_KEYWORDS = { "walk","run","idle","jump","fall","climb","swim" }
local function IsWalkAnim(track)
    local name = (track.Name or ""):lower()
    local id = ""
    pcall(function()
        if track.Animation then id = tostring(track.Animation.AnimationId or ""):lower() end
    end)
    for _, w in ipairs(SKIP_KEYWORDS) do
        if name:find(w) or id:find(w) then return true end
    end
    return false
end
local function OnAnimPlayed(track)
    if not settings.animSpeedEnabled then return end
    task.delay(0.02, function()
        if not settings.animSpeedEnabled then return end
        if IsWalkAnim(track) then return end
        if not (player.Character and player.Character:FindFirstChild("Fists")) then return end
        pcall(function() track:AdjustSpeed(settings.animSpeed) end)
    end)
end
player.CharacterAdded:Connect(function(c)
    task.wait(0.3)
    AnimHum = c:FindFirstChildOfClass("Humanoid")
    if AnimConn then AnimConn:Disconnect() end
    if AnimHum then AnimConn = AnimHum.AnimationPlayed:Connect(OnAnimPlayed) end
end)
if player.Character then
    AnimHum = player.Character:FindFirstChildOfClass("Humanoid")
    if AnimHum then AnimConn = AnimHum.AnimationPlayed:Connect(OnAnimPlayed) end
end

task.spawn(function()
    while true do
        if settings.animSpeedEnabled and AnimHum then
            local char = player.Character
            if char and char:FindFirstChild("Fists") then
                for _, track in ipairs(AnimHum:GetPlayingAnimationTracks()) do
                    if not IsWalkAnim(track) then
                        pcall(function() track:AdjustSpeed(settings.animSpeed) end)
                    end
                end
            end
        end
        task.wait(0.1)
    end
end)

-- Magnet
local function createMagnetFor(target)
    local char = target.Character
    if not char then return end
    if Magnets[target] and Magnets[target].Parent then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    local magnet = Instance.new("Part")
    magnet.Name = "MagnetHitbox"
    magnet.Size = Vector3.new(settings.magnetSize, settings.magnetSize, settings.magnetSize)
    magnet.CFrame = head.CFrame
    magnet.Shape = Enum.PartType.Ball
    magnet.Transparency = settings.showHitbox and 0.8 or 1
    magnet.CanCollide = false
    magnet.Anchored = false
    magnet.Massless = true
    magnet.Color = Color3.fromRGB(255, 60, 60)
    magnet.Material = Enum.Material.Neon
    magnet.Parent = workspace
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = head
    weld.Part1 = magnet
    weld.Parent = magnet
    Magnets[target] = magnet
end
local function removeMagnetFor(target)
    if Magnets[target] then
        pcall(function() Magnets[target]:Destroy() end)
        Magnets[target] = nil
    end
end

task.spawn(function()
    while task.wait(0.2) do
        if settings.magnet then
            local myChar = player.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local closest, minDist = nil, settings.magnetRange
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= player and p.Character then
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        local eRoot = p.Character:FindFirstChild("HumanoidRootPart")
                        if hum and hum.Health > 0 and eRoot then
                            local d = (myRoot.Position - eRoot.Position).Magnitude
                            if d < minDist then minDist = d; closest = p end
                        end
                    end
                end
                for p, _ in pairs(Magnets) do
                    if p ~= closest then removeMagnetFor(p) end
                end
                if closest then
                    createMagnetFor(closest)
                    local m = Magnets[closest]
                    if m and m.Parent then
                        m.Size = Vector3.new(settings.magnetSize, settings.magnetSize, settings.magnetSize)
                        m.Transparency = settings.showHitbox and 0.8 or 1
                    end
                end
            end
        else
            for p in pairs(Magnets) do removeMagnetFor(p) end
        end
    end
end)

-- ESP boxes
task.spawn(function()
    while task.wait(0.2) do
        if settings.espBoxes then
            for p, box in pairs(ESPObjects) do
                if not p.Parent or not p.Character or not p.Character:FindFirstChild("HumanoidRootPart") then
                    pcall(function() box:Destroy() end)
                    ESPObjects[p] = nil
                end
            end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    local root = p.Character:FindFirstChild("HumanoidRootPart")
                    if hum and hum.Health > 0 and root then
                        if not ESPObjects[p] then
                            local box = Instance.new("BoxHandleAdornment")
                            box.Size = Vector3.new(2, 5, 1)
                            box.Adornee = root
                            box.AlwaysOnTop = true
                            box.ZIndex = 5
                            box.Transparency = 0.5
                            box.Color3 = Color3.fromRGB(255, 0, 0)
                            box.Parent = CoreGui
                            ESPObjects[p] = box
                        else
                            ESPObjects[p].Adornee = root
                        end
                    end
                end
            end
        else
            for p, box in pairs(ESPObjects) do
                pcall(function() box:Destroy() end)
                ESPObjects[p] = nil
            end
        end
    end
end)

-- Aim loop
RunService.RenderStepped:Connect(function()
    if not settings.aimEnabled then settings.lockedTarget = nil; return end
    local useAim = false
    if settings.alwaysOn then
        useAim = true
    else
        if settings.aimMode == "Toggle" then
            useAim = settings.toggleState
        elseif settings.aimMode == "Hold" then
            useAim = settings.holdState
        end
    end
    if not useAim then settings.lockedTarget = nil; return end
    local target = getTarget()
    if target then snapAim(target.Position) end
end)

-- Range indicator
RunService.RenderStepped:Connect(function()
    if not settings.rangeIndicator then
        rangeCircle.Visible = false
        return
    end
    local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then
        rangeCircle.Visible = false
        return
    end
    local sp, onScreen = camera:WorldToViewportPoint(myRoot.Position)
    if not onScreen then
        rangeCircle.Visible = false
        return
    end
    local baseDist = 8
    local p1, _ = camera:WorldToViewportPoint(myRoot.Position + Vector3.new(baseDist, 0, 0))
    local p2, _ = camera:WorldToViewportPoint(myRoot.Position)
    rangeCircle.Radius = math.abs(p1.X - p2.X)
    rangeCircle.Position = Vector2.new(sp.X, sp.Y)
    rangeCircle.Visible = true
end)

-- Aim bind handler
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if settings.aimEnabled and not settings.alwaysOn then
        if input.KeyCode == settings.currentBind then
            if settings.aimMode == "Toggle" then
                settings.toggleState = not settings.toggleState
                if not settings.toggleState then settings.lockedTarget = nil end
                playSound(settings.toggleState and 500 or 200, 0.15)
            elseif settings.aimMode == "Hold" then
                settings.holdState = true
                playSound(400, 0.15)
            end
        end
    end
end)
UIS.InputEnded:Connect(function(input)
    if settings.aimEnabled and not settings.alwaysOn then
        if input.KeyCode == settings.currentBind and settings.aimMode == "Hold" then
            settings.holdState = false
            settings.lockedTarget = nil
        end
    end
end)

-- Cleanup on remove
player.CharacterRemoving:Connect(function()
    for p in pairs(Magnets) do removeMagnetFor(p) end
end)

task.delay(0.5, function()
    toast("noblack hub LITE loaded")
end)
