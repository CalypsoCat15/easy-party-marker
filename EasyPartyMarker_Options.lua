local ADDON_NAME = ...
local API = _G.EasyPartyMarker

local panel
local minimapButton
local partySlider
local playerSlider
local partyValue
local playerValue
local partyPreview
local playerPreview
local partySwatches = {}
local playerSwatches = {}
local updating = false

local PLAYER_SIZE_NAMES = { "Tiny", "Small", "Medium", "Large", "Extra Large" }

local function AddRoundMask(frame, texture)
    if not frame.CreateMaskTexture or not texture.AddMaskTexture then
        return
    end
    local mask = frame:CreateMaskTexture()
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
end

local function AddBorder(frame, thickness)
    local border = {}
    local function Line(pointA, pointB, x, y, width, height)
        local texture = frame:CreateTexture(nil, "BORDER")
        texture:SetPoint(pointA, frame, pointA, x, y)
        texture:SetPoint(pointB, frame, pointB, -x, -y)
        if width then texture:SetWidth(width) end
        if height then texture:SetHeight(height) end
        border[#border + 1] = texture
    end
    Line("TOPLEFT", "TOPRIGHT", 0, 0, nil, thickness)
    Line("BOTTOMLEFT", "BOTTOMRIGHT", 0, 0, nil, thickness)
    Line("TOPLEFT", "BOTTOMLEFT", 0, 0, thickness, nil)
    Line("TOPRIGHT", "BOTTOMRIGHT", 0, 0, thickness, nil)
    frame.EPMBorder = border
    return border
end

local function SetBorderColor(frame, r, g, b, a)
    if not frame.EPMBorder then return end
    for _, texture in ipairs(frame.EPMBorder) do
        texture:SetColorTexture(r, g, b, a or 1)
    end
end

local function PositionMinimapButton()
    if not minimapButton or not Minimap then return end
    local settings = API.GetSettings()
    if not settings then return end
    local angle = math.rad(settings.minimapButtonAngle or 225)
    local radius = (math.max(Minimap:GetWidth(), Minimap:GetHeight()) / 2) + 5
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function UpdateSwatches(swatches, selected)
    for _, button in ipairs(swatches) do
        if button.colorName == selected then
            SetBorderColor(button, 1, 0.85, 0.12, 1)
            button:SetScale(1.12)
        else
            SetBorderColor(button, 0.08, 0.08, 0.08, 1)
            button:SetScale(1)
        end
    end
end

local function RefreshOptions()
    local settings = API.GetSettings()
    if not settings then return end
    updating = true

    if partySlider then
        partySlider:SetValue(settings.size)
        partyValue:SetText(tostring(settings.size))
    end
    if playerSlider then
        playerSlider:SetValue(settings.selfSize)
        playerValue:SetText(PLAYER_SIZE_NAMES[settings.selfSize] or "Medium")
    end

    UpdateSwatches(partySwatches, settings.color)
    UpdateSwatches(playerSwatches, settings.selfColor)

    local colors = API.GetColors()
    local partyColor = colors[settings.color] or colors.pink
    if partyPreview then
        partyPreview.inner:SetColorTexture(partyColor[1], partyColor[2], partyColor[3], 1)
        partyPreview:SetSize(settings.size * 2, settings.size * 2)
        local innerSize = math.max(4, math.floor(settings.size * 1.4))
        partyPreview.inner:SetSize(innerSize, innerSize)
    end
    if playerPreview then
        playerPreview:SetTexture(API.GetPlayerPointerTexture())
    end
    if minimapButton then
        minimapButton.icon:SetTexture(API.GetPlayerPointerTexture())
    end

    PositionMinimapButton()
    updating = false
end

API.RefreshOptions = RefreshOptions

local function CreateSwatch(parent, colorName, color, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(28, 28)
    button.colorName = colorName
    AddBorder(button, 2)

    local fill = button:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 4, -4)
    fill:SetPoint("BOTTOMRIGHT", -4, 4)
    fill:SetColorTexture(color[1], color[2], color[3], 1)
    AddRoundMask(button, fill)

    button:SetScript("OnClick", function()
        onClick(colorName)
        RefreshOptions()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(string.upper(string.sub(colorName, 1, 1)) .. string.sub(colorName, 2), 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

local function CreateColorRow(parent, y, labelText, onClick, destination)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 34, y)
    label:SetText(labelText)

    local colors, order = API.GetColors()
    for index, colorName in ipairs(order) do
        local button = CreateSwatch(parent, colorName, colors[colorName], onClick)
        button:SetPoint("TOPLEFT", 38 + ((index - 1) * 43), y - 25)
        destination[#destination + 1] = button
    end
end

local function StyleSlider(slider, lowText, highText)
    slider:SetMinMaxValues(lowText == "6" and 6 or 1, highText == "30" and 30 or 5)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:SetWidth(280)
    local name = slider:GetName()
    if name then
        local low = _G[name .. "Low"]
        local high = _G[name .. "High"]
        local text = _G[name .. "Text"]
        if low then low:SetText(lowText) end
        if high then high:SetText(highText) end
        if text then text:SetText("") end
    end
end

local function BuildPanel()
    panel = CreateFrame("Frame", "EasyPartyMarkerOptionsPanel", UIParent)
    panel:SetSize(420, 450)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetScript("OnShow", RefreshOptions)
    panel:Hide()

    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.025, 0.035, 0.032, 0.96)
    AddBorder(panel, 3)
    SetBorderColor(panel, 0.38, 0.90, 0.71, 1)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText("Easy Party Marker")
    title:SetTextColor(0.38, 0.90, 0.71)

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)
    subtitle:SetText("Make your map markers feel like yours")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local partyHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    partyHeading:SetPoint("TOPLEFT", 26, -72)
    partyHeading:SetText("Party marker")
    partyHeading:SetTextColor(1, 0.20, 0.65)

    CreateColorRow(panel, -105, "Color", API.SetPartyColor, partySwatches)

    local partySizeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    partySizeLabel:SetPoint("TOPLEFT", 34, -166)
    partySizeLabel:SetText("Size")
    partyValue = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    partyValue:SetPoint("LEFT", partySizeLabel, "RIGHT", 10, 0)

    partySlider = CreateFrame("Slider", "EasyPartyMarkerPartySizeSlider", panel, "OptionsSliderTemplate")
    partySlider:SetPoint("TOPLEFT", 63, -188)
    StyleSlider(partySlider, "6", "30")
    partySlider:SetScript("OnValueChanged", function(_, value)
        if updating then return end
        local rounded = math.floor(value + 0.5)
        partyValue:SetText(tostring(rounded))
        API.SetPartySize(rounded)
        RefreshOptions()
    end)

    local playerHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    playerHeading:SetPoint("TOPLEFT", 26, -235)
    playerHeading:SetText("Your directional arrow")
    playerHeading:SetTextColor(0.38, 0.90, 0.71)

    CreateColorRow(panel, -268, "Color", API.SetPlayerColor, playerSwatches)

    local playerSizeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    playerSizeLabel:SetPoint("TOPLEFT", 34, -329)
    playerSizeLabel:SetText("Size")
    playerValue = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    playerValue:SetPoint("LEFT", playerSizeLabel, "RIGHT", 10, 0)

    playerSlider = CreateFrame("Slider", "EasyPartyMarkerPlayerSizeSlider", panel, "OptionsSliderTemplate")
    playerSlider:SetPoint("TOPLEFT", 63, -351)
    StyleSlider(playerSlider, "1", "5")
    playerSlider:SetScript("OnValueChanged", function(_, value)
        if updating then return end
        local rounded = math.floor(value + 0.5)
        playerValue:SetText(PLAYER_SIZE_NAMES[rounded] or "Medium")
        API.SetPlayerSize(rounded)
        RefreshOptions()
    end)

    partyPreview = CreateFrame("Frame", nil, panel)
    partyPreview:SetPoint("BOTTOMLEFT", 40, 22)
    partyPreview.outer = partyPreview:CreateTexture(nil, "ARTWORK", nil, 1)
    partyPreview.outer:SetAllPoints()
    partyPreview.outer:SetColorTexture(0.02, 0.02, 0.02, 1)
    AddRoundMask(partyPreview, partyPreview.outer)
    partyPreview.inner = partyPreview:CreateTexture(nil, "ARTWORK", nil, 2)
    partyPreview.inner:SetPoint("CENTER")
    partyPreview.inner:SetSize(14, 14)
    AddRoundMask(partyPreview, partyPreview.inner)

    playerPreview = panel:CreateTexture(nil, "ARTWORK")
    playerPreview:SetSize(64, 64)
    playerPreview:SetPoint("BOTTOMLEFT", 80, 4)

    local instant = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instant:SetPoint("BOTTOM", 0, 54)
    instant:SetText("Changes apply instantly to the minimap and large map")
    instant:SetTextColor(0.72, 0.82, 0.78)

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(150, 24)
    reset:SetPoint("BOTTOM", 42, 20)
    reset:SetText("Lisa's Defaults")
    reset:SetScript("OnClick", function()
        API.ResetDefaults()
        RefreshOptions()
    end)

    table.insert(UISpecialFrames, panel:GetName())
end

local function UpdateButtonDuringDrag()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale
    local centerX, centerY = Minimap:GetCenter()
    local deltaX, deltaY = x - centerX, y - centerY
    local atan2 = math.atan2 or function(a, b) return math.atan(a, b) end
    API.SetMinimapButtonAngle(math.deg(atan2(deltaY, deltaX)))
    PositionMinimapButton()
end

local function BuildMinimapButton()
    minimapButton = CreateFrame("Button", "EasyPartyMarkerMinimapButton", Minimap)
    minimapButton:SetSize(20, 20)
    minimapButton:SetFrameStrata("HIGH")
    minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 30)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    local background = minimapButton:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.02, 0.03, 0.03, 0.98)
    AddRoundMask(minimapButton, background)

    minimapButton.icon = minimapButton:CreateTexture(nil, "ARTWORK")
    minimapButton.icon:SetPoint("CENTER")
    minimapButton.icon:SetSize(34, 34)
    minimapButton.icon:SetTexture(API.GetPlayerPointerTexture())

    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    minimapButton:SetScript("OnClick", function(_, button)
        if minimapButton.wasDragged then return end
        API.ToggleOptions()
    end)
    minimapButton:SetScript("OnDragStart", function(self)
        self.dragging = true
        self.wasDragged = true
        self:SetScript("OnUpdate", UpdateButtonDuringDrag)
    end)
    minimapButton:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() self.wasDragged = false end)
        else
            self.wasDragged = false
        end
    end)
    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Easy Party Marker", 0.38, 0.90, 0.71)
        GameTooltip:AddLine("Click: Open marker menu", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move this button", 1, 1, 1)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if Minimap.HookScript then
        Minimap:HookScript("OnSizeChanged", PositionMinimapButton)
    end
    PositionMinimapButton()
end

function API.ToggleOptions()
    if not panel then return end
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
        RefreshOptions()
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end
    local function Build()
        BuildPanel()
        BuildMinimapButton()
        RefreshOptions()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, Build)
    else
        Build()
    end
end)
