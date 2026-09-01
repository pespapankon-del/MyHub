-- SPY with copyable GUI
local CoreGui = game:GetService("CoreGui")
pcall(function() CoreGui:FindFirstChild("SPY_GUI"):Destroy() end)

local logs = {}

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

-- Titlebar
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
TL.Size = UDim2.new(1,-80,1,0)
TL.Position = UDim2.new(0,12,0,0)
TL.BackgroundTransparency = 1
TL.TextColor3 = Color3.new(1,1,1)
TL.Font = Enum.Font.GothamBold
TL.TextSize = 13
TL.TextXAlignment = Enum.TextXAlignment.Left
TL.Text = "SPY — กด action ในเกมได้เลย"
TL.Parent = TB

-- Close button
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
CloseBtn.MouseButton1Click:Connect(function()
    Gui:Destroy()
end)

-- Log box (readonly textbox for copy)
local LogBox = Instance.new("TextBox")
LogBox.Size = UDim2.new(1,-16,1,-100)
LogBox.Position = UDim2.new(0,8,0,48)
LogBox.BackgroundColor3 = Color3.fromRGB(22,22,35)
LogBox.TextColor3 = Color3.fromRGB(180,255,180)
LogBox.Font = Enum.Font.Code
LogBox.TextSize = 11
LogBox.TextXAlignment = Enum.TextXAlignment.Left
LogBox.TextYAlignment = Enum.TextYAlignment.Top
LogBox.MultiLine = true
LogBox.ClearTextOnFocus = false
LogBox.Text = "รอ action...\n"
LogBox.BorderSizePixel = 0
LogBox.Parent = Win
Instance.new("UICorner",LogBox).CornerRadius = UDim.new(0,8)
local lp = Instance.new("UIPadding")
lp.PaddingLeft = UDim.new(0,6)
lp.PaddingTop = UDim.new(0,4)
lp.Parent = LogBox

-- Clear button
local ClearBtn = Instance.new("TextButton")
ClearBtn.Size = UDim2.new(0.45,-4,0,36)
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
    LogBox.Text = "cleared...\n"
end)

-- Status label
local StatusLbl = Instance.new("TextLabel")
StatusLbl.Size = UDim2.new(0.55,-4,0,36)
StatusLbl.Position = UDim2.new(0.45,0,1,-44)
StatusLbl.BackgroundTransparency = 1
StatusLbl.TextColor3 = Color3.fromRGB(100,220,100)
StatusLbl.Font = Enum.Font.Gotham
StatusLbl.TextSize = 11
StatusLbl.Text = "SPY active"
StatusLbl.Parent = Win

-- กรองเฉพาะ remote ที่สำคัญ (ตัดพวก UI/render/input noise ออก)
local skipList = {
    "UIService", "VirtualInputManager", "UserInputService",
    "AnimationController", "Animate", "RunService",
    "Camera", "Players.LocalPlayer.PlayerGui",
    "CoreGui", "HttpRbxApiService", "RobloxReplicatedStorage",
}
local function isNoise(path)
    for _, s in ipairs(skipList) do
        if path:find(s, 1, true) then return true end
    end
    return false
end

local seen = {}
local function addLog(line)
    table.insert(logs, line)
    if #logs > 60 then table.remove(logs,1) end
    LogBox.Text = table.concat(logs, "\n")
end

local mt = getrawmetatable(game)
local old = mt.__namecall
setreadonly(mt, false)
mt.__namecall = function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" then
        local path = self:GetFullName()
        if not isNoise(path) then
            local args = {...}
            task.spawn(function()
                local arg1 = args[1] ~= nil and tostring(args[1]) or ""
                if #arg1 > 50 then arg1 = arg1:sub(1,50).."..." end
                local line = path
                if arg1 ~= "" then line = line .. "  → " .. arg1 end
                addLog(line)
            end)
        end
    end
    return old(self, ...)
end
setreadonly(mt, true)

addLog("SPY ready — กด action ในเกมได้เลย")
