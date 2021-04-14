-- upvalue the globals;
local _G = getfenv(0);
local CreateFrame = _G.CreateFrame;
local RELIC_TOOLTIP_TYPE = _G.RELIC_TOOLTIP_TYPE;
local ITEM_LEVEL = _G.ITEM_LEVEL;
local GameFontNormal = _G.GameFontNormal;
local UIParent = _G.UIParent;
local GetItemInfo = _G.GetItemInfo;
local string = _G.string;
local LE_ITEM_CLASS_WEAPON = _G.LE_ITEM_CLASS_WEAPON;
local LE_ITEM_CLASS_GEM = _G.LE_ITEM_CLASS_GEM;
local LE_ITEM_CLASS_ARMOR = _G.LE_ITEM_CLASS_ARMOR;
local LE_ITEM_ARMOR_RELIC = _G.LE_ITEM_ARMOR_RELIC;
local tonumber = _G.tonumber;
local LibStub = _G.LibStub;
local table__insert = _G.table.insert;
local table__concat = _G.table.concat;

local name = ...;

local ILA = LibStub('AceAddon-3.0'):GetAddon(name);
if not ILA then return ; end

ILA.prettyItemLink = ILA.prettyItemLink or {};
local module = ILA.prettyItemLink;

local PATTERN_RELIC_TOOLTIP_TYPE = RELIC_TOOLTIP_TYPE:gsub('%%s', '(.+)');
local PATTERN_ITEM_LEVEL = ITEM_LEVEL:gsub('%%d', '(%%d+)');;

local function EscapeSearchString(str)
    return str:gsub('(%W)', '%%%1');
end

function module:CreateEmptyTooltip()
    local tooltip = CreateFrame('GameTooltip');
    local leftside, rightside = {}, {};
    local L, R;
    for i = 1, 6 do
        L, R = tooltip:CreateFontString(), tooltip:CreateFontString();
        L:SetFontObject(GameFontNormal);
        R:SetFontObject(GameFontNormal);
        tooltip:AddFontStrings(L, R);
        leftside[i] = L;
        rightside[i] = R;
    end
    tooltip.leftside = leftside;
    tooltip.rightside = rightside;
    return tooltip;
end

function module:GetRealItemLevel(itemLink)
    local realIlvl;

    if itemLink ~= nil then
        self.tooltip = self.tooltip or self:CreateEmptyTooltip();
        self.tooltip:SetOwner(UIParent, 'ANCHOR_NONE');
        self.tooltip:ClearLines();
        self.tooltip:SetHyperlink(itemLink);

        local t = self.tooltip.leftside[2]:GetText();
        if t ~= nil then
            realIlvl = t:match(PATTERN_ITEM_LEVEL);
        end
        -- ilvl can be in the 2nd or 3rd line dependng on the tooltip; if we didn't find it in 2nd, try 3rd
        if realIlvl == nil then
            t = self.tooltip.leftside[3]:GetText();
            if t ~= nil then
                realIlvl = t:match(PATTERN_ITEM_LEVEL);
            end
        end
        self.tooltip:Hide();

        -- if realILVL is still nil, we couldn't find it in the tooltip - try grabbing it from getItemInfo, even though
        --   that doesn't return upgrade levels
        if realIlvl == nil then
            _, _, _, realIlvl, _, _, _, _, _, _, _ = GetItemInfo(itemLink);
        end
    end

    if realIlvl == nil then
        return 0;
    else
        return tonumber(realIlvl);
    end
end

function module:GetRelicType(itemLink)
    local relicType;

    if itemLink ~= nil then
        self.tooltip = self.tooltip or self:CreateEmptyTooltip();
        self.tooltip:SetOwner(UIParent, 'ANCHOR_NONE');
        self.tooltip:ClearLines();
        self.tooltip:SetHyperlink(itemLink);
        local text = self.tooltip.leftside[2]:GetText();

        local index = 1;
        while not relicType and self.tooltip.leftside[index] do
            text = self.tooltip.leftside[index]:GetText();
            if text ~= nil then
                relicType = text:match(PATTERN_RELIC_TOOLTIP_TYPE);
            end
            index = index + 1;
        end

        self.tooltip:Hide();
    end

    return relicType;
end

function module:ItemHasSockets(itemLink)
    local result = false;
    self.socketTooltip = self.socketTooltip or
            CreateFrame('GameTooltip', 'ItemLinkLevelSocketTooltip', nil, 'GameTooltipTemplate');
    self. socketTooltip:SetOwner(UIParent, 'ANCHOR_NONE');
    self.socketTooltip:ClearLines();
    for i = 1, 30 do
        local texture = _G[self.socketTooltip:GetName() .. 'Texture' .. i];
        if texture then
            texture:SetTexture(nil);
        end
    end
    self.socketTooltip:SetHyperlink(itemLink);
    for i = 1, 30 do
        local texture = _G[self.socketTooltip:GetName() .. 'Texture' .. i];
        local textureName = texture and texture:GetTexture();

        if textureName then
            local canonicalTextureName = string.gsub(string.upper(textureName), '\\', '/');
            result = string.find(canonicalTextureName, EscapeSearchString('ITEMSOCKETINGFRAME/UI-EMPTYSOCKET-'));
        end
    end
    return result;
end

function module:GetPrettyItemLink(itemLink)
    local _, _, _, _, _, _, itemSubType, _, itemEquipLoc, _, _, itemClassId, itemSubClassId = GetItemInfo(itemLink);
    if (itemClassId == LE_ITEM_CLASS_WEAPON or itemClassId == LE_ITEM_CLASS_GEM or itemClassId == LE_ITEM_CLASS_ARMOR) then
        local itemString = string.match(itemLink, 'item[%-?%d:]+');
        local _, _, color = string.find(
                itemLink,
                '|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*):?(%-?%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?'
        );
        local iLevel = self:GetRealItemLevel(itemLink);

        local attrs = {};
        if (itemSubType ~= nil) then
            if (itemClassId == LE_ITEM_CLASS_ARMOR and itemSubClassId == 0) then
                -- don't display Miscellaneous for rings, necks and trinkets
            elseif (itemClassId == LE_ITEM_CLASS_ARMOR and itemEquipLoc == 'INVTYPE_CLOAK') then
                -- don't display Cloth for cloaks
            else
                table__insert(attrs, itemSubType);
                --table.insert(attrs, itemSubType:sub(0, 1));
            end
            if (itemClassId == LE_ITEM_CLASS_GEM and itemSubClassId == LE_ITEM_ARMOR_RELIC) then
                local relicType = self:GetRelicType(itemLink);
                table__insert(attrs, relicType);
            end
        end
        if (itemEquipLoc ~= nil and _G[itemEquipLoc] ~= nil) then table__insert(attrs, _G[itemEquipLoc]); end
        if (iLevel ~= nil) then
            local txt = iLevel;
            if (self:ItemHasSockets(itemLink)) then txt = txt .. '+S'; end
            table__insert(attrs, txt);
        end

        local newItemName = table__concat(attrs, ' ');
        return '|cff' .. color .. '|H' .. itemString .. '|h[' .. newItemName .. ']|h|r';
    end
    return itemLink;
end