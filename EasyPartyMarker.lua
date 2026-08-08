local ADDON_NAME = ...
local REF = {}
local API = _G.EasyPartyMarker or {}
_G.EasyPartyMarker = API

local POINTER_TEXTURE_PREFIX = "Interface\\AddOns\\EasyPartyMarker\\Textures\\PlayerArrow"

local HBD = LibStub and LibStub("HereBeDragons-2.0", true)
local Pins = LibStub and LibStub("HereBeDragons-Pins-2.0", true)

local DEFAULTS = {
    enabled = true,
    size = 10,
    worldSize = 14,
    color = "pink",
    selfEnabled = true,
    selfColor = "mint",
    selfSize = 3,
    selfWorldSize = 4,
    minimapButtonAngle = 0,
    rotateMap = false,
    version = 10,
}

local COLORS = {
    mint = { 0.38, 0.90, 0.71 },
    pink = { 1.00, 0.04, 0.55 },
    cyan = { 0.00, 1.00, 1.00 },
    lime = { 0.25, 1.00, 0.00 },
    yellow = { 1.00, 0.92, 0.00 },
    orange = { 1.00, 0.32, 0.00 },
    purple = { 0.74, 0.41, 1.00 },
    white = { 0.96, 0.96, 0.96 },
}

local POINTER_COLOR_SUFFIX = {
    mint = "Mint",
    pink = "Pink",
    cyan = "Cyan",
    lime = "Lime",
    yellow = "Yellow",
    orange = "Orange",
    purple = "Purple",
    white = "White",
}

local WORLD_PLAYER_PIN_SIZES = { 12, 16, 20, 24, 30 }

local COLOR_ORDER = { "mint", "pink", "cyan", "lime", "yellow", "orange", "purple", "white" }

local markers = {}
local worldMarkers = {}
local nativePlayerPointerTextures = setmetatable({}, { __mode = "k" })
local updateFrame = CreateFrame("Frame")
local elapsedSinceUpdate = 0
local worldMapHooked = false
local groupMembersPinHooked = false
local lastWorldMapID
local UpdateWorldMapMarkers

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0a8aEasy Party Marker:|r " .. message)
end

local function GetPlayerPointerTextureFor(colorName, size)
    local suffix = POINTER_COLOR_SUFFIX[colorName] or POINTER_COLOR_SUFFIX.mint
    local safeSize = math.max(1, math.min(5, tonumber(size) or DEFAULTS.selfSize))
    return POINTER_TEXTURE_PREFIX .. suffix .. safeSize
end

local function GetPlayerPointerTexture()
    local settings = EasyPartyMarkerDB or DEFAULTS
    return GetPlayerPointerTextureFor(settings.selfColor, settings.selfSize)
end

local function GetWorldPlayerPointerTexture()
    local settings = EasyPartyMarkerDB or DEFAULTS
    return GetPlayerPointerTextureFor(settings.selfColor, settings.selfWorldSize)
end

local function GetWorldPlayerPinSize()
    local settings = EasyPartyMarkerDB or DEFAULTS
    local level = math.max(1, math.min(5, tonumber(settings.selfWorldSize) or DEFAULTS.selfWorldSize))
    return WORLD_PLAYER_PIN_SIZES[level]
end

local function DisableMinimapRotation()
    if SetCVar then
        SetCVar("rotateMinimap", "0")
    end
end

local function AddRoundMask(frame, texture)
    if not frame.CreateMaskTexture or not texture.AddMaskTexture then
        return
    end

    local mask = frame:CreateMaskTexture()
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
end

local function ApplyAppearance(marker)
    local size = marker.isWorldMapMarker and EasyPartyMarkerDB.worldSize or EasyPartyMarkerDB.size
    local color = COLORS[EasyPartyMarkerDB.color] or COLORS.pink

    marker:SetSize(size, size)
    marker.outer:SetColorTexture(0.02, 0.02, 0.02, 1)
    marker.inner:SetColorTexture(color[1], color[2], color[3], 1)
    local innerSize = math.max(5, math.floor(size * 0.72))
    local coreSize = math.max(2, math.floor(size * 0.22))
    marker.inner:SetSize(innerSize, innerSize)
    marker.core:SetSize(coreSize, coreSize)
end

local function CreateMarker(index)
    local marker = CreateFrame("Frame", nil, Minimap)
    marker:SetFrameStrata("HIGH")
    marker:SetFrameLevel(Minimap:GetFrameLevel() + 12)
    marker:EnableMouse(false)

    marker.outer = marker:CreateTexture(nil, "OVERLAY", nil, 1)
    marker.outer:SetAllPoints()
    AddRoundMask(marker, marker.outer)

    marker.inner = marker:CreateTexture(nil, "OVERLAY", nil, 2)
    marker.inner:SetPoint("CENTER")
    AddRoundMask(marker, marker.inner)

    marker.core = marker:CreateTexture(nil, "OVERLAY", nil, 3)
    marker.core:SetPoint("CENTER")
    marker.core:SetColorTexture(1, 1, 1, 1)
    AddRoundMask(marker, marker.core)

    marker.unit = "party" .. index
    ApplyAppearance(marker)
    marker:Hide()
    markers[index] = marker
end

local function CreateWorldMapMarkers()
    for index = 1, 4 do
        local marker = CreateFrame("Frame", nil, UIParent)
        marker.isWorldMapMarker = true
        marker.unit = "party" .. index
        marker:EnableMouse(false)

        marker.outer = marker:CreateTexture(nil, "OVERLAY", nil, 1)
        marker.outer:SetAllPoints()
        AddRoundMask(marker, marker.outer)

        marker.inner = marker:CreateTexture(nil, "OVERLAY", nil, 2)
        marker.inner:SetPoint("CENTER")
        AddRoundMask(marker, marker.inner)

        marker.core = marker:CreateTexture(nil, "OVERLAY", nil, 3)
        marker.core:SetPoint("CENTER")
        marker.core:SetColorTexture(1, 1, 1, 1)
        AddRoundMask(marker, marker.core)

        ApplyAppearance(marker)
        marker:Hide()
        worldMarkers[index] = marker
    end

end

local function ReplaceMinimapPlayerPointer()
    if EasyPartyMarkerDB.selfEnabled and Minimap and Minimap.SetPlayerTexture then
        Minimap:SetPlayerTexture(GetPlayerPointerTexture())
    end
end

local function CreatePlayerMarker()
    ReplaceMinimapPlayerPointer()
end

local function ReplaceTextureObject(texture)
    if not texture or not texture.GetObjectType or texture:GetObjectType() ~= "Texture" then
        return false
    end

    texture:SetTexture(GetWorldPlayerPointerTexture())
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetVertexColor(1, 1, 1, 1)
    texture:SetAlpha(1)
    nativePlayerPointerTextures[texture] = true
    return true
end

local function ReplaceGroupMembersPlayerTexture(pin)
    if not pin or not pin.SetPinTexture then
        return false
    end

    local ok = pcall(pin.SetPinTexture, pin, "player", GetWorldPlayerPointerTexture())
    if ok and pin.dataProvider and pin.dataProvider.SetUnitPinSize then
        pcall(pin.dataProvider.SetUnitPinSize, pin.dataProvider, "player", GetWorldPlayerPinSize())
    elseif ok and pin.SetPinSize then
        pcall(pin.SetPinSize, pin, "player", GetWorldPlayerPinSize())
    end
    if ok and pin.SetNeedsFullUpdate then
        pcall(pin.SetNeedsFullUpdate, pin)
    end
    return ok
end

local function ReplacePlayerPinTextures(pin)
    if not pin then
        return
    end

    if ReplaceTextureObject(pin) then
        return
    end

    local customTexture = pin.EasyPartyMarkerPointerTexture

    for _, key in ipairs({ "Texture", "texture", "Icon", "icon", "Arrow", "arrow" }) do
        local texture = pin[key]
        if texture and texture ~= customTexture and texture.SetAlpha then
            texture:SetAlpha(0)
        end
    end

    if pin.GetRegions then
        for index = 1, pin:GetNumRegions() do
            local region = select(index, pin:GetRegions())
            if region and region ~= customTexture and region.GetObjectType and region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
            end
        end
    end

    if not customTexture and pin.CreateTexture then
        customTexture = pin:CreateTexture(nil, "OVERLAY", nil, 7)
        customTexture:SetAllPoints(pin)
        pin.EasyPartyMarkerPointerTexture = customTexture
    end

    if customTexture then
        customTexture:SetTexture(GetWorldPlayerPointerTexture())
        customTexture:SetTexCoord(0, 1, 0, 1)
        customTexture:SetVertexColor(1, 1, 1, 1)
        customTexture:SetAlpha(1)
        customTexture:Show()
        nativePlayerPointerTextures[customTexture] = true
    end
end

local function IsWorldMapPlayerPin(pin)
    if not pin then
        return false
    end

    for _, key in ipairs({ "unit", "unitToken", "unitID", "Unit", "UnitToken" }) do
        local ok, value = pcall(function() return pin[key] end)
        if ok and value == "player" then
            return true
        end
    end

    if pin.GetUnit then
        local ok, value = pcall(pin.GetUnit, pin)
        if ok and value == "player" then
            return true
        end
    end

    local name = pin.GetName and pin:GetName()
    local lowerName = name and string.lower(name)
    return lowerName and (string.find(lowerName, "worldmapplayer", 1, true) or string.find(lowerName, "mapcanvasplayer", 1, true))
end

local function IsInsideWorldMap(frame)
    local current = frame
    for _ = 1, 16 do
        if current == WorldMapFrame then
            return true
        end
        if not current or not current.GetParent then
            return false
        end
        current = current:GetParent()
    end
    return false
end

local function RotateNativeWorldMapPointers()
    local facing = GetPlayerFacing and GetPlayerFacing()
    if not facing then
        return
    end

    for texture in pairs(nativePlayerPointerTextures) do
        if texture and texture.SetRotation then
            texture:SetRotation(facing)
        end
    end
end

local function ReplaceWorldMapPlayerPointer()
    if not EasyPartyMarkerDB.selfEnabled or not WorldMapFrame then
        return
    end

    if WorldMapFrame.EnumeratePinsByTemplate then
        pcall(function()
            for pin in WorldMapFrame:EnumeratePinsByTemplate("GroupMembersPinTemplate") do
                ReplaceGroupMembersPlayerTexture(pin)
            end
        end)
    end

    for _, globalName in ipairs({
        "WorldMapPlayer",
        "WorldMapPlayerIcon",
        "WorldMapPlayerPin",
        "WorldMapFramePlayerPin",
    }) do
        ReplacePlayerPinTextures(_G[globalName])
    end

    if WorldMapFrame.GetPlayerPin then
        local ok, pin = pcall(WorldMapFrame.GetPlayerPin, WorldMapFrame)
        if ok then
            ReplacePlayerPinTextures(pin)
        end
    end

    if WorldMapFrame.EnumeratePinsByTemplate then
        for _, template in ipairs({
            "WorldMapPlayerPinTemplate",
            "MapCanvasPlayerPinTemplate",
            "WorldMapUnitPinTemplate",
            "MapCanvasUnitPinTemplate",
        }) do
            pcall(function()
                for pin in WorldMapFrame:EnumeratePinsByTemplate(template) do
                    if template == "WorldMapPlayerPinTemplate" or template == "MapCanvasPlayerPinTemplate" or IsWorldMapPlayerPin(pin) then
                        ReplacePlayerPinTextures(pin)
                    end
                end
            end)
        end
    end

    if EnumerateFrames and WorldMapFrame:IsShown() then
        local frame = EnumerateFrames()
        while frame do
            if IsInsideWorldMap(frame) and IsWorldMapPlayerPin(frame) then
                ReplacePlayerPinTextures(frame)
            end
            frame = EnumerateFrames(frame)
        end
    end

    RotateNativeWorldMapPointers()
end

local function HookGroupMembersPlayerPointer()
    if groupMembersPinHooked or not hooksecurefunc or not GroupMembersPinMixin then
        return
    end

    hooksecurefunc(GroupMembersPinMixin, "OnAcquired", function(pin)
        if EasyPartyMarkerDB and EasyPartyMarkerDB.selfEnabled then
            ReplaceGroupMembersPlayerTexture(pin)
        end
    end)
    groupMembersPinHooked = true
end

local function HookWorldMapPointer()
    HookGroupMembersPlayerPointer()

    if worldMapHooked or not WorldMapFrame or not WorldMapFrame.HookScript then
        return
    end

    WorldMapFrame:HookScript("OnShow", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                ReplaceWorldMapPlayerPointer()
                if UpdateWorldMapMarkers then
                    UpdateWorldMapMarkers()
                end
            end)
        else
            ReplaceWorldMapPlayerPointer()
            if UpdateWorldMapMarkers then
                UpdateWorldMapMarkers()
            end
        end
    end)
    worldMapHooked = true
end

local function RemoveMarker(marker)
    if Pins then
        Pins:RemoveMinimapIcon(REF, marker)
    else
        marker:Hide()
    end
end

local function UpdateMarkers()
    if not EasyPartyMarkerDB.enabled or not HBD or not Pins then
        for _, marker in ipairs(markers) do
            RemoveMarker(marker)
        end
        return
    end

    for _, marker in ipairs(markers) do
        if UnitExists(marker.unit) and UnitIsConnected(marker.unit) then
            local x, y, instanceID = HBD:GetUnitWorldPosition(marker.unit)
            if x and y and instanceID then
                Pins:AddMinimapIconWorld(REF, marker, instanceID, x, y, false)
            else
                RemoveMarker(marker)
            end
        else
            RemoveMarker(marker)
        end
    end
end

local function RemoveWorldMarker(marker)
    if not marker then
        return
    end

    if Pins and marker.worldRegistered then
        Pins:RemoveWorldMapIcon(REF, marker)
    else
        marker:Hide()
    end
    marker.worldRegistered = false
    marker.worldMapID = nil
end

local function PositionWorldMarker(marker, x, y, instanceID, mapID)
    local currentParent = marker:GetParent()
    if marker.worldRegistered and (not currentParent or not currentParent.SetPosition) then
        marker.worldRegistered = false
    end

    if not marker.worldRegistered or marker.worldMapID ~= mapID then
        RemoveWorldMarker(marker)
        Pins:AddWorldMapIconWorld(REF, marker, instanceID, x, y, HBD_PINS_WORLDMAP_SHOW_WORLD)
        marker.worldRegistered = true
        marker.worldMapID = mapID
    end

    local mapX, mapY
    if mapID == 947 then
        mapX, mapY = HBD:GetAzerothWorldMapCoordinatesFromWorld(x, y, instanceID)
    else
        mapX, mapY = HBD:GetZoneCoordinatesFromWorldInstance(x, y, instanceID, mapID)
    end

    local parent = marker:GetParent()
    if mapX and mapY and parent and parent.SetPosition then
        parent:SetPosition(mapX, mapY)
        if parent.SetFrameLevel then
            parent:SetFrameLevel(10000)
        end
        marker:Show()
    else
        marker:Hide()
    end
end

UpdateWorldMapMarkers = function()
    if not HBD or not Pins or not WorldMapFrame or not WorldMapFrame:IsShown() then
        return
    end

    local mapID = WorldMapFrame:GetMapID()
    if not mapID then
        return
    end

    if lastWorldMapID ~= mapID then
        for _, marker in ipairs(worldMarkers) do
            RemoveWorldMarker(marker)
        end
        lastWorldMapID = mapID
        ReplaceWorldMapPlayerPointer()
    end

    for _, marker in ipairs(worldMarkers) do
        if EasyPartyMarkerDB.enabled and UnitExists(marker.unit) and UnitIsConnected(marker.unit) then
            local x, y, instanceID = HBD:GetUnitWorldPosition(marker.unit)
            if x and y and instanceID then
                PositionWorldMarker(marker, x, y, instanceID, mapID)
            else
                RemoveWorldMarker(marker)
            end
        else
            RemoveWorldMarker(marker)
        end
    end

    RotateNativeWorldMapPointers()
end

local function RefreshPartyAppearance()
    for _, marker in ipairs(markers) do
        ApplyAppearance(marker)
    end
    for _, marker in ipairs(worldMarkers) do
        ApplyAppearance(marker)
    end
    UpdateMarkers()
    UpdateWorldMapMarkers()
end

local function RefreshPlayerAppearance()
    ReplaceMinimapPlayerPointer()
    for texture in pairs(nativePlayerPointerTextures) do
        if texture and texture.SetTexture then
            texture:SetTexture(GetWorldPlayerPointerTexture())
        end
    end
    ReplaceWorldMapPlayerPointer()
    RotateNativeWorldMapPointers()
end

function API.GetSettings()
    return EasyPartyMarkerDB
end

function API.GetColors()
    return COLORS, COLOR_ORDER
end

function API.GetPlayerPointerTexture()
    return GetPlayerPointerTexture()
end

function API.GetPlayerPointerTextureFor(colorName, size)
    return GetPlayerPointerTextureFor(colorName, size)
end

function API.SetPartyColor(colorName)
    if not COLORS[colorName] then
        return
    end
    EasyPartyMarkerDB.color = colorName
    RefreshPartyAppearance()
end

function API.SetPartySize(size)
    EasyPartyMarkerDB.size = math.max(6, math.min(30, math.floor((tonumber(size) or DEFAULTS.size) + 0.5)))
    RefreshPartyAppearance()
end

function API.SetPartyWorldSize(size)
    EasyPartyMarkerDB.worldSize = math.max(6, math.min(30, math.floor((tonumber(size) or DEFAULTS.worldSize) + 0.5)))
    RefreshPartyAppearance()
end

function API.SetPlayerColor(colorName)
    if not POINTER_COLOR_SUFFIX[colorName] then
        return
    end
    EasyPartyMarkerDB.selfColor = colorName
    RefreshPlayerAppearance()
end

function API.SetPlayerSize(size)
    EasyPartyMarkerDB.selfSize = math.max(1, math.min(5, math.floor((tonumber(size) or DEFAULTS.selfSize) + 0.5)))
    RefreshPlayerAppearance()
end

function API.SetPlayerWorldSize(size)
    EasyPartyMarkerDB.selfWorldSize = math.max(1, math.min(5, math.floor((tonumber(size) or DEFAULTS.selfWorldSize) + 0.5)))
    RefreshPlayerAppearance()
end

function API.SetMinimapButtonAngle(angle)
    EasyPartyMarkerDB.minimapButtonAngle = tonumber(angle) or DEFAULTS.minimapButtonAngle
end

function API.ResetDefaults()
    EasyPartyMarkerDB.enabled = true
    EasyPartyMarkerDB.size = 10
    EasyPartyMarkerDB.worldSize = DEFAULTS.worldSize
    EasyPartyMarkerDB.color = "pink"
    EasyPartyMarkerDB.selfEnabled = true
    EasyPartyMarkerDB.selfColor = "mint"
    EasyPartyMarkerDB.selfSize = 3
    EasyPartyMarkerDB.selfWorldSize = DEFAULTS.selfWorldSize
    EasyPartyMarkerDB.minimapButtonAngle = DEFAULTS.minimapButtonAngle
    EasyPartyMarkerDB.rotateMap = false
    DisableMinimapRotation()
    RefreshPartyAppearance()
    RefreshPlayerAppearance()
end

local function SetEnabled(enabled)
    EasyPartyMarkerDB.enabled = enabled
    UpdateMarkers()
    Print(enabled and "bright party markers are ON." or "bright party markers are OFF.")
end

local function ShowHelp()
    Print("Use |cffffffff/epm|r to open the marker menu. Commands still work: |cffffffff/epm pink|r, |cffffffff/epm cyan|r, or |cffffffff/epm size 6-30|r.")
end

SLASH_EASYPARTYMARKER1 = "/epm"
SlashCmdList.EASYPARTYMARKER = function(input)
    input = string.lower(strtrim(input or ""))

    if input == "" or input == "menu" then
        if API.ToggleOptions then
            API.ToggleOptions()
        else
            ShowHelp()
        end
        return
    elseif input == "on" then
        SetEnabled(true)
        return
    elseif input == "off" then
        SetEnabled(false)
        return
    elseif COLORS[input] then
        API.SetPartyColor(input)
        Print("marker color changed to " .. input .. ".")
        return
    end

    local xCommand = string.match(input, "^x%s+(%S+)$")
    if xCommand == "on" then
        EasyPartyMarkerDB.selfEnabled = true
        ReplaceMinimapPlayerPointer()
        ReplaceWorldMapPlayerPointer()
        Print("your mint directional arrow is ON.")
        return
    elseif xCommand == "off" then
        Print("the mint arrow replaces WoW's pointer texture; disable the addon and reload to restore the original.")
        return
    end

    local requestedSize = tonumber(string.match(input, "^size%s+(%d+)$"))
    if requestedSize then
        API.SetPartySize(requestedSize)
        Print("marker size changed to " .. EasyPartyMarkerDB.size .. ".")
        return
    end

    ShowHelp()
end

updateFrame:RegisterEvent("ADDON_LOADED")
updateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
updateFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
updateFrame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == ADDON_NAME then
        EasyPartyMarkerDB = EasyPartyMarkerDB or {}
        local previousVersion = tonumber(EasyPartyMarkerDB.version) or 0

        -- Version 1 used a much larger default. Shrink that untouched default
        -- automatically, while preserving any size the player chose herself.
        if not EasyPartyMarkerDB.version and EasyPartyMarkerDB.size == 30 then
            EasyPartyMarkerDB.size = DEFAULTS.size
        end

        if previousVersion < 9 then
            EasyPartyMarkerDB.selfColor = "mint"
            EasyPartyMarkerDB.selfSize = 3
            EasyPartyMarkerDB.minimapButtonAngle = DEFAULTS.minimapButtonAngle
            EasyPartyMarkerDB.rotateMap = false
            EasyPartyMarkerDB.version = DEFAULTS.version
        end

        if previousVersion < 10 then
            EasyPartyMarkerDB.worldSize = DEFAULTS.worldSize
            EasyPartyMarkerDB.selfWorldSize = DEFAULTS.selfWorldSize
            EasyPartyMarkerDB.version = DEFAULTS.version
        end

        for key, value in pairs(DEFAULTS) do
            if EasyPartyMarkerDB[key] == nil then
                EasyPartyMarkerDB[key] = value
            end
        end

        for index = 1, 4 do
            CreateMarker(index)
        end
        CreateWorldMapMarkers()
        CreatePlayerMarker()
        HookWorldMapPointer()
        DisableMinimapRotation()

        if not HBD or not Pins then
            Print("The bundled map helper could not be loaded. Please reinstall Easy Party Marker.")
        end
    elseif event == "ADDON_LOADED" and EasyPartyMarkerDB then
        HookWorldMapPointer()
    elseif EasyPartyMarkerDB then
        UpdateMarkers()
        UpdateWorldMapMarkers()
        ReplaceMinimapPlayerPointer()
        ReplaceWorldMapPlayerPointer()
        DisableMinimapRotation()
    end
end)

updateFrame:SetScript("OnUpdate", function(_, elapsed)
    if not EasyPartyMarkerDB then
        return
    end

    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if elapsedSinceUpdate >= 0.12 then
        elapsedSinceUpdate = 0
        UpdateMarkers()
        UpdateWorldMapMarkers()
    end

end)
