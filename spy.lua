-- SPY v2 — no metatable hook, zero lag
local CoreGui = game:GetService("CoreGui")
local RS = game:GetService("ReplicatedStorage")
pcall(function() CoreGui:FindFirstChild("SPY_GUI"):Destroy() end)

local logs = {}

-- GUI
local Gui = Instance.new("ScreenGui")
Gui.Name = "SPY_GUI"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = CoreGui

local Win = Instance.new("Frame")
Win.Size = UDim2.new(0,340,0,420)
Win.Position = UDim2.new(0.5,-170,0.5,-210)
Win.BackgroundColor3 = Color3.fromRGB(15,15,22)
Win.BorderSizePixel = 0
Win.Active = true
Win.Draggable = true
Win.Parent = Gui
Instance.new("UICorner",Win).CornerRadius = UDim.new(0,12)

local TB = Instance.new("Frame")
TB.Size = UDim2.new(1,0,0,40)
TB.BackgroundColor3 = Color3.fromRGB(80,40,180)
TB.BorderSizePixel = 0
TB.Parent = Win
Instance.new("UICorner",TB).CornerRadius = UDim.new(0,12)
local TBFix = Instance.new("Frame")
TBFix.Size = UDim2.new(1,0,0.5,0)
TBFix.Position = UDim2.new(0,0,0.5,0)
TBFix.BackgroundColor3 = Color3.fromRGB(80,40,180)
TBFix.BorderSizePixel = 0
TBFix.Parent = TB

local TL = Instance.new("TextLabel")
TL.Size = UDim2.new(1,-50,1,0)
TL.Position = UDim2.new(0,12,0,0)
TL.BackgroundTransparency = 1
TL.TextColor3 = Color3.new(1,1,1)
TL.Font = Enum.Font.GothamBold
TL.TextSize = 13
TL.TextXAlignment = Enum.TextXAlignment.Left
TL.Text = "SPY — กด action ในเกมได้เลย"
TL.Parent = TB

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0,28,0,28)
CloseBtn.Position = UDim2.new(1,-34,0.5,-14)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
CloseBtn.TextColor3 = Color3.new(1,1,1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Text = "X"
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = TB
Instance.new("UICorner",CloseBtn).CornerRadius = UDim.new(0,6)
CloseBtn.MouseButton1Click:Connect(function() Gui:Destroy() end)

local LogBox = Instance.new("TextBox")
LogBox.Size = UDim2.new(1,-16,1,-96)
LogBox.Position = UDim2.new(0,8,0,48)
LogBox.BackgroundColor3 = Color3.fromRGB(22,22,35)
LogBox.TextColor3 = Color3.fromRGB(180,255,180)
LogBox.Font = Enum.Font.Code
LogBox.TextSize = 11
LogBox.TextXAlignment = Enum.TextXAlignment.Left
LogBox.TextYAlignment = Enum.TextYAlignment.Top
LogBox.MultiLine = true
LogBox.ClearTextOnFocus = false
LogBox.Text = "scanning remotes...\n"
LogBox.BorderSizePixel = 0
LogBox.Parent = Win
Instance.new("UICorner",LogBox).CornerRadius = UDim.new(0,8)
local lp = Instance.new("UIPadding")
lp.PaddingLeft = UDim.new(0,6); lp.PaddingTop = UDim.new(0,4); lp.Parent = LogBox

local ClearBtn = Instance.new("TextButton")
ClearBtn.Size = UDim2.new(1,-16,0,36)
ClearBtn.Position = UDim2.new(0,8,1,-44)
ClearBtn.BackgroundColor3 = Color3.fromRGB(60,60,80)
ClearBtn.TextColor3 = Color3.new(1,1,1)
ClearBtn.Font = Enum.Font.Gotham
ClearBtn.TextSize = 12
ClearBtn.Text = "Clear"
ClearBtn.AutoButtonColor = false
ClearBtn.Parent = Win
Instance.new("UICorner",ClearBtn).CornerRadius = UDim.new(0,8)
ClearBtn.MouseButton1Click:Connect(function()
    logs = {}
    LogBox.Text = "cleared\n"
end)

local function addLog(line)
    table.insert(logs, line)
    if #logs > 60 then table.remove(logs,1) end
    LogBox.Text = table.concat(logs,"\n")
end

-- Scan Networking folder และ connect ทุก Remote
local Net = RS:WaitForChild("Packages",5) and RS.Packages:WaitForChild("Networking",5)
if not Net then addLog("ERROR: Networking not found"); return end

local count = 0
for _, remote in ipairs(Net:GetDescendants()) do
    if remote:IsA("RemoteEvent") then
        local name = remote.Name
        remote.OnClientEvent:Connect(function(...)
            local args = {...}
            local a1 = args[1] ~= nil and tostring(args[1]) or ""
            if #a1 > 40 then a1 = a1:sub(1,40).."..." end
            addLog("[RE←Server] " .. name .. (a1~="" and "  → "..a1 or ""))
        end)
        count += 1
    elseif remote:IsA("RemoteFunction") then
        count += 1
    end
end

addLog("connected " .. count .. " remotes")
addLog("กด Hatch / Treadmill / Sell / Place ได้เลย")
addLog("(RF จะขึ้นเมื่อ server reply กลับมา)")
