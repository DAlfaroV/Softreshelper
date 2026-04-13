-- SoftResHelper.lua

-- CSV parsing

local function parseCSVLine(line)
    local fields = {}
    local i = 1
    local len = #line
    while i <= len do
        if line:sub(i, i) == '"' then
            local j = i + 1
            while j <= len do
                if line:sub(j, j) == '"' then
                    if line:sub(j+1, j+1) == '"' then
                        j = j + 2
                    else
                        break
                    end
                else
                    j = j + 1
                end
            end
            local field = line:sub(i+1, j-1):gsub('""', '"')
            fields[#fields+1] = field
            i = j + 2
        else
            local j = line:find(",", i, true)
            if j then
                fields[#fields+1] = line:sub(i, j-1)
                i = j + 1
            else
                fields[#fields+1] = line:sub(i)
                break
            end
        end
    end
    return fields
end

local function importCSV(csvText)
    local newData = {}
    local lineNum = 0
    local imported = 0
    local errors = 0

    for line in (csvText .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("\r", "")
        lineNum = lineNum + 1

        if lineNum > 1 and line ~= "" then
            local fields = parseCSVLine(line)
            local itemID = tonumber(fields[2])
            local name   = fields[4]

            if itemID and name and name ~= "" then
                if not newData[itemID] then
                    newData[itemID] = {}
                end
                newData[itemID][name] = (newData[itemID][name] or 0) + 1
                imported = imported + 1
            else
                errors = errors + 1
            end
        end
    end

    return newData, imported, errors
end

-- ============================================================
-- Actions list / clear
-- ============================================================
local qualityColors = {
    [0] = "ff9d9d9d", -- Poor 
    [1] = "ffffffff", -- Common 
    [2] = "ff1eff00", -- Uncommon 
    [3] = "ff0070dd", -- Rare
    [4] = "ffa335ee", -- Epic 
    [5] = "ffff8000", -- Legendary 
    [6] = "ffe6cc80", -- Artifact
    [7] = "ff00ccff", -- Heirloom
}

local function makeItemLink(itemID)
    local name, _, quality = GetItemInfo(itemID)
    if name then
        local color = qualityColors[quality] or "ffffffff"
        return "|c" .. color .. "|Hitem:" .. itemID .. ":0:0:0:0:0:0:0|h[" .. name .. "]|h|r"
    else
        return "|cFFAAAAAA[Item:" .. itemID .. "]|r"
    end
end

local function doList()
    if not SoftResDB or not SoftResDB.reservas then
        print("|cFF888888[SoftRes]|r No data imported.")
        return
    end
    local count = 0
    for _ in pairs(SoftResDB.reservas) do count = count + 1 end
    if count == 0 then
        print("|cFF888888[SoftRes]|r No data imported.")
    else
        print(string.format("|cFF00FF7F[SoftRes]|r %d items reserved:", count))
        for itemID, counts in pairs(SoftResDB.reservas) do
            local parts = {}
            for name, n in pairs(counts) do
                parts[#parts+1] = n > 1 and (name .. " (x" .. n .. ")") or name
            end
            print(makeItemLink(itemID) .. " -> " .. table.concat(parts, ", "))
        end
    end
end

local function doClear()
    SoftResDB.reservas = {}
    SoftResDB.csv = ""
    if SoftResEditBox then SoftResEditBox:SetText("") end
    print("|cFF00FF7F[SoftRes]|r Data Cleared.")
end

-- Window

local importWindow = nil

local function createImportWindow()
    if importWindow then
        if SoftResDB and SoftResDB.csv and SoftResDB.csv ~= "" then
            SoftResEditBox:SetText(SoftResDB.csv)
        end
        importWindow:Show()
        return
    end

    local W, H = 520, 440

    local frame = CreateFrame("Frame", "SoftResImportFrame", UIParent)
    frame:SetSize(W, H)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true, tileSize = 32, edgeSize = 32,
        insets   = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    importWindow = frame

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    title:SetText("SoftRes Helper")

    local btnList = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnList:SetSize(140, 26)
    btnList:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -44)
    btnList:SetText("View res")
    btnList:SetScript("OnClick", doList)

    local btnClear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnClear:SetSize(140, 26)
    btnClear:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -44)
    btnClear:SetText("Clear Data")
    btnClear:SetScript("OnClick", doClear)

    local sep = frame:CreateTexture(nil, "BACKGROUND")
    sep:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    sep:SetSize(W - 40, 4)
    sep:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -78)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -92)
    label:SetText("Import CSV data from softres.it:")
    label:SetTextColor(1, 0.82, 0)

    local editBg = CreateFrame("Frame", nil, frame)
    editBg:SetPoint("TOPLEFT",     frame, "TOPLEFT",  18, -112)
    editBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 50)
    editBg:SetBackdrop({
        bgFile  = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    editBg:SetBackdropColor(0, 0, 0, 0.8)
    editBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local scrollFrame = CreateFrame("ScrollFrame", "SoftResScrollFrame", editBg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     editBg, "TOPLEFT",  6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", editBg, "BOTTOMRIGHT", -26, 6)

    local editBox = CreateFrame("EditBox", "SoftResEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    editBox:SetScript("OnTextChanged", function()
        scrollFrame:UpdateScrollChildRect()
    end)
    scrollFrame:SetScrollChild(editBox)

    if SoftResDB and SoftResDB.csv and SoftResDB.csv ~= "" then
        editBox:SetText(SoftResDB.csv)
    end

    local btnImport = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnImport:SetSize(120, 26)
    btnImport:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 16)
    btnImport:SetText("Import")
    btnImport:SetScript("OnClick", function()
        local text = editBox:GetText()
        if not text or text == "" then
            print("|cFFFF4444[SoftRes]|r Empty.")
            return
        end
        local newData, imported, errors = importCSV(text)
        SoftResDB.reservas = newData
        SoftResDB.csv = text   
        print(string.format("|cFF00FF7F[SoftRes]|r Imported: |cFFFFD700%d|r res. Errors: %d", imported, errors))
        frame:Hide()
    end)

    local btnCancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnCancel:SetSize(100, 26)
    btnCancel:SetPoint("BOTTOMRIGHT", btnImport, "BOTTOMLEFT", -8, 0)
    btnCancel:SetText("Cancel")
    btnCancel:SetScript("OnClick", function()
        frame:Hide()
    end)

    local link = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    link:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 20)
    link:SetText("|cFF4FC3F7softres.it|r")
 
    local linkBtn = CreateFrame("Button", nil, frame)
    linkBtn:SetAllPoints(link)
    linkBtn:SetScript("OnEnter", function()
        link:SetText("|cFF81D4FAsoftres.it|r")
        GameTooltip:SetOwner(linkBtn, "ANCHOR_TOP")
        GameTooltip:SetText("https://softres.it", 1, 1, 1)
        GameTooltip:Show()
    end)
    linkBtn:SetScript("OnLeave", function()
        link:SetText("|cFF4FC3F7softres.it|r")
        GameTooltip:Hide()
    end)
    linkBtn:SetScript("OnClick", function()
        print("|cFF4FC3F7[SoftRes]|r Visit: https://softres.it")
    end)
    frame:Show()
end

-- Init

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    if not SoftResDB then SoftResDB = {} end
    if not SoftResDB.reservas then SoftResDB.reservas = {} end
    if not SoftResDB.csv then SoftResDB.csv = "" end

    GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
        local _, link = tooltip:GetItem()
        if not link then return end

        local itemID = tonumber(link:match("item:(%d+)"))
        if not itemID then return end

        local counts = SoftResDB.reservas[itemID]

        tooltip:AddLine(" ")
        if counts and next(counts) then
            tooltip:AddLine("|cFFFFD700[SoftRes] Res by:|r")
            for name, n in pairs(counts) do
                if n > 1 then
                    tooltip:AddLine("  |cFF00FF7F" .. name .. " |cFFFFD700(x" .. n .. ")|r")
                else
                    tooltip:AddLine("  |cFF00FF7F" .. name .. "|r")
                end
            end
        end

        tooltip:Show()
    end)
end)

-- Comands

SLASH_SOFTRESHELPER1 = "/softres"
SLASH_SOFTRESHELPER2 = "/srs"

SlashCmdList["SOFTRESHELPER"] = function(input)
    local cmd = input:match("^(%S+)") or ""
    cmd = cmd:lower()
    createImportWindow()
end
