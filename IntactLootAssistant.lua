-- upvalue the globals;
local _G = getfenv(0);
local CreateFrame = _G.CreateFrame;
local UIParent = _G.UIParent;
local GetItemInfo = _G.GetItemInfo;
local GameTooltip = _G.GameTooltip;
local tinsert = _G.tinsert;
local string = _G.string;
local string__format = string.format;
local string__sub = string.sub;
local string__len = string.len;
local IsInRaid = _G.IsInRaid;
local UnitIsGroupLeader = _G.UnitIsGroupLeader;
local UnitIsGroupAssistant = _G.UnitIsGroupAssistant;
local UnitInRaid = _G.UnitInRaid;
local C_BattleNet = _G.C_BattleNet;
local C_BattleNet__GetAccountInfoByID = C_BattleNet.GetAccountInfoByID
local LibStub = _G.LibStub;

local name = ...;

_G.IntactLootAssistantDB = _G.IntactLootAssistantDB or {};

local ILA = LibStub('AceAddon-3.0'):NewAddon(name, 'AceConsole-3.0', 'AceHook-3.0', 'AceEvent-3.0');
if not ILA then
    return
end

local BUTTON_WIDTH = 180;

_G.ILA = ILA;

function ILA:OnInitialize()
    self.db = _G.IntactLootAssistantDB;
    self.lootFrames = {};
    self:InitFrame();

    self:RegisterEvent('CHAT_MSG_BN_WHISPER', function(_, message, _, _, _, _, _, _, _, _, _, _, _, bnetIDAccount, _)
        self:HandleBnetWhisper(message, bnetIDAccount)
    end)
    self:RegisterEvent('CHAT_MSG_WHISPER', function(_, message, characterName, _)
        self:HandleWhisper(message, characterName)
    end)
    self:RegisterEvent('CHAT_MSG_OFFICER', function(_, message, characterName, _)
        self:HandleWhisper(message, characterName)
    end)

    --local msg = 'got |cffa335ee|Hitem:184031::::::::60:250::82:4:7189:6652:1472:6646:1:28:751:::|h[Sanguine Vintage]|h|r for grabs';
    --self:CreateLootFrame(
    --        'Numedain-Draenor',
    --        self:ExtractItemLink(msg),
    --        msg
    --);
end

function ILA:HandleWhisper(message, characterName)
    self:ProcessMessage(message, characterName)
end

function ILA:HandleBnetWhisper(message, bnetIDAccount)
    local accountInfo = C_BattleNet__GetAccountInfoByID(bnetIDAccount)
    if (accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.characterName and accountInfo.gameAccountInfo.realmName) then
        local characterName = accountInfo.gameAccountInfo.characterName .. '-' .. accountInfo.gameAccountInfo.realmName
        self:ProcessMessage(message, characterName)
    end
end

function ILA:ProcessMessage(message, characterName)
    if (not self.db.override and (not IsInRaid() or not UnitIsGroupLeader('player') or not UnitIsGroupAssistant('player'))) then
        return ;
    end
    if (not self.db.override and not UnitInRaid(characterName)) then return ; end

    local itemLink = self:ExtractItemLink(message)
    if (not itemLink) then return ; end

    self:CreateLootFrame(characterName, itemLink, message);
end

function ILA:CreateLootFrame(looterName, itemLink, extraMessage)
    local isCreated = false;
    for i = 1, #self.lootFrames, 1 do
        local lootFrame = self.lootFrames[i];
        if (isCreated == false and lootFrame.isUsed == false) then
            local itemInfoTable = { GetItemInfo(itemLink) };
            lootFrame.isUsed = true;
            isCreated = true;
            lootFrame.looterName = looterName;
            lootFrame.itemLink = itemLink;
            lootFrame.itemContainer.texture:SetTexture(itemInfoTable[10]);
            lootFrame.description:SetText(string__format(
                    'Looter: %s - Item type: %s\nMessage: %s',
                    looterName,
                    self.prettyItemLink:GetPrettyItemLink(itemLink),
                    extraMessage
            ));
            lootFrame:Show();
        end
    end
    self.frameHeader:Show();
end

function ILA:GetItemSlot(item)
    local itemInfo = { GetItemInfo(item) };
    local itemEquipLoc = itemInfo[9];
    if (_G[itemEquipLoc]) then
        return _G[itemEquipLoc];
    end
    if (string__sub(itemEquipLoc, 1, 7) == 'INVTYPE') then
        local slot = string__sub(itemEquipLoc, 9);
        if (string__len(slot) > 2) then
            return slot;
        end
    end
    return 'MISC';
end

function ILA:ExtractItemLink(message)
    return message:match('(|c[^|]+|Hitem:%d+[^|]+|h[^|]+|h|r)');
end

function ILA:InitFrame()
    self.frameHeader = CreateFrame('Frame', 'ILAFrameHeader', UIParent);
    self.frameHeader:SetHeight(45) --+ (80*7));
    self.frameHeader:SetWidth(10 + 60 + 10 + BUTTON_WIDTH + 10 + BUTTON_WIDTH + 10);
    self.frameHeader:SetPoint('TOPLEFT', (UIParent:GetWidth() / 6), -(UIParent:GetHeight() / 4));
    self.frameHeader.textureBorder = self.frameHeader:CreateTexture();
    self.frameHeader.textureBorder:SetPoint('TOPLEFT', 0, 0);
    self.frameHeader.textureBorder:SetSize(10 + 60 + 10 + BUTTON_WIDTH + 10 + BUTTON_WIDTH + 10, 45);
    self.frameHeader.textureBackground = self.frameHeader:CreateTexture();
    local mx, my = self.frameHeader.textureBorder:GetSize();
    --print(mx, my);
    self.frameHeader.textureBackground:SetSize(mx - 4, my - 4);
    self.frameHeader.textureBackground:SetPoint('TOPLEFT', self.frameHeader.textureBorder, 2, -2);
    self.frameHeader.textureBorder:SetColorTexture(.2, .2, .2);
    self.frameHeader.textureBackground:SetColorTexture(.05, .05, .05);
    self.frameHeader.textureBackground:SetDrawLayer('ARTWORK', 1);

    self.frameHeader.text = self.frameHeader:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge');
    self.frameHeader.text:SetPoint('CENTER', self.frameHeader.textureBackground);
    self.frameHeader.text:SetDrawLayer('Artwork', 2);
    self.frameHeader.text:SetText('A raider linked you this...');
    self.frameHeader:SetScript('OnMouseDown', function()
        self.frameHeader:SetMovable(true);
        self.frameHeader:StartMoving();
    end);
    self.frameHeader:SetScript('OnMouseUp', function()
        self.frameHeader:SetMovable(false);
        self.frameHeader:StopMovingOrSizing();
    end);

    self.frameHeader:Hide();

    self.frameContainer = CreateFrame('Frame', 'ILAFrameContainer', self.frameHeader);
    -- width: 10 + 60 + 10 + BUTTON_WIDTH + 10 + BUTTON_WIDTH + 10
    -- height: 10 + 60 + 10
    self.frameContainer:SetHeight((80 * 7) + 0); -- 7 frames
    self.frameContainer:SetWidth((10 + 60 + 10 + BUTTON_WIDTH + 10 + BUTTON_WIDTH + 10));
    self.frameContainer:SetPoint('BOTTOMLEFT', self.frameHeader, 0, -(80 * 7));

    --self.frameContainer:SetPoint('CENTER', 0, 0);
    for i = 1, 7, 1 do
        -- create 7 frames;
        self:InitLootframe(i);
    end
end

function ILA:InitLootframe(index)
    local previousFrame = _G['ILALootframe'.. (index -1)] or self.frameHeader;
    local lootFrame = CreateFrame('Frame', 'ILALootframe' .. index, self.frameContainer);
    lootFrame.itemLink = nil;
    lootFrame.looterName = nil;
    lootFrame.isUsed = false;

    lootFrame:SetHeight(80);
    lootFrame:SetWidth(10 + 30 + 30 + 10 + BUTTON_WIDTH + 10 + BUTTON_WIDTH + 10);
    lootFrame:SetPoint('TOPLEFT', previousFrame, 'BOTTOMLEFT');
    --lootFrame:SetPoint('TOPLEFT', 0, -(((index - 1) * 80) + 0));

    lootFrame.border = lootFrame:CreateTexture();
    lootFrame.border:SetColorTexture(.2, .2, .2);
    lootFrame.border:SetAllPoints();
    lootFrame.border:SetDrawLayer('Background', 1);

    lootFrame.background = lootFrame:CreateTexture();
    lootFrame.background:SetColorTexture(0.05, 0.05, 0.05);
    lootFrame.background:SetWidth(lootFrame:GetWidth() - 4);
    lootFrame.background:SetHeight(lootFrame:GetHeight() - 4);
    lootFrame.background:SetPoint('TOPLEFT', 2, -2);
    lootFrame.background:SetDrawLayer('Background', 2);

    lootFrame.itemContainer = CreateFrame('FRAME', nil, lootFrame);
    lootFrame.itemContainer:SetSize(60, 60);
    lootFrame.itemContainer:SetPoint('TOPLEFT', 10, -10);
    lootFrame.itemContainer.texture = lootFrame.itemContainer:CreateTexture();
    lootFrame.itemContainer.texture:SetAllPoints();

    lootFrame.rollButton = CreateFrame('Button', nil, lootFrame, 'UIPanelButtonTemplate');
    lootFrame.rollButton:SetWidth(BUTTON_WIDTH);
    lootFrame.rollButton:SetHeight(30);
    lootFrame.rollButton:SetPoint('TOPLEFT', 10 + 60 + 10, -40);
    lootFrame.rollButton.text:SetText('Roll');

    lootFrame.cancelButton = CreateFrame('Button', nil, lootFrame, 'UIPanelButtonTemplate');
    lootFrame.cancelButton:SetWidth(BUTTON_WIDTH);
    lootFrame.cancelButton:SetHeight(30);
    lootFrame.cancelButton:SetPoint('TOPLEFT', 10 + 60 + 10 + BUTTON_WIDTH + 10, -40);
    lootFrame.cancelButton.text:SetText('Cancel');

    lootFrame.description = lootFrame:CreateFontString(nil, 'ARTWORK', 'GameFontNormal');
    lootFrame.description:SetSize((BUTTON_WIDTH * 2) + 10, 30);
    lootFrame.description:SetPoint('TOPLEFT', 10 + 60 + 10 + 3, -10);
    lootFrame.description:SetJustifyH('LEFT');
    lootFrame.description:SetText('This text should not be visible');

    lootFrame.itemContainer:SetScript('onEnter', function() self:ShowItemTooltip(lootFrame); end);
    lootFrame.itemContainer:SetScript('onLeave', function() GameTooltip:Hide(); end);
    lootFrame.cancelButton:SetScript('OnClick', function() self:HideLootFrame(lootFrame); end);
    lootFrame.rollButton:SetScript('OnClick', function() self:RollItem(lootFrame); end);
    lootFrame:Hide();

    tinsert(self.lootFrames, lootFrame);
end

function ILA:ShowItemTooltip(lootFrame)
    GameTooltip:SetAnchorType('ANCHOR_CURSOR');
    GameTooltip:SetOwner(UIParent, 'ANCHOR_CURSOR');
    GameTooltip:SetHyperlink(lootFrame.itemLink);
    GameTooltip:Show();
end

function ILA:HideLootFrame(lootFrame)
    lootFrame.isUsed = false;
    lootFrame:Hide();
    local allHidden = true;
    for i = 1, #self.lootFrames do
        if self.lootFrames[i]:IsVisible() then
            allHidden = false;
        end
    end
    if allHidden then
        self.frameHeader:Hide();
    end
end

function ILA:RollItem(lootFrame)
    self:HideLootFrame(lootFrame);
end
