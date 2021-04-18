-- upvalue the globals;
local _G = getfenv(0);
local CreateFrame = _G.CreateFrame;
local GameFontNormal = _G.GameFontNormal;
local UIParent = _G.UIParent;
local LibStub = _G.LibStub;
local CLOSE = _G.CLOSE;
local select = _G.select;
local math__min = _G.math.min;
local math__max = _G.math.max;
local tinsert = _G.tinsert;
local table__sort = _G.table.sort;
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS;
local UnitClassBase = _G.UnitClassBase;
local string__format = _G.string.format;
local CreateColor = _G.CreateColor;
local pairs = _G.pairs;

local name = ...;

local ILA = LibStub('AceAddon-3.0'):GetAddon(name);
if not ILA then return ; end

ILA.rollTrackerFrame = ILA.rollTrackerFrame or {};
local module = ILA.rollTrackerFrame;

function module:round(num)
    return num + (2 ^ 52 + 2 ^ 51) - (2 ^ 52 + 2 ^ 51)
end

function module:GetMessageFrame()
    return self.messageFrame;
end

function module:Clear()
    self:GetMessageFrame():Clear();
end

function module:ClearAndHide()
    self:Clear();
    self:HideFrame();
end

function module:AddMessage(message)
    self:GetMessageFrame():AddMessage(message);
end

function module:ShowFrame()
    self.frame:Show();
end

function module:HideFrame()
    self.frame:Hide();
end

function module:WrapTextInClassColor(unit, text)
    local className = UnitClassBase(unit);
    return self.colors[className]:WrapTextInColorCode(text)
end

function module:FillRollFrame(currentRolls)
    self:Clear();
    local clonedRolls = {}
    local authorRolls = {};
    local highestRolls = {};

    for i = 1, #currentRolls do
        local currentRoll = {
            author = currentRolls[i].author,
            rollResult = currentRolls[i].rollResult,
            rollMin = currentRolls[i].rollMin,
            rollMax = currentRolls[i].rollMax,
            rank = 0,
        };
        tinsert(clonedRolls, currentRoll);

        currentRoll.legal = true;
        if (authorRolls[currentRoll.author]) then
            currentRoll.legal = false;
        end
        if (currentRoll.rollMin ~= 1 or currentRoll.rollMax ~= 100) then
            currentRoll.legal = false;
        end

        if ((ILA.db.debug and ILA.db.override) or currentRoll.legal) then
            tinsert(highestRolls, currentRoll);
        end
        authorRolls[currentRoll.author] = true;
    end
    table__sort(highestRolls, function(a, b)
        return a.rollResult > b.rollResult;
    end);

    for i = 1, #highestRolls do
        local currentRoll = highestRolls[i];
        if (highestRolls[i - 1] and highestRolls[i - 1].rollResult == currentRoll.rollResult) then
            currentRoll.rank = highestRolls[i - 1].rank;
            currentRoll.sharedRank = true;
            highestRolls[i - 1].sharedRank = true;
        else
            currentRoll.sharedRank = false;
            currentRoll.rank = i;
        end
    end

    NPG:browser(clonedRolls);

    for i = 1, #clonedRolls do
        local currentRoll = clonedRolls[i];
        self:AddMessage(self:BuildRollMessage(currentRoll));
    end

    self:ShowFrame();
end

function module:BuildRollMessage(rollInfo)
    local color = self.colors.default;
    local wrappedRoller = self:WrapTextInClassColor(rollInfo.author, rollInfo.author);
    if (rollInfo.rank == 1) then
        color = self.colors.green;
    end
    if (not rollInfo.legal) then
        color = self.colors.red;
    end

    return color:WrapTextInColorCode(string__format(
            '%d%s : %s rolled %d (%d-%d)',
            rollInfo.rank,
            rollInfo.sharedRank and '#' or '',
            wrappedRoller,
            rollInfo.rollResult,
            rollInfo.rollMin,
            rollInfo.rollMax
    ));
end

function module:Init()
    self.colors = {};
    for k, v in pairs(RAID_CLASS_COLORS) do
        self.colors[k] = v;
    end
    self.colors.red = CreateColor(1, 0, 0);
    self.colors.green = CreateColor(0, 1, 0);
    self.colors.default = CreateColor(1, 1, 1);

    self.frame = CreateFrame("Frame", nil, UIParent);
    self.frame.width = 250;
    self.frame.height = 250;
    self.frame:SetFrameStrata("FULLSCREEN_DIALOG");
    self.frame:SetSize(self.frame.width, self.frame.height);
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
    self.frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    });
    self.frame:SetBackdropColor(0, 0, 0, 1);
    self.frame:EnableMouse(true);
    self.frame:EnableMouseWheel(true);
    self.frame:SetMovable(true);
    self.frame:RegisterForDrag("LeftButton");
    self.frame:SetScript("OnDragStart", self.frame.StartMoving);
    self.frame:SetScript("OnDragStop", self.frame.StopMovingOrSizing);

    -- Close button
    local closeButton = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate");
    closeButton:SetPoint("BOTTOM", 0, 10);
    closeButton:SetHeight(25);
    closeButton:SetWidth(70);
    closeButton:SetText(CLOSE);
    closeButton:SetScript("OnClick", function() self:HideFrame(); end)
    self.frame.closeButton = closeButton;

    -- ScrollingMessageFrame
    self.messageFrame = CreateFrame("ScrollingMessageFrame", nil, self.frame);
    self.messageFrame:SetPoint("CENTER", 15, 20);
    self.messageFrame:SetSize(self.frame.width, self.frame.height - 50);
    self.messageFrame:SetFontObject(GameFontNormal);
    self.messageFrame:SetTextColor(1, 1, 1, 1) -- default color;
    self.messageFrame:SetJustifyH("LEFT");
    self.messageFrame:SetFading(false);
    self.messageFrame:SetMaxLines(300);
    self.frame.messageFrame = self.messageFrame;

    -- Scroll bar
    local scrollBar = CreateFrame("Slider", nil, self.frame, "UIPanelScrollBarTemplate");
    scrollBar:SetPoint("RIGHT", self.frame, "RIGHT", -10, 10);
    scrollBar:SetSize(30, self.frame.height - 90);
    scrollBar:SetMinMaxValues(0, 9);
    scrollBar:SetValueStep(1);
    scrollBar.scrollStep = 1;
    self.frame.scrollBar = scrollBar;

    scrollBar:SetScript("OnValueChanged", function(_, value)
        local rounded = self:round(value);
        self.messageFrame:SetScrollOffset(select(2, scrollBar:GetMinMaxValues()) - rounded);
    end);

    self.frame:SetScript("OnMouseWheel", function(_, delta)
        local cur_val = scrollBar:GetValue();
        local min_val, max_val = scrollBar:GetMinMaxValues();

        if delta < 0 and cur_val < max_val then
            cur_val = math__min(max_val, cur_val + 1);
            scrollBar:SetValue(cur_val);
        elseif delta > 0 and cur_val > min_val then
            cur_val = math__max(min_val, cur_val - 1);
            scrollBar:SetValue(cur_val);
        end
    end)

    self:HideFrame();
end
