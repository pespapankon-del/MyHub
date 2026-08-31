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

-- Filter (egg = Lua data table from FieldEggShifted)
local function passesFilter(egg)
    if Config.TargetPet and Config.TargetPet ~= "All" then
        local name = egg.name or egg.Name or egg.petName or egg.PetName or ""
        if not tostring(name):lower():find(Config.TargetPet:lower(), 1, true) then return false end
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

-- Egg data pool from server events
local fieldEggs = {}
local carryRemote = getNet("RF/EggWorld/AskFieldEggCarry")
local dropRemote  = getNet("RF/EggWorld/AskFieldEggDrop")
local shiftedRE   = getNet("RE/EggWorld/FieldEggShifted")
local goneRE      = getNet("RE/EggWorld/FieldEggGone")

if shiftedRE then
    shiftedRE.OnClientEvent:Connect(function(eggData)
        if type(eggData) == "table" then
            local id = eggData.id or eggData.Id or tostring(eggData)
            fieldEggs[id] = eggData
        end
    end)
end
if goneRE then
    goneRE.OnClientEvent:Connect(function(id)
        fieldEggs[tostring(id)] = nil
    end)
end

-- Auto steal loop — uses real egg data tables from server
local stealBusy = false
task.spawn(function()
    while true do
        if Config.AutoSteal and not stealBusy and carryRemote then
            for id, eggData in pairs(fieldEggs) do
                if not Config.AutoSteal then break end
                stealBusy = true
                local ok = pcall(function()
                    carryRemote:InvokeServer(eggData)
                end)
                if ok then
                    Config.Stats.EggsStolen += 1
                    fieldEggs[id] = nil
                end
                task.wait(Config.StealDelay)
                if Config.AutoHatch then
                    pcall(function() hatchEggs() end)
                end
                stealBusy = false
                break
            end
        end
        task.wait(0.3)
    end
end)

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

-- Pet list for filter
local allPets = {
    -- Divine
    {n="Unicorn",t="Divine"},{n="Kitsune",t="Divine"},{n="Nightflame",t="Divine"},{n="Dreadscale",t="Divine"},
    -- Eternal
    {n="Ice Dragon",t="Eternal"},{n="Phoenix",t="Eternal"},{n="Lava Dragon",t="Eternal"},
    {n="El Maja",t="Eternal"},{n="Mosasaurus",t="Eternal"},{n="Oni Tiger",t="Eternal"},
    {n="Gorilla King",t="Eternal"},{n="Krakenoid",t="Eternal"},{n="Strawberry Elephant",t="Eternal"},
    -- Secret
    {n="King Snake",t="Secret"},{n="Yeti",t="Secret"},{n="Cerberus",t="Secret"},
    {n="Kraken",t="Secret"},{n="Tralaledon",t="Secret"},{n="T-Rex",t="Secret"},
    {n="Cosmic Dragon",t="Secret"},{n="Stag",t="Secret"},{n="Mutant Shark",t="Secret"},
    -- Cosmic
    {n="Leviathan",t="Cosmic"},{n="King Mammoth",t="Cosmic"},{n="Whale Shark",t="Cosmic"},
    {n="Beluga Whale",t="Cosmic"},{n="Triceratops",t="Cosmic"},{n="Bronto",t="Cosmic"},
    {n="Koi",t="Cosmic"},{n="Snowy Owl",t="Cosmic"},{n="Mantaris",t="Cosmic"},
    -- Mythic
    {n="Scorpion",t="Mythic"},{n="Sand Spider",t="Mythic"},{n="Spider",t="Mythic"},
    {n="Tiger",t="Mythic"},{n="Sabertooth Tiger",t="Mythic"},{n="Mammoth",t="Mythic"},
    {n="Orca",t="Mythic"},{n="Ankylosaurus",t="Mythic"},{n="Red Panda",t="Mythic"},
    -- Legendary
    {n="Axolotl",t="Legendary"},{n="Gorilla",t="Legendary"},{n="Polar Bear",t="Legendary"},
    {n="Flaming Bull",t="Legendary"},{n="Shark",t="Legendary"},{n="Pterodactyl",t="Legendary"},
    -- Rare/Epic/Common
    {n="Owl",t="Rare"},{n="Raccoon",t="Rare"},{n="Turtle",t="Rare"},
    {n="Bear",t="Epic"},{n="Fox",t="Epic"},{n="Crocodile",t="Epic"},
    {n="Chicken",t="Common"},{n="Dog",t="Common"},{n="Frog",t="Common"},
}
local tierColor = {
    Divine=Color3.fromRGB(255,215,0), Eternal=Color3.fromRGB(255,100,255),
    Secret=Color3.fromRGB(255,50,50), Cosmic=Color3.fromRGB(100,200,255),
    Mythic=Color3.fromRGB(180,80,255), Legendary=Color3.fromRGB(255,140,0),
    Rare=Color3.fromRGB(60,120,255), Epic=Color3.fromRGB(160,60,220),
    Common=Color3.fromRGB(140,140,140),
}

-- Filter open button
local filterOpen = false
local filterBtn = Instance.new("TextButton")
filterBtn.Size = UDim2.new(1,0,0,38)
filterBtn.BackgroundColor3 = Color3.fromRGB(80,50,150)
filterBtn.TextColor3 = Color3.new(1,1,1)
filterBtn.Font = Enum.Font.Gotham
filterBtn.TextSize = 12
filterBtn.Text = "Target: All  [tap to filter]"
filterBtn.AutoButtonColor = false
filterBtn.Parent = Scroll
Instance.new("UICorner",filterBtn).CornerRadius=UDim.new(0,8)

-- Popup frame (inside Win, not Scroll)
local Pop = Instance.new("Frame")
Pop.Size = UDim2.new(1,-20,0,320)
Pop.Position = UDim2.new(0,10,0,50)
Pop.BackgroundColor3 = Color3.fromRGB(18,18,28)
Pop.BorderSizePixel = 0
Pop.Visible = false
Pop.ZIndex = 10
Pop.Parent = Win
Instance.new("UICorner",Pop).CornerRadius=UDim.new(0,10)

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1,-16,0,32)
SearchBox.Position = UDim2.new(0,8,0,8)
SearchBox.BackgroundColor3 = Color3.fromRGB(30,30,45)
SearchBox.TextColor3 = Color3.new(1,1,1)
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 12
SearchBox.PlaceholderText = "Search pet..."
SearchBox.PlaceholderColor3 = Color3.fromRGB(100,100,120)
SearchBox.Text = ""
SearchBox.ClearTextOnFocus = false
SearchBox.ZIndex = 11
SearchBox.Parent = Pop
Instance.new("UICorner",SearchBox).CornerRadius=UDim.new(0,6)

local PopScroll = Instance.new("ScrollingFrame")
PopScroll.Size = UDim2.new(1,-8,1,-48)
PopScroll.Position = UDim2.new(0,4,0,44)
PopScroll.BackgroundTransparency = 1
PopScroll.ScrollBarThickness = 3
PopScroll.CanvasSize = UDim2.new(0,0,0,0)
PopScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
PopScroll.ZIndex = 11
PopScroll.Parent = Pop
Instance.new("UIListLayout",PopScroll).Padding = UDim.new(0,3)

local petRows = {}
local function buildList(query)
    for _,r in pairs(petRows) do r:Destroy() end
    petRows = {}
    -- All option
    local allBtn = Instance.new("TextButton")
    allBtn.Size = UDim2.new(1,-6,0,30)
    allBtn.BackgroundColor3 = Config.TargetPet=="All" and Color3.fromRGB(60,60,90) or Color3.fromRGB(30,30,45)
    allBtn.TextColor3 = Color3.new(1,1,1)
    allBtn.Font = Enum.Font.Gotham; allBtn.TextSize=12
    allBtn.Text = "All Eggs"
    allBtn.AutoButtonColor=false; allBtn.ZIndex=12; allBtn.Parent=PopScroll
    Instance.new("UICorner",allBtn).CornerRadius=UDim.new(0,6)
    allBtn.MouseButton1Click:Connect(function()
        Config.TargetPet="All"
        filterBtn.Text="Target: All  [tap to filter]"
        Pop.Visible=false; filterOpen=false
        buildList("")
    end)
    table.insert(petRows,allBtn)
    -- Pet rows
    for _,p in ipairs(allPets) do
        if query=="" or p.n:lower():find(query:lower(),1,true) then
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1,-6,0,30)
            b.BackgroundColor3 = Config.TargetPet==p.n and Color3.fromRGB(60,60,90) or Color3.fromRGB(25,25,38)
            b.TextColor3 = tierColor[p.t] or Color3.new(1,1,1)
            b.Font = Enum.Font.Gotham; b.TextSize=12
            b.Text = p.n.."  ("..p.t..")"
            b.TextXAlignment=Enum.TextXAlignment.Left
            b.AutoButtonColor=false; b.ZIndex=12; b.Parent=PopScroll
            Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
            local pp=Instance.new("UIPadding"); pp.PaddingLeft=UDim.new(0,8); pp.Parent=b
            b.MouseButton1Click:Connect(function()
                Config.TargetPet=p.n
                filterBtn.Text="Target: "..p.n.."  ("..p.t..")"
                filterBtn.TextColor3 = tierColor[p.t] or Color3.new(1,1,1)
                Pop.Visible=false; filterOpen=false
                buildList("")
            end)
            table.insert(petRows,b)
        end
    end
end
Config.TargetPet = "All"
buildList("")
SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    buildList(SearchBox.Text)
end)
filterBtn.MouseButton1Click:Connect(function()
    filterOpen = not filterOpen
    Pop.Visible = filterOpen
    if filterOpen then SearchBox:CaptureFocus() end
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
