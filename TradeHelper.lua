-- Original work reference - https://github.com/cherrymathew/WoWLuaHelloWorld
-- 
-- References used for the current framework
-- Button Generator - http://wowprogramming.com/snippets/LOL_CLASS_31
-- Quantity Box - http://eu.battle.net/wow/en/forum/topic/1622897526
-- Dropdown Box - http://wowprogramming.com/snippets/Create_UI-styled_dropdown_menu_10
-- ComboPoints (Most of the coding style has been taken from here) - http://www.curse.com/addons/wow/cbp 

local TradeHelper = CreateFrame("frame")



--Variables

local scale = 1
local prevpos = false
local itemList = {};
local timerFrame = nil;
local advertiseInterval = 5.0;
local timeSinceLastAdvertisement = 0
local quantityTypes = {
	"Individual", -- ID 1
	"Stacks", -- ID 2
}

--/Variables



--Events

--
-- Initialize the frame to accept events
--
TradeHelper:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)

--
-- Initializes the slash commands
--
function TradeHelper:ADDON_LOADED(addon)
	if addon ~= "TradeHelper" then return end
	SlashCmdList["TRADEHELPER"] = TradeHelper_Init;
	
	SLASH_TRADEHELPER1 = "/th"; -- an alias to /hwshow
	SLASH_TRADEHELPER2 = "/tradehelper"; 
	
	DEFAULT_CHAT_FRAME:AddMessage("|r:"..colorhex("#FF0000").."Trade Helper v0.0 |r Loaded");
end


TradeHelper:RegisterEvent("ADDON_LOADED")

--
-- Initializates the TradeHelper Addon
--
function TradeHelper_Init(args) 
	local _,_,command,options = string.find(args,"([%w%p]+)%s*(.*)$");
	
	if (command) then
		command = string.lower(command);
	end

	if(command == nil or command == "") then TradeHelper_SlashHelp()
	elseif(command == "show" or command == "s") then HelloWorldForm:Show();
	elseif(command == "hide" or command == "h") then HelloWorldForm:Hide();
	else
		TradeHelper_SlashHelp();
	end
	  
	-- Initialize the Tooltip Information Capture
	TradeHelper_InitItemCapture();
	
	-- Sets the backdrop to be transparent
	HelloWorldForm:SetBackdrop(StaticPopup1:GetBackdrop())
	
	--- Initialize the trade chat watcher
	TradeHelper_TradeChatWatcher()
end

--
-- Initializes all the events and handlers for a given frame
--
function TradeHelper_SetOrHookHandler(frame, event, handler)
	if frame:GetScript(event) then -- Checks if the event has a handler
		frame:HookScript(event, handler) -- if not we hook out handler
	else
		frame:SetScript(event, handler) -- else set our function has the handler
	end
end

------- WTS Section Begins --------

-- 
-- Initializes the hooks and handlers for capturing information
-- from an Item Hyperlink
--
function TradeHelper_InitItemCapture()
	-- Creates copy of "General Chat Frame"
	local frame = getglobal("ChatFrame"..1);
	if frame then
		TradeHelper_SetOrHookHandler(frame,"onHyperlinkClick", TradeHelper_ItemCapture)
	end
end	

--
-- Captures the data from the tooltip
--
function TradeHelper_ItemCapture(self, linkData)
	local linkType, itemID = string.split(":", linkData)
	if(linkType == 'item') then
		itemIcon = GetItemIcon(itemID);
		TradeHelper_GenerateButton(itemIcon, itemID);
	end
end


--
-- Generates a button containing the icon of the tooltip data captured
-- and also a Quantity Box to enter quantities
--
-- TODO:
-- 1. Better alignment of generated rows of Buttons and Boxes
-- 2. Table to store and retrieve Data after logging off
-- 3. Implement basic trading logic (yet to be split into micro tasks)
--
function TradeHelper_GenerateButton(itemIcon, itemID) 
	if itemList[itemID] == true then
		return;
	end
	
	local button = CreateFrame("Button", itemID.."-button", HelloWorldForm, "ActionButtonTemplate")
	local editBox = CreateFrame("EditBox", itemID.."-editBox", HelloWorldForm, "InputBoxTemplate")
	local dropdownBox = CreateFrame("Button", itemID.."-dropdownBox", HelloWorldForm, "UIDropDownMenuTemplate")
	
	-- Initialize each of the UI elements
	button:SetScale(scale)
	
	editBox:SetWidth(35)
	editBox:SetHeight(50)
	editBox:SetAutoFocus(false)
	editBox:SetNumeric(true)
	editBox:SetNumber(1)
	
	dropdownBox:ClearAllPoints()
	dropdownBox:Show()

	UIDropDownMenu_Initialize(dropdownBox, TradeHelper_InitializeDropdownBox)
	UIDropDownMenu_SetWidth(dropdownBox, 100);
	UIDropDownMenu_SetButtonWidth(dropdownBox, 124)
	UIDropDownMenu_SetSelectedID(dropdownBox, 1)
	UIDropDownMenu_JustifyText(dropdownBox, "LEFT")

	if not prevpos then
		button:SetPoint("TOPLEFT",HelloWorldForm,"TOPLEFT",17,-30)
		editBox:SetPoint("TOPLEFT",HelloWorldForm,"TOPLEFT",73,-23.5)
		dropdownBox:SetPoint("TOPLEFT",HelloWorldForm,"TOPLEFT",130,-30)
	else 
		button:SetPoint("TOP",prevpos,"BOTTOM",0,-4)
		--editBox:SetPoint("TOP",prevposBox,"BOTTOM",0, 2)
		editBox:SetPoint("TOPLEFT",prevpos,"TOPLEFT", 55, -29)
		dropdownBox:SetPoint("TOP",prevposDropdownBox,"BOTTOM",0,-8)
	end

	_G[button:GetName().."Icon"]:SetTexture(itemIcon)
	_G[button:GetName().."Icon"]:SetTexCoord(0, 1, 0, 1)   
	
  
	button:SetScript("OnClick", function() TradeHelper_AdvertiseItem(itemID, editBox:GetNumber(), UIDropDownMenu_GetSelectedID(dropdownBox)) end)

	editBox:SetScript("OnEnterPressed", function (self) 
				editBox:ClearFocus(); -- clears focus from editbox, (unlocks key bindings, so pressing W makes your character go forward.
	end );
	editBox:Show()

	prevpos = itemID.."-button"
	prevposBox = itemID.."-editBox"
	prevposDropdownBox = itemID.."-dropdownBox"
	itemList[itemID] = true
	
	advertiseButton:SetScript("OnClick", function() TradeHelper_AdvertiseItems(itemList) end)
	stopAdvertiseButton:SetScript("OnClick", TradeHelper_stopAdvertise) 
end

--
-- Callback for whenever the drop down changes
--
function TradeHelper_DropdownBoxOnClick(self, frame)
	UIDropDownMenu_SetSelectedID(frame, self:GetID())
end

--
-- Initialization of the dropdown and filling up with values
--
function TradeHelper_InitializeDropdownBox(self, level)
	local info = UIDropDownMenu_CreateInfo()
	for k,v in pairs(quantityTypes) do
		info = UIDropDownMenu_CreateInfo()
		info.text = v
		info.value = v
		info.func = function(this) TradeHelper_DropdownBoxOnClick(this, self) end
		UIDropDownMenu_AddButton(info, level)
	end 
end

--
-- Advertise the Item into Trade Chat (Channel 2), when the Icon is clicked
--
function TradeHelper_AdvertiseItem(itemID, quantity, quantityType)
	local index, name = GetChannelName(2) -- It finds Trade is a channel at index 2
	local quantityString = (quantityType == 2 and " Stack(s)." or ".")

	if (index ~= nil) then 
		local itemName, itemLink = GetItemInfo(itemID)
		SendChatMessage("WTS "..itemLink.." x "..quantity..quantityString, "CHANNEL", nil, index);
	end
end

--
-- Avertise a list of items, each item will be displayed one after another
-- in the chat window in Trade Channel
--
function TradeHelper_AdvertiseItems(itemList)
	for itemID in pairs(itemList) do
		local editBox = itemID.."-editBox"
		local dropdownBox = itemID.."-dropdownBox"
		TradeHelper_AdvertiseItem(itemID, _G[editBox]:GetNumber(), UIDropDownMenu_GetSelectedID(_G[dropdownBox]))
	end
	
	if (timerFrame == nil) then
		timerFrame = CreateFrame("frame")
		advertiseInterval = 5.0;
		timerFrame:SetScript("OnUpdate", function(self,elapsed) TradeHelper_AdvertiseItemsPeriodic(self,elapsed,itemList) end)
	end
end

--
-- OnUpdate Callback for a timer frame, which advertises the items in the trade
-- channel in a fixed periodic interval
-- 
function TradeHelper_AdvertiseItemsPeriodic(self, elapsed, itemList)
	timeSinceLastAdvertisement = timeSinceLastAdvertisement + elapsed; 	

	if(itemList ~= nil) then
		if (timeSinceLastAdvertisement > advertiseInterval) then
			TradeHelper_AdvertiseItems(itemList)
			timeSinceLastAdvertisement = 0;
		end
	end
end

--
-- Stub function to stop advertisement
-- Currently just sets a huge time interval to prevent advertisement spam
--
function TradeHelper_stopAdvertise()
	advertiseInterval = 50000000000.0;
end

------- WTS Section Ends --------

------- WTB Section Begins --------

--
-- Initializes the hooks and callbacks for watching tradechat, the callback
-- is a parser to extract potential trading information
--
function TradeHelper_TradeChatWatcher()
	local frame = CreateFrame("Frame");
	
	frame:RegisterEvent("CHAT_MSG_CHANNEL")
	frame:SetScript("OnEvent", TradeHelper_TradeChatParser)
end

--
-- Stub code for the trade chat parser
--
function TradeHelper_TradeChatParser(self, event, ...)
	local message, author = ...
	local channelName = select(4, ...)
	local channelNo = select(8, ...)
	local name = UnitName("player")
	
	if (name ~= author) then
		print(author.." "..message.." "..channelName.." "..channelNo)
	end
end

------- WTB Section Begins --------

--
-- Some stub code for help
--
function TradeHelper_SlashHelp()
	TradeHelper_Print("Type /tradehelper show to show the UI");
end

--
-- Generic output function to chat frame
-- 
function TradeHelper_Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(colorhex("#FF0000").."|r:"..colorhex("#FF0000").."TradeHelper".."|r:: " .. msg);
end

--/Events



--Private Functions

function colorhex(hex)
	if(string.sub(hex, 1,1) == "#") then
		hex = string.sub(hex, 2);
	end
	
	local col = "|c00"..hex;
	return col;	
end

--/Private Functions


