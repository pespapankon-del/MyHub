local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local Net = RS:WaitForChild("Packages"):WaitForChild("Networking")
local function getNet(name) return Net:FindFirstChild(name) end

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local Config = {
    AutoSteal = false,
    AutoHatch = false,
    AutoTreadmill = false,
    SpeedBoost = false,
    EggESP = false,
    AntiKick = false,
    AntiAFK = false,
    AutoServerHop = false,
    MutationOnly = false,
    WalkSpeed = 100,
    StealDelay = 0.3,
    TargetRarity = "All",
    MaxPlayers = 3,
    HopDelay = 3,
    Stats = { EggsStolen = 0, EggsHatched = 0, SessionTime = 0 }
}

local rarityList = {"All","Common","Uncommon","Rare","Epic","Legendary","Mythic","Divine"}
local rarityIdx = 1

local function log(msg) print("[SAE] " .. tostring(msg)) end

local function safeWalk(pos)
    if not humanoid or humanoid.Health <= 0 then return end
    humanoid:MoveTo(pos)
    local done, t = false, 0
    local conn
    conn = humanoid.MoveToFinished:Connect(function() done = true; conn:Disconnect() end)
    while not done and t < 12 do task.wait(0.1); t += 0.1 end
end

player.CharacterAdded:Connect(function(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")
    task.wait(1)
    if Config.SpeedBoost then humanoid.WalkSpeed = Config.WalkSpeed end
end)

-- Anti-Kick
local function enableAntiKick()
    local mt = getmetatable(player)
    if mt then
        local old = mt.__namecall
        mt.__namecall = function(self, ...)
            if select(1, ...) == "Kick" and self == player then return end
            return old(self, ...)
        end
    end
end

-- Anti-AFK
local afkThread = nil
local function enableAntiAFK()
    if afkThread then return end
    afkThread = task.spawn(function()
        while Config.AntiAFK do
            local c = player.Character
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                if h then h:Move(Vector3.new(0.01,0,0),true); task.wait(0.1); h:Move(Vector3.zero,true) end
            end
            task.wait(55)
        end
    end)
end
local function disableAntiAFK()
    Config.AntiAFK = false
    if afkThread then task.cancel(afkThread); afkThread = nil end
end

-- Server Hop
local function hopToEmpty()
    local ok, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
        ))
    end)
    local servers = (ok and result and result.data) or {}
    local best, fewest = nil, math.huge
    for _, srv in ipairs(servers) do
        if srv.id ~= game.JobId then
            local count = srv.playing or 0
            if count < fewest then fewest = count; best = srv end
        end
    end
    if best and fewest <= Config.MaxPlayers then
        task.wait(Config.HopDelay)
        TS:TeleportToPlaceInstance(game.PlaceId, best.id, player)
    end
end

-- Filter
local function passesFilter(egg)
    if Config.TargetRarity ~= "All" then
        local tag = egg:FindFirstChild("Rarity") or egg:FindFirstChild("rarity")
        if not tag or tag.Value ~= Config.TargetRarity then return false end
    end
    if Config.MutationOnly then
        local mut = egg:FindFirstChild("Mutation") or egg:FindFirstChild("mutation")
        if not (mut and mut.Value ~= "") then return false end
    end
    return true
end

-- ESP
local espObjects = {}
local function clearESP()
    for _, v in pairs(espObjects) do pcall(function() v:Destroy() end) end
    espObjects = {}
end
local function updateESP()
    if not Config.EggESP then clearESP(); return end
    local folder = workspace:FindFirstChild("Eggs", true)
    if not folder then return end
    for _, egg in ipairs(folder:GetChildren()) do
        if not espObjects[egg] and passesFilter(egg) then
            local part = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
            if part then
                local box = Instance.new("SelectionBox")
                box.Adornee = part
                box.Color3 = Color3.fromRGB(255, 215, 0)
                box.LineThickness = 0.06
                box.SurfaceTransparency = 0.75
                box.SurfaceColor3 = Color3.fromRGB(255, 215, 0)
                box.Parent = CoreGui
                espObjects[egg] = box
                egg.AncestryChanged:Connect(function()
                    if box and box.Parent then box:Destroy(); espObjects[egg] = nil end
                end)
            end
        end
    end
end

local function returnToBase()
    local delivery = workspace:FindFirstChild("DeliveryHitbox", true)
    if delivery then safeWalk(delivery.Position) end
end

local function hatchEggs()
    local loadEgg = getNet("RF/Bloomery/AskLoadEgg")
    if not loadEgg then return end
    local bloomery = workspace:FindFirstChild("Bloomery", true)
    if bloomery then
        local p = bloomery.PrimaryPart or bloomery:FindFirstChildWhichIsA("BasePart")
        if p then safeWalk(p.Position) end
    end
    pcall(function() loadEgg:InvokeServer() end)
    local mutate = getNet("RF/Bloomery/AskMutate")
    if mutate then task.wait(0.5); pcall(function() mutate:InvokeServer() end) end
    Config.Stats.EggsHatched += 1
end

local function trainTreadmill()
    local wearStill = getNet("RF/Treadmill/AskWearStill")
    local tierRaise = getNet("RF/Treadmill/AskTierRaise")
    local tm = workspace:FindFirstChild("Treadmill", true)
    if tm then
        local p = tm.PrimaryPart or tm:FindFirstChildWhichIsA("BasePart")
        if p then safeWalk(p.Position) end
    end
    if wearStill then pcall(function() wearStill:InvokeServer(true) end) end
    if tierRaise then pcall(function() tierRaise:InvokeServer() end) end
end

-- Steal immediately when egg spawns (no global lock — each egg runs independently)
local stolen = {}
local function tryStealEgg(egg)
    if not Config.AutoSteal then return end
    if stolen[egg] then return end
    if not passesFilter(egg) then return end
    stolen[egg] = true
    task.spawn(function()
        pcall(function()
            local part = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
            if part then
                rootPart.CFrame = CFrame.new(part.Position + Vector3.new(0,0,2))
                task.wait(0.05)
            end
            local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                fireproximityprompt(prompt)
            else
                local stealRemote = getNet("RF/EggWorld/AskFieldEggCarry")
                if stealRemote then stealRemote:InvokeServer(egg) end
            end
            Config.Stats.EggsStolen += 1
            task.wait(0.3)
            returnToBase()
            if Config.AutoHatch then hatchEggs() end
        end)
        task.wait(5)
        stolen[egg] = nil
    end)
end

-- Hook into workspace.Eggs ChildAdded
local eggsFolder = workspace:WaitForChild("Eggs", 10)
if eggsFolder then
    -- grab any already there
    for _, egg in ipairs(eggsFolder:GetChildren()) do
        task.spawn(tryStealEgg, egg)
    end
    eggsFolder.ChildAdded:Connect(function(egg)
        task.wait(0.05)
        tryStealEgg(egg)
    end)
end

-- Main loop (support functions & stats)
local sessionStart = os.clock()
task.spawn(function()
    while true do
        Config.Stats.SessionTime = math.floor(os.clock() - sessionStart)
        if Config.SpeedBoost and humanoid then humanoid.WalkSpeed = Config.WalkSpeed end
        updateESP()
        if Config.AutoTreadmill and not Config.AutoSteal then trainTreadmill() end
        if Config.AutoServerHop and #Players:GetPlayers() > Config.MaxPlayers then
            task.spawn(hopToEmpty)
        end
        task.wait(1)
    end
end)

-- GUI
pcall(function() CoreGui:FindFirstChild("SAE_GUI"):Destroy() end)

local Gui = Instance.new("ScreenGui")
Gui.Name = "SAE_GUI"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.IgnoreGuiInset = true
Gui.Parent = CoreGui

local C = {
    bg = Color3.fromRGB(15,15,22),
    panel = Color3.fromRGB(22,22,35),
    accent = Color3.fromRGB(100,70,220),
    danger = Color3.fromRGB(200,50,50),
    success = Color3.fromRGB(40,180,80),
    warn = Color3.fromRGB(220,140,30),
    text = Color3.fromRGB(230,230,230),
    sub = Color3.fromRGB(140,140,160),
    off = Color3.fromRGB(55,55,70),
}

local Win = Instance.new("Frame")
Win.Size = UDim2.new(0,270,0,520)
Win.Position = UDim2.new(0,16,0.05,0)
Win.BackgroundColor3 = C.bg
Win.BorderSizePixel = 0
Win.Active = true
Win.Draggable = true
Win.Parent = Gui
Instance.new("UICorner", Win).CornerRadius = UDim.new(0,12)

local TB = Instance.new("Frame")
TB.Size = UDim2.new(1,0,0,42)
TB.BackgroundColor3 = C.accent
TB.BorderSizePixel = 0
TB.Parent = Win
Instance.new("UICorner", TB).CornerRadius = UDim.new(0,12)
local TBfix = Instance.new("Frame")
TBfix.Size = UDim2.new(1,0,0.5,0)
TBfix.Position = UDim2.new(0,0,0.5,0)
TBfix.BackgroundColor3 = C.accent
TBfix.BorderSizePixel = 0
TBfix.Parent = TB

local TL = Instance.new("TextLabel")
TL.Size = UDim2.new(1,-10,1,0)
TL.Position = UDim2.new(0,10,0,0)
TL.BackgroundTransparency = 1
TL.TextColor3 = Color3.new(1,1,1)
TL.Font = Enum.Font.GothamBold
TL.TextSize = 14
TL.TextXAlignment = Enum.TextXAlignment.Left
TL.Text = "Steal An Egg Script"
TL.Parent = TB

local MB = Instance.new("TextButton")
MB.Size = UDim2.new(0,28,0,28)
MB.Position = UDim2.new(1,-34,0.5,-14)
MB.BackgroundColor3 = Color3.new(1,1,1)
MB.BackgroundTransparency = 0.8
MB.TextColor3 = Color3.new(1,1,1)
MB.Font = Enum.Font.GothamBold
MB.TextSize = 13
MB.Text = "-"
MB.Parent = TB
Instance.new("UICorner", MB).CornerRadius = UDim.new(0,6)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1,0,1,-42)
Scroll.Position = UDim2.new(0,0,0,42)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = C.accent
Scroll.CanvasSize = UDim2.new(0,0,0,0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = Win

local SL = Instance.new("UIListLayout")
SL.Padding = UDim.new(0,6)
SL.Parent = Scroll

local SP = Instance.new("UIPadding")
SP.PaddingLeft = UDim.new(0,10)
SP.PaddingRight = UDim.new(0,10)
SP.PaddingTop = UDim.new(0,10)
SP.PaddingBottom = UDim.new(0,10)
SP.Parent = Scroll

local minimized = false
local origSize = Win.Size
MB.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(Win, TweenInfo.new(0.2), {
        Size = minimized and UDim2.new(0,270,0,42) or origSize
    }):Play()
    Scroll.Visible = not minimized
    MB.Text = minimized and "+" or "-"
end)

local function sec(title)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,0,18)
    l.BackgroundTransparency = 1
    l.TextColor3 = C.sub
    l.Font = Enum.Font.GothamBold
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = "-- " .. title .. " --"
    l.Parent = Scroll
end

local function tog(label, key, col, onOn, onOff)
    col = col or C.accent
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,38)
    b.BackgroundColor3 = C.off
    b.TextColor3 = C.text
    b.Font = Enum.Font.Gotham
    b.TextSize = 13
    b.Text = label .. "  [ OFF ]"
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.AutoButtonColor = false
    b.Parent = Scroll
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0,12)
    p.Parent = b
    b.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        TweenService:Create(b, TweenInfo.new(0.2), {
            BackgroundColor3 = Config[key] and col or C.off
        }):Play()
        b.Text = label .. "  [ " .. (Config[key] and "ON" or "OFF") .. " ]"
        if Config[key] and onOn then onOn()
        elseif not Config[key] and onOff then onOff() end
    end)
    return b
end

local function mkbtn(label, col, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,38)
    b.BackgroundColor3 = col or C.accent
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Text = label
    b.AutoButtonColor = false
    b.Parent = Scroll
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
    b.MouseButton1Click:Connect(function()
        if cb then cb() end
    end)
end

-- Rarity button
local rBtn = Instance.new("TextButton")
rBtn.Size = UDim2.new(1,0,0,38)
rBtn.BackgroundColor3 = Color3.fromRGB(140,80,20)
rBtn.TextColor3 = Color3.new(1,1,1)
rBtn.Font = Enum.Font.Gotham
rBtn.TextSize = 13
rBtn.Text = "Filter: All"
rBtn.AutoButtonColor = false
rBtn.Parent = Scroll
Instance.new("UICorner", rBtn).CornerRadius = UDim.new(0,8)
local rp = Instance.new("UIPadding")
rp.PaddingLeft = UDim.new(0,12)
rp.Parent = rBtn
rBtn.MouseButton1Click:Connect(function()
    rarityIdx = (rarityIdx % #rarityList) + 1
    Config.TargetRarity = rarityList[rarityIdx]
    rBtn.Text = "Filter: " .. Config.TargetRarity
end)

sec("Auto Farm")
tog("Auto Steal Egg", "AutoSteal", C.accent)
tog("Auto Hatch Egg", "AutoHatch", C.accent)
tog("Auto Treadmill", "AutoTreadmill", C.accent)

sec("Extras")
tog("Speed Boost", "SpeedBoost", C.warn,
    function() if humanoid then humanoid.WalkSpeed = Config.WalkSpeed end end,
    function() if humanoid then humanoid.WalkSpeed = 16 end end)
tog("Egg ESP", "EggESP", C.warn, nil, function() clearESP() end)
tog("Mutation Only", "MutationOnly", C.warn)

sec("Protection")
tog("Anti-Kick", "AntiKick", C.success,
    function() enableAntiKick() end, nil)
tog("Anti-AFK", "AntiAFK", C.success,
    function() Config.AntiAFK = true; enableAntiAFK() end,
    function() disableAntiAFK() end)

sec("Server")
tog("Auto Server Hop", "AutoServerHop", C.warn)
mkbtn("Find Empty Server Now", C.warn, function() task.spawn(hopToEmpty) end)

sec("Stats")
local sE = Instance.new("TextLabel")
sE.Size = UDim2.new(1,0,0,16); sE.BackgroundTransparency = 1
sE.TextColor3 = C.sub; sE.Font = Enum.Font.Gotham; sE.TextSize = 11
sE.TextXAlignment = Enum.TextXAlignment.Left
sE.Text = "Stolen: 0"; sE.Parent = Scroll

local sH = Instance.new("TextLabel")
sH.Size = UDim2.new(1,0,0,16); sH.BackgroundTransparency = 1
sH.TextColor3 = C.sub; sH.Font = Enum.Font.Gotham; sH.TextSize = 11
sH.TextXAlignment = Enum.TextXAlignment.Left
sH.Text = "Hatched: 0"; sH.Parent = Scroll

local sT = Instance.new("TextLabel")
sT.Size = UDim2.new(1,0,0,16); sT.BackgroundTransparency = 1
sT.TextColor3 = C.sub; sT.Font = Enum.Font.Gotham; sT.TextSize = 11
sT.TextXAlignment = Enum.TextXAlignment.Left
sT.Text = "Time: 00:00"; sT.Parent = Scroll

mkbtn("Reset Stats", C.off, function()
    Config.Stats.EggsStolen = 0
    Config.Stats.EggsHatched = 0
    sessionStart = os.clock()
end)

task.spawn(function()
    while true do
        sE.Text = "Stolen: " .. Config.Stats.EggsStolen
        sH.Text = "Hatched: " .. Config.Stats.EggsHatched
        local s = Config.Stats.SessionTime
        sT.Text = string.format("Time: %02d:%02d", math.floor(s/60), s%60)
        task.wait(1)
    end
end)

log("GUI Ready!")
