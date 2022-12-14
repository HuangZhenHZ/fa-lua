--*****************************************************************************
--* File: lua/modules/ui/lobby/lobby.lua
--* Author: Chris Blackwell
--* Summary: Game selection UI
--*
--* Copyright © 2005 Gas Powered Games, Inc. All rights reserved.
--*****************************************************************************

local GameVersion = import('/lua/version.lua').GetVersion
local UIUtil = import('/lua/ui/uiutil.lua')
local MenuCommon = import('/lua/ui/menus/menucommon.lua')
local Prefs = import('/lua/user/prefs.lua')
local MapUtil = import('/lua/ui/maputil.lua')
local Group = import('/lua/maui/group.lua').Group
local RadioButton = import('/lua/ui/controls/radiobutton.lua').RadioButton
local MapPreview = import('/lua/ui/controls/mappreview.lua').MapPreview
local ResourceMapPreview = import('/lua/ui/controls/resmappreview.lua').ResourceMapPreview
local Popup = import('/lua/ui/controls/popups/popup.lua').Popup
local InputDialog = import('/lua/ui/controls/popups/inputdialog.lua').InputDialog
local Slider = import('/lua/maui/slider.lua').Slider
local PlayerData = import('/lua/ui/lobby/data/playerdata.lua').PlayerData
local GameInfo = import('/lua/ui/lobby/data/gamedata.lua')
local WatchedValueArray = import('/lua/ui/lobby/data/watchedvalue/watchedvaluearray.lua').WatchedValueArray
local ItemList = import('/lua/maui/itemlist.lua').ItemList
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local Button = import('/lua/maui/button.lua').Button
local ToggleButton = import('/lua/ui/controls/togglebutton.lua').ToggleButton
local Edit = import('/lua/maui/edit.lua').Edit
local LobbyComm = import('/lua/ui/lobby/lobbyComm.lua')
local Tooltip = import('/lua/ui/game/tooltip.lua')
local Mods = import('/lua/mods.lua')
local FactionData = import('/lua/factions.lua')
local Text = import('/lua/maui/text.lua').Text
local TextArea = import('/lua/ui/controls/textarea.lua').TextArea
local Trueskill = import('/lua/ui/lobby/trueskill.lua')
local round = import('/lua/ui/lobby/trueskill.lua').round
local Player = import('/lua/ui/lobby/trueskill.lua').Player
local Rating = import('/lua/ui/lobby/trueskill.lua').Rating
local Teams = import('/lua/ui/lobby/trueskill.lua').Teams
local EscapeHandler = import('/lua/ui/dialogs/eschandler.lua')
local CountryTooltips = import('/lua/ui/help/tooltips-country.lua').tooltip
local JSON = import('/lua/system/dkson.lua').json
local Changelog = import('/lua/ui/lobby/changelog.lua')

local IsSyncReplayServer = false

local AddUnicodeCharToEditText = import('/lua/UTF.lua').AddUnicodeCharToEditText

if HasCommandLineArg("/syncreplay") and HasCommandLineArg("/gpgnet") then
    IsSyncReplayServer = true
end

local globalOpts = import('/lua/ui/lobby/lobbyOptions.lua').globalOpts
local teamOpts = import('/lua/ui/lobby/lobbyOptions.lua').teamOptions
local AIOpts = import('/lua/ui/lobby/lobbyOptions.lua').AIOpts
local gameColors = import('/lua/gameColors.lua').GameColors
local numOpenSlots = LobbyComm.maxPlayerSlots

-- Maps faction identifiers to their names.
local FACTION_NAMES = {[1] = "uef", [2] = "aeon", [3] = "cybran", [4] = "seraphim", [5] = "random"}

local formattedOptions = {}
local nonDefaultFormattedOptions = {}
local Warning_MAP = false
local LrgMap = false
local OLtag = false

conTimes = 1

local teamIcons = {
    '/lobby/team_icons/team_no_icon.dds',
    '/lobby/team_icons/team_1_icon.dds',
    '/lobby/team_icons/team_2_icon.dds',
    '/lobby/team_icons/team_3_icon.dds',
    '/lobby/team_icons/team_4_icon.dds',
    '/lobby/team_icons/team_5_icon.dds',
    '/lobby/team_icons/team_6_icon.dds',
}
local hxlmIcons = {
    '/lobby/hxlm_icons/hxlm_no_icon.dds',
    '/lobby/hxlm_icons/hxlm_1_icon.dds',
    '/lobby/hxlm_icons/hxlm_2_icon.dds',
    '/lobby/hxlm_icons/hxlm_3_icon.dds',
    '/lobby/hxlm_icons/hxlm_4_icon.dds',
    '/lobby/hxlm_icons/hxlm_5_icon.dds',
    '/lobby/hxlm_icons/hxlm_6_icon.dds',
    '/lobby/hxlm_icons/hxlm_7_icon.dds',
    '/lobby/hxlm_icons/hxlm_8_icon.dds',
    '/lobby/hxlm_icons/hxlm_9_icon.dds',	
}
DebugEnabled = Prefs.GetFromCurrentProfile('LobbyDebug') or ''
local HideDefaultOptions = Prefs.GetFromCurrentProfile('LobbyHideDefaultOptions') == 'true'
function LOGX(text, ttype)
	-- onlyChat = for debug only in the Chat
	-- onlyLOG = for debug only in the LOG
	-- CLEAR = for disable the debug
	-- Country, RuleTitle, Background
	-- Disconnected, Connecting, UpdateGame
	local text = tostring(text)
	local onlyLOG = string.find(DebugEnabled, 'onlyLOG') or nil
	local onlyChat = string.find(DebugEnabled, 'onlyChat') or nil
	if ttype == nil then
		LOG(text)
	else
		if string.find(DebugEnabled, ttype) and ttype ~= nil then
			if onlyLOG ~= nil then
				LOG(text)
			elseif onlyChat ~= nil then
				AddChatText(text)
			else
				LOG(text)
				AddChatText(text)
			end
		end
	end
end

local connectedTo = {} -- by UID
CurrentConnection = {} -- by Name
ConnectionEstablished = {} -- by Name
ConnectedWithProxy = {} -- by UID

-- The set of available colours for each slot. Each index in this table contains the set of colour
-- values that may appear in its combobox. Keys in the sub-tables are indexes into allColours,
-- values are the colour values.
availableColours = {}

local checkVersion = {}
local checkOL = {}
local allowobers = true
local availableMods = {} -- map from peer ID to set of available mods; each set is a map from "mod id"->true
local selectedMods = nil

local CPU_Benchmarks = {} -- Stores CPU benchmark data


local function parseCommandlineArguments()
    local function GetCommandLineArgOrDefault(argname, default)
        local arg = GetCommandLineArg(argname, 1)
        if arg then
            return arg[1]
        end

        return default
    end

    return {
        PrefLanguage = tostring(string.lower(GetCommandLineArgOrDefault("/country", "V1T2"))),
        initName = GetCommandLineArgOrDefault("/init", ""),
        ratingColor = GetCommandLineArgOrDefault("/ratingcolor", "ffffffff"),
        numGames = tonumber(GetCommandLineArgOrDefault("/numgames", 0)),
        playerMean = tonumber(GetCommandLineArgOrDefault("/mean", 1500)),
        playerClan = tostring(GetCommandLineArgOrDefault("/clan", "")),
        playerDeviation = tonumber(GetCommandLineArgOrDefault("/deviation", 500)),
		onlinecheck = tonumber(GetCommandLineArgOrDefault("/online", 0)),
		Score = tonumber(GetCommandLineArgOrDefault("/score", 0)),
    }
end
local argv = parseCommandlineArguments()

local playerRating = math.floor( Trueskill.round2((argv.playerMean - 3 * argv.playerDeviation) / 100.0) * 100 )

local teamTooltips = {
    'lob_team_none',
    'lob_team_one',
    'lob_team_two',
    'lob_team_three',
    'lob_team_four',
    'lob_team_five',
    'lob_team_six',
}

local teamNumbers = {
    "<LOC _No>",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
}
local hxlmTooltips = {
    'lob_aix_none',
    'lob_aix_1',
    'lob_aix_2',
    'lob_aix_3',
    'lob_aix_4',
    'lob_aix_5',
    'lob_aix_6',
    'lob_aix_7',
    'lob_aix_8',
    'lob_aix_9',
}
local hxlmtable = {
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,}

local function ParseWhisper(params)
    local delimStart = string.find(params, " ")
    if delimStart then
        local name = string.sub(params, 1, delimStart-1)
        local targID = FindIDForName(name)
        if targID then
            PrivateChat(targID, string.sub(params, delimStart+1))
        else
            AddChatText(LOC("<LOC lobby_0007>Invalid whisper target."))
        end
    end
end

local function LOGXWhisper(params)
	-- Exemple : Country Background useChat'
	if string.find(params, 'CLEAR') then
		DebugEnabled = ''
		Prefs.SetToCurrentProfile('LobbyDebug', '')
		AddChatText('Debug disabled')
	else
        DebugEnabled = params
		Prefs.SetToCurrentProfile('LobbyDebug', params)
		AddChatText('Debug activated : '..params)
	end
end

local commands = {
    pm = ParseWhisper,
    private = ParseWhisper,
    w = ParseWhisper,
    whisper = ParseWhisper,
    debug = LOGXWhisper
}

local Strings = LobbyComm.Strings

local lobbyComm = false
local localPlayerName = ""
local gameName = ""
local hostID = false
local singlePlayer = false
local GUI = false
local localPlayerID = false
local gameInfo = false
local pmDialog = false

local defaultMode =(HasCommandLineArg("/windowed") and "windowed") or Prefs.GetFromCurrentProfile('options').primary_adapter
local windowedMode = defaultMode == "windowed" or (HasCommandLineArg("/windowed"))

function SetWindowedLobby(windowed)
    -- Dont change resolution if user already using windowed mode
    if windowed == windowedMode or defaultMode == 'windowed' then
        return
    end

    if windowed then
        ConExecute('SC_PrimaryAdapter windowed')
    else
        ConExecute('SC_PrimaryAdapter ' .. tostring(defaultMode))
    end

    windowedMode = windowed
end

-- String from which to build the various "Move player to slot" labels.
-- TODO: This probably needs localising.
local slotMenuStrings = {
    open = "<LOC lobui_0219>Open",
    close = "<LOC lobui_0220>Close",
    closed = "<LOC lobui_0221>Closed",
    occupy = "<LOC lobui_0222>Occupy",
    pm = "<LOC lobui_0223>Private Message",
    remove_to_kik = "踢出本联机局",
    remove_to_observer = "移动到ob位置",
}
local slotMenuData = {
    open = {
        host = {
            'close',
            'occupy',
            'ailist',
        },
        client = {
            'occupy',
        },
    },
    closed = {
        host = {
            'open',
        },
        client = {
        },
    },
    player = {
        host = {
            'pm',
            'remove_to_observer',
            'remove_to_kik',
            'move'
        },
        client = {
            'pm',
        },
    },
    ai = {
        host = {
            'remove_to_kik',
            'ailist',
        },
        client = {
        },
    },
}



local function GetSlotMenuTables(stateKey, hostKey, slotNum)
    local keys = {}
    local strings = {}
    local tooltips = {}
	
    if not slotMenuData[stateKey] then
        WARN("Invalid slot menu state selected: " .. stateKey)
        return nil
    end

    if not slotMenuData[stateKey][hostKey] then
        WARN("Invalid slot menu host key selected: " .. hostKey)
        return nil
    end

    local isPlayerReady = false
    local localPlayerSlot = FindSlotForID(localPlayerID)
    if localPlayerSlot then
        if gameInfo.PlayerOptions[localPlayerSlot].Ready then
            isPlayerReady = true
        end
    end

    for index, key in slotMenuData[stateKey][hostKey] do
        if key == 'ailist' then
            local aitypes = import('/lua/ui/lobby/aitypes.lua').aitypes
            for aiindex, aidata in aitypes do
                table.insert(keys, aidata.key)
                table.insert(strings, aidata.name)
				table.insert(tooltips, 'aitype_'..aidata.key)
            end
        elseif key == 'move' then
            -- Generate the "move player to slot X" entries.
            for i = 1, numOpenSlots, 1 do
			    if i ~= slotNum then
					table.insert(keys, 'move_player_to_slot' .. i)
					table.insert(strings, LOCF("<LOC lobui_0596>Move Player to slot %s", i))
					table.insert(tooltips, nil)
				end
            end
        else
            if not (isPlayerReady and key == 'occupy') then
                table.insert(keys, key)
                table.insert(strings, slotMenuStrings[key])
				-- Add a tooltip key here if we ever get any interesting options.
                table.insert(tooltips, nil)
            end
        end
    end

    return keys, strings, tooltips
end

-- Instruct a player to unset their "ready" status. Should be called only by the host.
local function setPlayerNotReady(slot)
    local slotOptions = gameInfo.PlayerOptions[slot]
    if slotOptions.Ready then
        if not IsLocallyOwned(slot) then
            lobbyComm:SendData(slotOptions.OwnerID, {Type = 'SetPlayerNotReady', Slot = slot})
        end
        slotOptions.Ready = false
    end
end

-- Called by the host when a "move player to slot X" option is clicked.
local function HandleSlotSwitches(moveFrom, moveTo)
    -- Bail out early for the stupid cases.
    if moveFrom == moveTo then
        AddChatText('You cannot move the Player in slot '..moveFrom..' to the same slot!')
        return
    end

    local fromOpts = gameInfo.PlayerOptions[moveFrom]
    local toOpts = gameInfo.PlayerOptions[moveTo]

    if not fromOpts.Human then
        AddChatText('You cannot move the Player in slot '..moveFrom..' because they are not human.')
        return
    end

    -- If we're moving a human onto an AI, evict the AI and move the player into the space.
    if not toOpts.Human then
        HostRemoveAI(moveTo)
        HostTryMovePlayer(fromOpts.OwnerID, moveFrom, moveTo)
        return
    end

    -- So we're switching two humans. (or moving a human to a blank).
    -- Clear the ready flag for both targets.
    setPlayerNotReady(moveTo)
    setPlayerNotReady(moveFrom)

    HostConvertPlayerToObserver(toOpts.OwnerID, moveTo, false) -- Move Slot moveTo to Observer
    HostTryMovePlayer(fromOpts.OwnerID, moveFrom, moveTo) -- Move Player moveFrom to Slot moveTo
    HostConvertObserverToPlayer(toOpts.OwnerID, FindObserverSlotForID(toOpts.OwnerID), moveFrom)
    SendSystemMessage(fromOpts.PlayerName..' has switched with '..toOpts.PlayerName, 'switch')
end

--- Get the value of the LastFaction, sanitised in case it's an unsafe value.
--
-- This means when some retarded mod (*cough*Nomads*cough*) writes a large number to LastFaction, we
-- don't catch fire.
function GetSanitisedLastFaction()
    local lastFaction = Prefs.GetFromCurrentProfile('LastFaction') or 1
    if lastFaction > table.getn(FactionData.Factions) + 1 or lastFaction < 1 then
        lastFaction = 1
    end

    return lastFaction
end

--- Get a PlayerData object for the local player, configured using data from their profile.
function GetLocalPlayerData()
	local PN = localPlayerName
	--[[if argv.onlinecheck == 1 then
		PN = argv.Name
	end]]--
    return PlayerData(
        {
			PlayerName = PN,
            OwnerID = localPlayerID,
            Human = true,
            PlayerColor = Prefs.GetFromCurrentProfile('LastColor'),
            Faction = GetSanitisedLastFaction(),
            PlayerClan = argv.playerClan,
            PL = playerRating,
            RC = argv.ratingColor,
            NG = argv.numGames,
            MEAN = argv.playerMean,
            DEV = argv.playerDeviation,
            Country = argv.PrefLanguage,
			BuildMult = 1,
			CheatMult = 1,
			HealthMult = 1,
			hx = 1,
            hxIndex = 1,
			PScore = argv.Score,
			Online = argv.onlinecheck,
        }
    )
end

function GetAIPlayerData(name, AIPersonality)
    return PlayerData(
        {
            OwnerID = hostID,
            PlayerName = name,
            Ready = true,
            Human = false,
            AIPersonality = AIPersonality,
        }
    )
end

local function DoSlotBehavior(slot, key, name)
    if key == 'open' then
        HostSetSlotClosed(slot, false)
    elseif key == 'close' then
        HostSetSlotClosed(slot, true)
    elseif key == 'occupy' then
        if IsPlayer(localPlayerID) then
            if lobbyComm:IsHost() then
                HostTryMovePlayer(hostID, FindSlotForID(localPlayerID), slot)
            else
                lobbyComm:SendData(hostID, {Type = 'MovePlayer', CurrentSlot = FindSlotForID(localPlayerID),
                                   RequestedSlot = slot})
            end
        elseif IsObserver(localPlayerID) then
            if lobbyComm:IsHost() then
                local requestedFaction = GetSanitisedLastFaction()
                HostConvertObserverToPlayer(hostID, FindObserverSlotForID(localPlayerID), slot)
            else
                lobbyComm:SendData(
                    hostID,
                    {
                        Type = 'RequestConvertToPlayer',
                        ObserverSlot = FindObserverSlotForID(localPlayerID),
                        PlayerSlot = slot
                    }
                )
            end
        end
    elseif key == 'pm' then
        if gameInfo.PlayerOptions[slot].Human then
            GUI.chatEdit:SetText(string.format("/whisper %s ", gameInfo.PlayerOptions[slot].PlayerName))
        end
    -- Handle the various "Move to slot X" options.
    elseif string.sub(key, 1, 19) == 'move_player_to_slot' then
        HandleSlotSwitches(slot, tonumber(string.sub(key, 20)))
    elseif key == 'remove_to_observer' then
        local playerInfo = gameInfo.PlayerOptions[slot]
        if playerInfo.Human then
            HostConvertPlayerToObserver(playerInfo.OwnerID, slot)
        end
        --\\ Stop Move Player slot to Observer
    elseif key == 'remove_to_kik' then
        if gameInfo.PlayerOptions[slot].Human then
            UIUtil.QuickDialog(GUI, "<LOC lobui_0166>Are you sure?",
                               "<LOC lobui_0167>Kick Player",
                               function() lobbyComm:EjectPeer(gameInfo.PlayerOptions[slot].OwnerID, "KickedByHost") end,
                               "<LOC _Cancel>", nil,
                               nil, nil,
                               true,
                               {worldCover = false, enterButton = 1, escapeButton = 2})
        else
            if lobbyComm:IsHost() then
                HostRemoveAI(slot)
				ClearSlotInfo(slot)
                gameInfo.PlayerOptions[slot] = nil
                --UpdateGame()
            else
                lobbyComm:SendData( hostID, { Type = 'ClearSlot', Slot = slot } )
            end
        end
    else
        -- We're adding an AI of some sort.
        if lobbyComm:IsHost() then
            HostTryAddPlayer(hostID, slot, GetAIPlayerData(name, key))
        end
    end
end --\\ End DoSlotBehavior()

local function GetLocallyAvailableMods()
    local result = {}
    for k,mod in Mods.AllMods() do
        if not mod.ui_only then
            result[mod.uid] = true
        end
    end
    return result
end

local function IsModAvailable(modId)
    for k,v in availableMods do
        if not v[modId] then
            return false
        end
    end
    return true
end


function Reset()
    lobbyComm = false
    localPlayerName = ""
    gameName = ""
    hostID = false
    singlePlayer = false
    GUI = false
    localPlayerID = false
    availableMods = {}
    selectedMods = nil
    numOpenSlots = LobbyComm.maxPlayerSlots
    gameInfo = GameInfo.CreateGameInfo(LobbyComm.maxPlayerSlots)
end

--- Create a new, unconnected lobby.
function ReallyCreateLobby(protocol, localPort, desiredPlayerName, localPlayerUID, natTraversalProvider, over, exitBehavior, playerHasSupcom)
    Reset()

    -- Among other things, this clears uimain's override escape handler, allowing our escape
    -- handler manager to work.
    MenuCommon.MenuCleanup()

    if GUI then
        WARN('CreateLobby called twice for UI construction (Should be unreachable)')
        GUI:Destroy()
        return
    end

    GUI = UIUtil.CreateScreenGroup(over, "CreateLobby ScreenGroup")

    GUI.exitBehavior = exitBehavior

    GUI.optionControls = {}
    GUI.slots = {}

    -- Set up the base escape handler first: want this one at the bottom of the stack.
    GUI.exitLobbyEscapeHandler = function()
        GUI.chatEdit:AbandonFocus()
        UIUtil.QuickDialog(GUI,
            "<LOC lobby_0000>Exit game lobby?",
            "<LOC _Yes>", function()
				if argv.onlinecheck == 1 then
					ReturnToMenu(false)
					ExitApplication()
				else
					ReturnToMenu(false)
				end
                EscapeHandler.PopEscapeHandler()
            end,
            "<LOC _Cancel>", function()
                GUI.chatEdit:AcquireFocus()
            end,
            nil, nil,
            true
        )
    end
    EscapeHandler.PushEscapeHandler(GUI.exitLobbyEscapeHandler)
	if argv.onlinecheck == 1 then
		GUI.connectdialog =  UIUtil.QuickDialog(GUI,
            "连接中...    尝试次数："..repr(conTimes),
            Strings.AbortConnect, function()
				ReturnToMenu(false)
				ExitApplication()
            end,
            "重新连接", function()
				--GUI:Destroy()
				--UIUtil.QuickDialog(GUI, "正常准备重新连接...	尝试次数："..repr(conTimes))
				ReturnToMenu(true)
            end,
            nil, nil,
            true
        )
		conTimes = conTimes + 1
	else 
		GUI.connectdialog = UIUtil.QuickDialog(GUI, Strings.TryingToConnect, Strings.AbortConnect, ReturnToMenu)
	end
    -- Prevent the dialog from being closed due to user action.
    GUI.connectdialog.OnEscapePressed = function() end
    GUI.connectdialog.OnShadowClicked = function() end

    InitLobbyComm(protocol, localPort, desiredPlayerName, localPlayerUID, natTraversalProvider)

    -- Store off the validated playername
    localPlayerName = lobbyComm:GetLocalPlayerName()
    local Prefs = import('/lua/user/prefs.lua')
    local windowed = Prefs.GetFromCurrentProfile('WindowedLobby') or 'false'
    SetWindowedLobby(windowed == 'true')
end

-- A map from message types to functions that process particular message types.
local MESSAGE_HANDLERS = {
    -- TODO: Finalise signature and semantics.
    ConnectivityState = function()
    end
}

--- Handle an incoming message from the FAF client via the GPGNet protocol.
--
-- @param jsonBlob A JSON string containing the message to process.
-- Messages are JSON strings containing two fields:
-- command_id: A string identifying the type of message. This string is used as a key into
--             MESSAGE_HANDLERS to find the function to use to process this message.
-- arguments: An array of arguments that should be passed to the handler function.
function HandleGPGNetMessage(jsonBlob)
    local jsonObj = JSON.decode(jsonBlob)
    table.print(jsonObj)
    local handler = MESSAGE_HANDLERS[jsonObj.command_id]
    if not handler then
        WARN("Incomprehensible JSON message: \n" .. jsonBlob)
        return
    end

    handler(unpack(jsonObj.arguments))
end

--- Start a synchronous replay session
--
-- @param replayID The ID of the replay to download and play.
function StartSyncReplaySession(replayID)
    SetFrontEndData('syncreplayid', replayID)
    local dl = UIUtil.QuickDialog(GetFrame(0), "Downloading the replay file...")
    LaunchReplaySession('gpgnet://' .. GetCommandLineArg('/gpgnet',1)[1] .. '/' .. import('/lua/user/prefs.lua').GetFromCurrentProfile('Name'))
    dl:Destroy()
    UIUtil.QuickDialog(GetFrame(0), "You dont have this map.", "Exit", function() ExitApplication() end)
end

--- Create a new unconnected lobby/Entry point for processing messages sent from the FAF lobby.
--
-- This function is called exactly once by the game when a new lobby should be created.
-- @see ReallyCreateLobby
--
-- This function is called whenever the FAF lobby sends a message into the game, with the message
-- in the desiredPlayerName parameter as a JSON string with a length no greater than 4061 bytes.
-- This madness is justified by this being one of the smallish number of functions we can have
-- called from outside.
-- @see HandleGPGNetMessage
--
-- This function is also called by the sync replay server when a session should be started. (this
-- should probably be refactored to use the JSON messenger protocol)
-- @see StartSyncReplaySession
function CreateLobby(protocol, localPort, desiredPlayerName, localPlayerUID, natTraversalProvider, over, exitBehavior, playerHasSupcom)
    -- Is this an incoming GPGNet message?
    if localPort == -1 then
        HandleGPGNetMessage(desiredPlayerName)
        return
    end

    -- Special-casing for sync-replay.
    -- TODO: Consider replacing this with a gpgnet message type.
    if IsSyncReplayServer then
        StartSyncReplaySession(localPlayerUID)
        return
    end

    -- Okay, so we actually are creating a lobby, instead of doing some ridiculous hack.
    ReallyCreateLobby(protocol, localPort, desiredPlayerName, localPlayerUID, natTraversalProvider, over, exitBehavior, playerHasSupcom)
end

-- create the lobby as a host
function HostGame(desiredGameName, scenarioFileName, inSinglePlayer)
    singlePlayer = inSinglePlayer
    gameName = lobbyComm:MakeValidGameName(desiredGameName)
    lobbyComm.desiredScenario = string.gsub(scenarioFileName, ".v%d%d%d%d_scenario.lua", "_scenario.lua")
    lobbyComm:HostGame()
end

-- join an already existing lobby
function JoinGame(address, asObserver, playerName, uid)
    lobbyComm:JoinGame(address, playerName, uid)
end

function ConnectToPeer(addressAndPort,name,uid)
    if not string.find(addressAndPort, '127.0.0.1') then
        #LOG("ConnectToPeer (name=" .. name .. ", uid=" .. uid .. ", address=" .. addressAndPort ..")")
		LOGX('>> ConnectToPeer > name='..tostring(name), 'Connecting')
    else
        DisconnectFromPeer(uid)
        #LOG("ConnectToPeer (name=" .. name .. ", uid=" .. uid .. ", address=" .. addressAndPort ..", USE PROXY)")
		LOGX('>> ConnectToPeer > name='..tostring(name)..' (with PROXY)', 'Connecting')
        table.insert(ConnectedWithProxy, uid)
    end
    lobbyComm:ConnectToPeer(addressAndPort,name,uid)
end

function DisconnectFromPeer(uid)
    #LOG("DisconnectFromPeer (uid=" .. uid ..")")
    if wasConnected(uid) then
        table.remove(connectedTo, uid)
    end
	LOGX('>> DisconnectFromPeer > name='..tostring(FindNameForID(uid)), 'Disconnected')
    GpgNetSend('Disconnected', string.format("%d", uid))
    lobbyComm:DisconnectFromPeer(uid)
end

function SetHasSupcom(cmd)
    -- TODO: Refactor SyncReplayServer gubbins to use generalised JSON protocol.
    if IsSyncReplayServer then
        if cmd == 0 then
            SessionResume()
        elseif cmd == 1 then
            SessionRequestPause()
        end
    end
end

function SetHasForgedAlliance(speed)
    if IsSyncReplayServer then
        if GetGameSpeed() ~= speed then
            SetGameSpeed(speed)
        end
    end
end

-- TODO: These functions are dumb. We have these things called "hashmaps".
function FindSlotForID(id)
    for k, player in gameInfo.PlayerOptions:pairs() do
        if player.OwnerID == id and player.Human then
            return k
        end
    end
    return nil
end

function FindNameForID(id)
    for k, player in gameInfo.PlayerOptions:pairs() do
        if player.OwnerID == id and player.Human then
            return player.PlayerName
        end
    end
    return nil
end

function FindIDForName(name)
    for k, player in gameInfo.PlayerOptions:pairs() do
        if player.PlayerName == name and player.Human then
            return player.OwnerID
        end
    end
    return nil
end

function FindObserverSlotForID(id)
    for k, observer in gameInfo.Observers:pairs() do
        if observer.OwnerID == id then
            return k
        end
    end
    return nil
end

function IsLocallyOwned(slot)
    return (gameInfo.PlayerOptions[slot].OwnerID == localPlayerID)
end

function IsPlayer(id)
    return FindSlotForID(id) ~= nil
end

function IsObserver(id)
    return FindObserverSlotForID(id) ~= nil
end

function UpdateSlotBackground(slotIndex)
    if gameInfo.ClosedSlots[slotIndex] then
        GUI.slots[slotIndex].SlotBackground:SetTexture(UIUtil.UIFile('/SLOT/slot-dis.dds'))
    else
        if gameInfo.PlayerOptions[slotIndex] then
            GUI.slots[slotIndex].SlotBackground:SetTexture(UIUtil.UIFile('/SLOT/slot-player.dds'))
        else
            GUI.slots[slotIndex].SlotBackground:SetTexture(UIUtil.UIFile('/SLOT/slot-player_other.dds'))
        end
    end
end

--- Send player settings to the server
function HostSendPlayerSettingsToServer(slotNum)
    local playerInfo = gameInfo.PlayerOptions[slotNum]
    local playerName = playerInfo.PlayerName
    GpgNetSend('PlayerOption', string.format("faction %s %d %s", playerName, slotNum, playerInfo.Faction))
    GpgNetSend('PlayerOption', string.format("color %s %d %s", playerName, slotNum, playerInfo.PlayerColor))
    GpgNetSend('PlayerOption', string.format("team %s %d %s", playerName, slotNum, playerInfo.Team))
    GpgNetSend('PlayerOption', string.format("startspot %s %d %s", playerName, slotNum, slotNum))
end

-- update the data in a player slot
-- TODO: With lazyvars, this function should be eliminated. Lazy-value-callbacks should be used
-- instead to incrementaly update things.
function SetSlotInfo(slotNum, playerInfo)
    -- Remove the ConnectDialog. It probably makes more sense to do this when we get the game state.
	if GUI.connectdialog then
		GUI.connectdialog:Close()
        GUI.connectdialog = nil

        -- Changelog, if necessary.
        if Changelog.NeedChangelog() then
            Changelog.CreateUI(GUI)
        end
    end

    local slot = GUI.slots[slotNum]
    local isHost = lobbyComm:IsHost()
    local isLocallyOwned = IsLocallyOwned(slotNum)

    -- Set enabledness of controls according to host privelage etc.
    -- Yeah, we set it twice. No, it's not brilliant. Blurgh.
    local facColEnabled = isLocallyOwned or (isHost and not playerInfo.Human)
    UIUtil.setEnabled(slot.faction, facColEnabled)
    UIUtil.setEnabled(slot.color, facColEnabled)
	UIUtil.setEnabled(slot.ecocheatText, facColEnabled)
	UIUtil.setEnabled(slot.buildcheatText, facColEnabled)
	UIUtil.setEnabled(slot.healthcheatText, facColEnabled)
	UIUtil.setEnabled(slot.hxlmText, facColEnabled)

    -- Possibly override it due to the ready box.
    if isLocallyOwned then
        if playerInfo.Ready and playerInfo.Human then
            DisableSlot(slotNum, true)
        else
            EnableSlot(slotNum)
        end
    else
        DisableSlot(slotNum)
    end

    --- Returns true if the team selector for this slot should be enabled.
    --
    -- The predicate was getting unpleasantly long to read.
    function teamSelectionEnabled(autoTeams, ready, locallyOwned, isHost)
        if isHost and not playerInfo.Human then
            return true
        end

        -- If autoteams has control, no selector for you.
        if autoTeams ~= 'none' then
            return false
        end

        -- You can control your own one when you're not ready.
        if locallyOwned then
            return not ready
        end

        -- The host can control that of others. TODO: Prevent him from doing this while ready
        -- himself. We need some sort of sane state-of-self tracking for this...
        return isHost
    end
	    --- Returns true if the team selector for this slot should be enabled.
    --
    -- 你调整一下，主机可以设置所有人，其他人只能看，不能改就行了。
    function AixSelectionEnabled(autoTeams, ready, locallyOwned, isHost)
        if isHost then
            return true
			else
			return false
        end
        return isHost
    end
    -- Disable team selection if "auto teams" is controlling it. Moderatelty ick.
    local autoTeams = gameInfo.GameOptions.AutoTeams
    UIUtil.setEnabled(slot.team, teamSelectionEnabled(autoTeams, playerInfo.Ready, isLocallyOwned, isHost))
    UIUtil.setEnabled(slot.ecocheatText, AixSelectionEnabled(autoTeams, playerInfo.Ready, isLocallyOwned, isHost))
	UIUtil.setEnabled(slot.buildcheatText, AixSelectionEnabled(autoTeams, playerInfo.Ready, isLocallyOwned, isHost))
	UIUtil.setEnabled(slot.healthcheatText, AixSelectionEnabled(autoTeams, playerInfo.Ready, isLocallyOwned, isHost))
	UIUtil.setEnabled(slot.hxlmText, AixSelectionEnabled(autoTeams, playerInfo.Ready, isLocallyOwned, isHost))

    local hostKey
    if isHost then
        hostKey = 'host'
    else
        hostKey = 'client'
    end

    -- These states are used to select the appropriate strings with GetSlotMenuTables.
    local slotState
    if not playerInfo.Human then
        slot.ecocheatText:Hide()
		slot.buildcheatText:Hide()
		slot.healthcheatText:Hide()
		slot.hxlmText:Hide()
        slotState = 'ai'
    elseif not isLocallyOwned then
        slotState = 'player'
    else
        slotState = nil
    end

    slot.name:ClearItems()

    if slotState then
        slot.name:Enable()
        local slotKeys, slotStrings, slotTooltips = GetSlotMenuTables(slotState, hostKey, slotNum)
        slot.name.slotKeys = slotKeys

        if table.getn(slotKeys) > 0 then
            slot.name:AddItems(slotStrings)
            slot.name:Enable()
            Tooltip.AddComboTooltip(slot.name, slotTooltips)
        else
            slot.name.slotKeys = nil
            slot.name:Disable()
            Tooltip.RemoveComboTooltip(slot.name)
        end
    else
        -- no slotState indicate this must be ourself, and you can't do anything to yourself
        slot.name.slotKeys = nil
        slot.name:Disable()
    end
	
	
    slot.name:Show()
    -- Color the Name in Slot by State
    if slotState == 'ai' then
        slot.name:SetTitleTextColor("dbdbb9") -- Beige Color for AI
        slot.name._text:SetFont('Arial Gras', 12)
		
		--FACN check AI
		LOG("*ADDED AI IN SLOT:"..repr(slotNum))
			
    elseif FindSlotForID(hostID) == slotNum then
        slot.name:SetTitleTextColor("ffc726") -- Orange Color for Host
        slot.name._text:SetFont('Arial Gras', 15)
    elseif slotState == 'player' then
        slot.name:SetTitleTextColor("64d264") -- Green Color for Players
        slot.name._text:SetFont('Arial Gras', 15)
    elseif isLocallyOwned then
        slot.name:SetTitleTextColor("6363d2") -- Blue Color for You
        slot.name._text:SetFont('Arial Gras', 15)
    else
        slot.name:SetTitleTextColor(UIUtil.fontColor) -- Normal Color for Other
        slot.name._text:SetFont('Arial Gras', 12)
    end


    local playerName = playerInfo.PlayerName
    local displayName = ""
    if playerInfo.PlayerClan ~= "" then
        displayName = string.format("[%s] %s", playerInfo.PlayerClan, playerInfo.PlayerName)
    else
        displayName = playerInfo.PlayerName
    end

    --\\ Stop - Color the Name in Slot by State
    if wasConnected(playerInfo.OwnerID) or isLocallyOwned or not playerInfo.Human then
        slot.name:SetTitleText(displayName)
        slot.name._text:SetFont('Arial Gras', 15)
        if not table.find(ConnectionEstablished, playerName) then
            if playerInfo.Human and not isLocallyOwned then
                if table.find(ConnectedWithProxy, playerInfo.OwnerID) then
                    AddChatText(LOCF("<LOC Engine0004>Connection to %s established.", playerName)..' (FAF Proxy)', "Engine0004")
                else
                    AddChatText(LOCF("<LOC Engine0004>Connection to %s established.", playerName), "Engine0004")
                end

                table.insert(ConnectionEstablished, playerName)
                for k, v in CurrentConnection do -- Remove PlayerName in this Table
                    if v == playerName then
                        CurrentConnection[k] = nil
                        break
                    end
                end
            end
        end
    else
        -- TODO: Localise!
        slot.name:SetTitleText('Connecting to ... ' .. playerName)
        slot.name._text:SetFont('Arial Gras', 11)
    end

    slot.faction:Show()
    slot.faction:SetItem(playerInfo.Faction)

    slot.color:Show()
    Check_Availaible_Color(slotNum)

    slot.team:Show()
    slot.team:SetItem(playerInfo.Team)
	
	if slotState ~= 'ai' then --不是ai才弹出选项
		slot.ecocheatText:Show()
		slot.ecocheatText:SetText(playerInfo.CheatMult)
	
		slot.buildcheatText:Show()
		slot.buildcheatText:SetText(playerInfo.BuildMult)
		
		slot.healthcheatText:Show()
		slot.healthcheatText:SetText(playerInfo.HealthMult)
	
		if playerInfo.Online == 1 then
			slot.scoreText:Show()
			slot.scoreText:SetText(playerInfo.PScore)
			slot.gamenumText:Show()
			slot.gamenumText:SetText(playerInfo.NG)
		else
			slot.hxlmText:Show()
			slot.hxlmText:SetItem(playerInfo.hxIndex)
		end
	end
	
    if isHost then
        HostSendPlayerSettingsToServer(slotNum)
    end

    UIUtil.setVisible(slot.ready, playerInfo.Human and not singlePlayer)
    slot.ready:SetCheck(playerInfo.Ready, true)

    if isLocallyOwned and playerInfo.Human then
        Prefs.SetToCurrentProfile('LastColor', playerInfo.PlayerColor)
        Prefs.SetToCurrentProfile('LastFaction', playerInfo.Faction)
    end

    -- Show the player's nationality
    if not playerInfo.Country then
        slot.KinderCountry:Hide()
    else
        slot.KinderCountry:Show()
        slot.KinderCountry:SetTexture(UIUtil.UIFile('/countries/'..playerInfo.Country..'.dds'))

        Tooltip.AddControlTooltip(slot.KinderCountry, {text=LOC("<LOC lobui_0413>Country"), body=CountryTooltips[playerInfo.Country]})
    end

    UpdateSlotBackground(slotNum)

    -- Set the CPU bar
    SetSlotCPUBar(slotNum, playerInfo)

    ShowGameQuality()
    RefreshMapPositionForAllControls(slotNum)
end

function ClearSlotInfo(slotIndex)
    local slot = GUI.slots[slotIndex]

    local hostKey
    if lobbyComm:IsHost() then
        hostKey = 'host'
    else
        hostKey = 'client'
    end

    local stateKey
    local stateText
    if gameInfo.ClosedSlots[slotIndex] then
        stateKey = 'closed'
        stateText = slotMenuStrings.closed
    else
        stateKey = 'open'
        stateText = slotMenuStrings.open
    end

    local slotKeys, slotStrings, slotTooltips = GetSlotMenuTables(stateKey, hostKey)

    -- set the text appropriately
    slot.name:ClearItems()
    slot.name:SetTitleText(LOC(stateText))
    if table.getn(slotKeys) > 0 then
        slot.name.slotKeys = slotKeys
        slot.name:AddItems(slotStrings)
        Tooltip.AddComboTooltip(slot.name, slotTooltips)
        slot.name:Enable()
    else
        slot.name.slotKeys = nil
        slot.name:Disable()
        Tooltip.RemoveComboTooltip(slot.name)
    end

    slot.name._text:SetFont('Arial Gras', 12)
    if stateKey == 'closed' then
        slot.name:SetTitleTextColor("Crimson")
    else
        slot.name:SetTitleTextColor('B9BFB9')
    end

    slot:HideControls()

    UpdateSlotBackground(slotIndex)
    ShowGameQuality()
    RefreshMapPositionForAllControls(slotIndex)
end

function IsColorFree(colorIndex)
    for id, player in gameInfo.PlayerOptions:pairs() do
        if player.PlayerColor == colorIndex then
            return false
        end
    end

    return true
end

function GetPlayerCount()
    local numPlayers = 0
    for k,player in gameInfo.PlayerOptions:pairs() do
        if player then
            numPlayers = numPlayers + 1
        end
    end
    return numPlayers
end

local function GetPlayersNotReady()
    local notReady = false
    for k,v in gameInfo.PlayerOptions:pairs() do
        if v.Human and not v.Ready then
            if not notReady then
                notReady = {}
            end
            table.insert(notReady, v.PlayerName)
        end
    end
    return notReady
end

local function GetRandomFactionIndex()
    local randomfaction = nil
    local counter = 50
    while counter > 0 do
        counter = (counter - 1)
        randomfaction = math.random(1, table.getn(FactionData.Factions))
    end
    return randomfaction
end


local function AssignRandomFactions()
    local randomFactionID = table.getn(FactionData.Factions) + 1
    for index, player in gameInfo.PlayerOptions do
        -- note that this doesn't need to be aware if player has supcom or not since they would only be able to select
        -- the random faction ID if they have supcom
        if player.Faction >= randomFactionID then
            player.Faction = GetRandomFactionIndex()
        end
    end
end

---------------------------
-- autobalance functions --
---------------------------
local function team_sort_by_sum(t1, t2)
    return t1['sum'] < t2['sum']
end

local function autobalance_bestworst(players, teams_arg)
    local players = table.deepcopy(players)
    local result = {}
    local best = true
    local teams = {}

    for t, slots in teams_arg do
        table.insert(teams, {team=t, slots=table.deepcopy(slots), sum=0})
    end

    -- teams first picks best player and then worst player, repeat
    while table.getn(players) > 0 do
        for i, t in teams do
            local team = t['team']
            local slots = t['slots']
            local slot = table.remove(slots, 1)
            local player

            if(best) then
                player = table.remove(players, 1)
            else
                player = table.remove(players)
            end

            if(not player) then break end

            teams[i]['sum'] = teams[i]['sum'] + player['rating']
            table.insert(result, {player=player['pos'], rating=player['rating'], team=team, slot=slot})
        end

        best = not best
        if(best) then
            table.sort(teams, team_sort_by_sum)
        end
    end

    return result
end

local function autobalance_avg(players, teams_arg)
    local players = table.deepcopy(players)
    local result = {}
    local teams = {}
    local max_sum = 0

    for t, slots in teams_arg do
        table.insert(teams, {team=t, slots=table.deepcopy(slots), sum=0})
    end

    while table.getn(players) > 0 do
        local first_team = true
        for i, t in teams do
            local team = t['team']
            local slots = t['slots']
            local slot = table.remove(slots, 1)
            local player
            local player_key

            for j, p in players do
                player_key = j
                if(first_team or t['sum'] + p['rating'] <= max_sum) then
                    break
                end
            end

            player = table.remove(players, player_key)
            if(not player) then break end

            teams[i]['sum'] = teams[i]['sum'] + player['rating']
            max_sum = math.max(max_sum, teams[i]['sum'])
            table.insert(result, {player=player['pos'], rating=player['rating'], team=team, slot=slot})
            first_team = false
        end

        table.sort(teams, team_sort_by_sum)
    end

    return result
end

local function autobalance_rr(players, teams)
    local players = table.deepcopy(players)
    local teams = table.deepcopy(teams)
    local result = {}

    local team_picks = {
        {},
        {1,2,  2,1,  2,1,  1,2,  1,2,  2,1},
        {1,2,3,  3,2,1,  2,1,3,  2,3,1},
        {1,2,3,4,  4,3,2,1,  3,1,4,2},
    }

    local picks = team_picks[table.getn(teams)]

    if(not picks or table.getsize(picks) == 0) then
        return
    end

    i = 1
    while (table.getn(players) > 0) do
        local player = table.remove(players, 1)
        local team = table.remove(picks, 1)
        local slot = table.remove(teams[team], 1)
        if(not player) then break end

        table.insert(result, {player=player['pos'], rating=player['rating'], team=team, slot=slot})
    end

    return result
end

local function autobalance_random(players, teams_arg)
    local players = table.deepcopy(players)
    local result = {}
    local teams = {}

    players = table.shuffle(players)

    for t, slots in teams_arg do
        table.insert(teams, {team=t, slots=table.deepcopy(slots)})
    end

    while(table.getn(players) > 0) do

        for _, t in teams do
            local team = t['team']
            local slot = table.remove(t['slots'], 1)
            local player = table.remove(players, 1)

            if(not player) then break end

            table.insert(result, {player=player['pos'], rating=player['rating'], team=team, slot=slot})
        end
    end

    return result
end

function autobalance_quality(players)
    local teams = nil
    local quality = nil

    for _, p in players do
        local i = p['player']
        local team = p['team']
        local playerInfo = gameInfo.PlayerOptions[i]
        local player = Player.create(playerInfo.PlayerName,
--自动分组算法 gly
                                     Rating.create(p['rating'] , 0))

        --LOG(tostring(playerInfo.PlayerName)..' '..tostring(i)..' '..tostring(team)..' '..tostring((p['rating'] or 10) * 100)..' '..tostring(25))

        if not teams then
            teams = Teams.create()
        end

        teams:addPlayer(team, player)
    end

    if teams then
        quality = Trueskill.computeQuality(teams)
    end

    return quality
end

--- Assign the "random" (really autobalanced) start positions.
local function AssignRandomStartSpots()
    local teamSpawn = gameInfo.GameOptions['TeamSpawn']

    if teamSpawn == 'fixed' then
        return
    end

    function teamsAddSpot(teams, team, spot)
        if not teams[team] then
            teams[team] = {}
        end
        table.insert(teams[team], spot)
    end

    -- rearrange players according to the provided setup
    function rearrangePlayers(data)
        gameInfo.GameOptions['Quality'] = data.quality

        -- Copy a reference to each of the PlayerData objects indexed by their original slots.
        local orgPlayerOptions = {}
        for k, p in gameInfo.PlayerOptions do
            orgPlayerOptions[k] = p
        end

        -- Rearrange the players in the slots to match the chosen configuration. The result object
        -- maps old slots to new slots, and we use orgPlayerOptions to avoid losing a reference to
        -- an object (and because swapping is too much like hard work).
        gameInfo.PlayerOptions = {}
        for _, r in data.setup do
            local playerOptions = orgPlayerOptions[r.player]
            playerOptions.Team = r.team + 1
            playerOptions.StartSpot = r.slot
            gameInfo.PlayerOptions[r.slot] = playerOptions --1111111111有错误

            -- Send team data to the server
            local playerInfo = gameInfo.PlayerOptions[r.slot]
            HostSendPlayerSettingsToServer(r.slot)
        end
    end

    local numAvailStartSpots = nil
    local scenarioInfo = nil
    if gameInfo.GameOptions.ScenarioFile and (gameInfo.GameOptions.ScenarioFile ~= "") then
        scenarioInfo = MapUtil.LoadScenario(gameInfo.GameOptions.ScenarioFile)
    end
    if scenarioInfo then
        local armyTable = MapUtil.GetArmies(scenarioInfo)
        if armyTable then
            if gameInfo.GameOptions['RandomMap'] == 'Off' then
                numAvailStartSpots = table.getn(armyTable)
            else
                numAvailStartSpots = numberOfPlayers
            end
        end
    else
        WARN("Can't assign random start spots, no scenario selected.")
        return
    end

    local AutoTeams = gameInfo.GameOptions.AutoTeams
    local positionGroups = {}
    local teams = {}

    -- Used to actualise the virtual teams produced by the "Team -" no-team team.
    local synthesizedTeamCounter = 9
    for i = 1, numAvailStartSpots do
        if not gameInfo.ClosedSlots[i] then
            local team = nil
            local group = nil

            if AutoTeams == 'lvsr' then
                local midLine = GUI.mapView.Left() + (GUI.mapView.Width() / 2)
                local markerPos = GUI.mapView.startPositions[i].Left()

                if markerPos < midLine then
                    team = 2
                else
                    team = 3
                end
            elseif AutoTeams == 'tvsb' then
                local midLine = GUI.mapView.Top() + (GUI.mapView.Height() / 2)
                local markerPos = GUI.mapView.startPositions[i].Top()

                if markerPos < midLine then
                    team = 2
                else
                    team = 3
                end
            elseif AutoTeams == 'pvsi' then
                if math.mod(i, 2) ~= 0 then
                    team = 2
                else
                    team = 3
                end
            elseif AutoTeams == 'manual' then
                team = gameInfo.AutoTeams[i]
            else -- none
                team = gameInfo.PlayerOptions[i].Team
                group = 1
            end

            group = group or team
            if not positionGroups[group] then
                positionGroups[group] = {}
            end
            table.insert(positionGroups[group], i)

            if team ~= nil then
                -- Team 1 secretly represents "No team", so give them a real team (but one that
                -- nobody else can possibly have)
                if team == 1 then
                    team = synthesizedTeamCounter
                    synthesizedTeamCounter = synthesizedTeamCounter + 1
                end
                teamsAddSpot(teams, team, i)
            end
        end
    end
    gameInfo.GameOptions.RandomPositionGroups = positionGroups

    -- shuffle the array for randomness.
    for i, team in teams do
        teams[i] = table.shuffle(team)
    end
    teams = table.shuffle(teams)

    local ratingTable = {}
    for i = 1, numAvailStartSpots do
        local playerInfo = gameInfo.PlayerOptions[i]
        if playerInfo then
			--如果是启动器模式，修改进游戏后的分数
			if argv.onlinecheck == 1 and playerInfo.PScore then
			table.insert(ratingTable, { pos=i, rating = playerInfo.PScore })
			else
            table.insert(ratingTable, { pos=i, rating = playerInfo.hx })
			end
        end
    end

    if teamSpawn == 'random' or teamSpawn == 'random_reveal' or teamSpawn == 'nomal_smurf' then
        s = autobalance_random(ratingTable, teams)
        q = autobalance_quality(s)
        rearrangePlayers{setup=s, quality=q}
        return
    end

    ratingTable = table.shuffle(ratingTable) -- random order for people with same rating
    table.sort(ratingTable, function(a, b) return a['rating'] > b['rating'] end)

    local setups = {}
    local functions = {
        rr=autobalance_rr,
        bestworst=autobalance_bestworst,
        avg=autobalance_avg,
    }

    local cmp = function(a, b) return a.quality > b.quality end
    local s, q
    for fname, f in functions do
        s = f(ratingTable, teams)
        if s then
            q = autobalance_quality(s)
            table.binsert(setups, {setup=s, quality=q}, cmp)
        end
    end

    local n_random = 0
    local frac = (teamSpawn == 'balanced_flex' or teamSpawn == 'balanced_flex_reveal') and 0.95 or 1
    -- add 100 random compositions and keep 3 with at least <frac%> of best quality
    for i=1, 200 do
        s = autobalance_random(ratingTable, teams)
        q = autobalance_quality(s)

        if q > setups[1].quality * frac then
            table.binsert(setups, {setup=s, quality=q}, cmp)
            n_random = n_random + 1
            if n_random > 10 then break end
        end
    end

    if teamSpawn == 'balanced_flex' or teamSpawn == 'balanced_flex_reveal' then
        setups = table.shuffle(setups)
    end

    best = table.remove(setups, 1)
    rearrangePlayers(best)
end

-- This function is used to double check the observers.
-- TODO: IT MUST DIE.
local function sendObserversList()
    for k, observer in gameInfo.Observers:pairs() do
        GpgNetSend('PlayerOption', string.format("team %s %d %s", observer.PlayerName, -1, 0))
    end
end


local function AssignAutoTeams()
    -- A function to take a player index and return the team they should be on.
    local getTeam
    if gameInfo.GameOptions.AutoTeams == 'lvsr' then
        local midLine = GUI.mapView.Left() + (GUI.mapView.Width() / 2)
        local startPositions = GUI.mapView.startPositions

        getTeam = function(playerIndex)
            local markerPos = startPositions[playerIndex].Left()
            if markerPos < midLine then
                return 2
            else
                return 3
            end
        end
    elseif gameInfo.GameOptions.AutoTeams == 'tvsb' then
        local midLine = GUI.mapView.Top() + (GUI.mapView.Height() / 2)
        local startPositions = GUI.mapView.startPositions

        getTeam = function(playerIndex)
            local markerPos = startPositions[playerIndex].Top()
            if markerPos < midLine then
                return 2
            else
                return 3
            end
        end
    elseif gameInfo.GameOptions.AutoTeams == 'pvsi' or gameInfo.GameOptions['RandomMap'] ~= 'Off' then
        getTeam = function(playerIndex)
            if math.mod(playerIndex, 2) ~= 0 then
                return 2
            else
                return 3
            end
        end
    else
        return
    end

    for i = 1, LobbyComm.maxPlayerSlots do
        if not gameInfo.ClosedSlots[i] and gameInfo.PlayerOptions[i] then
            local correctTeam = getTeam(i)
            if gameInfo.PlayerOptions[i].Team ~= correctTeam then
                SetPlayerOption(i, "Team", correctTeam, true)
                SetSlotInfo(i, gameInfo.PlayerOptions[i])
            end
        end
    end
end

local function AssignAINames()
    local aiNames = import('/lua/ui/lobby/aiNames.lua').ainames
    local nameSlotsTaken = {}
    for index, faction in FactionData.Factions do
        nameSlotsTaken[index] = {}
    end
    for index, player in gameInfo.PlayerOptions do
        if not player.Human then
            local playerFaction = player.Faction
            local factionNames = aiNames[FactionData.Factions[playerFaction].Key]
            local ranNum
            repeat
                ranNum = math.random(1, table.getn(factionNames))
            until nameSlotsTaken[playerFaction][ranNum] == nil
            nameSlotsTaken[playerFaction][ranNum] = true
            player.PlayerName = factionNames[ranNum] .. " (" .. player.PlayerName .. ")"
        end
    end
end


-- call this whenever the lobby needs to exit and not go in to the game
function ReturnToMenu(reconnect)
    if lobbyComm then
        lobbyComm:Destroy()
        lobbyComm = false
    end

    local exitfn = GUI.exitBehavior
	
	GUI:Destroy()
	GUI = false

    if not reconnect then
        exitfn()
    else
        exitfn()
    end
end


function SendSystemMessage(text, id)
    local data = {
        Type = "SystemMessage",
        Text = text,
        Id = id or '',
    }
    lobbyComm:BroadcastData(data)
    AddChatText(data.Text)
end

function PublicChat(text)
    lobbyComm:BroadcastData(
        {
            Type = "PublicChat",
            Text = text,
        }
        )
    AddChatText("["..localPlayerName.."] " .. text)
end

function PrivateChat(targetID,text)
    if targetID ~= localPlayerID then
        lobbyComm:SendData(
            targetID,
            {
                Type = 'PrivateChat',
                Text = text,
            }
            )
    end
    AddChatText("<<"..localPlayerName..">> " .. text)
end

function UpdateAvailableSlots( numAvailStartSpots )
    if numAvailStartSpots > LobbyComm.maxPlayerSlots then
        WARN("Lobby requests " .. numAvailStartSpots .. " but there are only " .. LobbyComm.maxPlayerSlots .. " available")
    end

    -- if number of available slots has changed, update it
    if numOpenSlots == numAvailStartSpots then
        return
    end

    numOpenSlots = numAvailStartSpots
    for i = 1, numAvailStartSpots do
        if gameInfo.ClosedSlots[i] then
			-- FXF210417 修复位置显示bug
			--gameInfo.ClosedSlots[i] = nil							 
            GUI.slots[i]:Show()
            if not gameInfo.PlayerOptions[i] then
                ClearSlotInfo(i)
            end
            if not gameInfo.PlayerOptions[i].Ready then
                EnableSlot(i)
            end
        end
    end

    for i = numAvailStartSpots + 1, LobbyComm.maxPlayerSlots do
        if lobbyComm:IsHost() and gameInfo.PlayerOptions[i] then
            local info = gameInfo.PlayerOptions[i]
            if info.Human then
                HostConvertPlayerToObserver(info.OwnerID, i)
            else
                HostRemoveAI(i)
            end
        end
        DisableSlot(i)
        GUI.slots[i]:Hide()
        gameInfo.ClosedSlots[i] = true
    end
end

--FXF210302 上传图标数据
local function UploadIconData(gameInfo)
	--陆军
	gameInfo.GameOptions['icon_ACU'] = Prefs.GetFromCurrentProfile('options').icon_ACU
	gameInfo.GameOptions['icon_T1MAA'] = Prefs.GetFromCurrentProfile('options').icon_T1MAA
	gameInfo.GameOptions['icon_T2MAA'] = Prefs.GetFromCurrentProfile('options').icon_T2MAA
	gameInfo.GameOptions['icon_T3MAA'] = Prefs.GetFromCurrentProfile('options').icon_T3MAA
	gameInfo.GameOptions['icon_T3SNP'] = Prefs.GetFromCurrentProfile('options').icon_T3SNP
	gameInfo.GameOptions['icon_T2MBB'] = Prefs.GetFromCurrentProfile('options').icon_T2MBB
	gameInfo.GameOptions['icon_T4LAND'] = Prefs.GetFromCurrentProfile('options').icon_T4LAND
	--空军
	gameInfo.GameOptions['icon_T1BOB'] = Prefs.GetFromCurrentProfile('options').icon_T1BOB
	gameInfo.GameOptions['icon_T2BOB'] = Prefs.GetFromCurrentProfile('options').icon_T2BOB
	gameInfo.GameOptions['icon_T3BOB'] = Prefs.GetFromCurrentProfile('options').icon_T3BOB
	gameInfo.GameOptions['icon_T1TRS'] = Prefs.GetFromCurrentProfile('options').icon_T1TRS
	gameInfo.GameOptions['icon_T2TRS'] = Prefs.GetFromCurrentProfile('options').icon_T2TRS
	gameInfo.GameOptions['icon_T3TRS'] = Prefs.GetFromCurrentProfile('options').icon_T3TRS
	gameInfo.GameOptions['icon_T2NOO'] = Prefs.GetFromCurrentProfile('options').icon_T2NOO
	gameInfo.GameOptions['icon_T4AIR'] = Prefs.GetFromCurrentProfile('options').icon_T4AIR
	--海军
	gameInfo.GameOptions['icon_T2DD'] = Prefs.GetFromCurrentProfile('options').icon_T2DD
	gameInfo.GameOptions['icon_T2CA'] = Prefs.GetFromCurrentProfile('options').icon_T2CA
	gameInfo.GameOptions['icon_T1SS'] = Prefs.GetFromCurrentProfile('options').icon_T1SS
	gameInfo.GameOptions['icon_T2SS'] = Prefs.GetFromCurrentProfile('options').icon_T2SS
	gameInfo.GameOptions['icon_T3NKSS'] = Prefs.GetFromCurrentProfile('options').icon_T3NKSS
	gameInfo.GameOptions['icon_T3HUSS'] = Prefs.GetFromCurrentProfile('options').icon_T3HUSS
	gameInfo.GameOptions['icon_T3BB'] = Prefs.GetFromCurrentProfile('options').icon_T3BB
	gameInfo.GameOptions['icon_T4NAVY'] = Prefs.GetFromCurrentProfile('options').icon_T4NAVY
	--建筑
	gameInfo.GameOptions['icon_T3NK'] = Prefs.GetFromCurrentProfile('options').icon_T3NK
	gameInfo.GameOptions['icon_T3SMD'] = Prefs.GetFromCurrentProfile('options').icon_T3SMD
	gameInfo.GameOptions['icon_T1PD'] = Prefs.GetFromCurrentProfile('options').icon_T1PD
	gameInfo.GameOptions['icon_T2PD'] = Prefs.GetFromCurrentProfile('options').icon_T2PD
	gameInfo.GameOptions['icon_T3PD'] = Prefs.GetFromCurrentProfile('options').icon_T3PD
	gameInfo.GameOptions['icon_T3HA'] = Prefs.GetFromCurrentProfile('options').icon_T3HA
	gameInfo.GameOptions['icon_T4BASE'] = Prefs.GetFromCurrentProfile('options').icon_T4BASE
end

local function TryLaunch(skipNoObserversCheck)


		
    if not singlePlayer then
        local notReady = GetPlayersNotReady()
        if notReady then
            for k,v in notReady do
                AddChatText(LOCF("<LOC lobui_0203>%s isn't ready.",v))
            end
            return
        end
    end

    local teamsPresent = {}

    -- make sure there are some players (could all be observers?)
    -- Also count teams. There needs to be at least 2 teams (or all FFA) represented
    local numPlayers = 0
    local numHumanPlayers = 0
    local numTeams = 0
    for slot, player in gameInfo.PlayerOptions:pairs() do
        if player then
            numPlayers = numPlayers + 1

            if player.Human then
                numHumanPlayers = numHumanPlayers + 1
            end

            -- Make sure to increment numTeams for people in the special "-" team, represented by 1.
            if not teamsPresent[player.Team] or player.Team == 1 then
                teamsPresent[player.Team] = true
                numTeams = numTeams + 1
            end
        end
    end

    -- Ensure, for a non-sandbox game, there are some teams to fight.
    if gameInfo.GameOptions['Victory'] ~= 'sandbox' and numTeams < 2 then
        AddChatText(LOC("<LOC lobui_0241>There must be more than one player or team or the Victory Condition must be set "..
                "to Sandbox."))
        return
    end

    if numPlayers == 0 then
        AddChatText(LOC("<LOC lobui_0233>There are no players assigned to player slots, can not continue"))
        return
    end

    if not EveryoneHasEstablishedConnections() then
        return
    end
	
	if gameInfo.GameOptions.CheatsEnabled == 'false' then
		local LaunchEN = 0
        for slot, player in gameInfo.PlayerOptions:pairs() do
			if player.Human then
				if player.CheatMult ~= 1 or player.BuildMult ~= 1 or player.HealthMult ~= 1 then
					LaunchEN = 1
				end
			end
        end
		if LaunchEN == 1 then
		LOG("1234326546457657")
		UIUtil.QuickDialog(GUI, "开启作弊选项后才能使用人类倍数加成",
                                   "启动", 	function() 
												for slot, player in gameInfo.PlayerOptions:pairs() do
													if player.Human then
														player.CheatMult = 1
														player.BuildMult = 1
														player.HealthMult = 1
													end
												end
												TryLaunch(true) 
											end,
                                   "取消", nil,
                                   nil, nil,
                                   true,
                                   {worldCover = false, enterButton = 1, escapeButton = 2}
                                   )
			return
		end
    end

    if not gameInfo.GameOptions.AllowObservers then
        local hostIsObserver = false
        local anyOtherObservers = false
        for k, observer in gameInfo.Observers:pairs() do
            if observer.OwnerID == localPlayerID then
                hostIsObserver = true
            else
                anyOtherObservers = true
            end
        end

        if hostIsObserver then
            AddChatText(LOC("<LOC lobui_0277>Cannot launch if the host isn't assigned a slot and observers are not allowed."))
            return
        end

        if anyOtherObservers then
            if skipNoObserversCheck then
                -- we send the observer list before kicking the players, in case they are not registered as observer
                -- and won't disconnect correctly before the game launch.
                sendObserversList(gameInfo)
                for k,observer in gameInfo.Observers:pairs() do
                    lobbyComm:EjectPeer(observer.OwnerID, "KickedByHost")
                end
                gameInfo.Observers = WatchedValueArray(LobbyComm.maxPlayerSlots)
            else
                UIUtil.QuickDialog(GUI, "<LOC lobui_0278>Launching will kick observers because \"allow observers\" is disabled.  Continue?",
                                   "<LOC _Yes>", function() TryLaunch(true) end,
                                   "<LOC _No>", nil,
                                   nil, nil,
                                   true,
                                   {worldCover = false, enterButton = 1, escapeButton = 2}
                                   )
                return
            end
        end
    end

    numberOfPlayers = numPlayers

    local function LaunchGame()
	
	--log message
	for i = 1, LobbyComm.maxPlayerSlots do
        if gameInfo.ClosedSlots[i] then
            UpdateSlotBackground(i)
        else
            if gameInfo.PlayerOptions[i] then
			--[[
				LOG('*PlayInfo:{')
				LOG('	PlayerName'..repr(gameInfo.PlayerOptions[i].PlayerName))
				LOG('	PlayerTeam:'..repr(gameInfo.PlayerOptions[i].Team))
				--LOG('	PlayerGameID:'..repr(gameInfo.PlayerOptions[i].GID))
				LOG('}')
			]]--
            else
                ClearSlotInfo(i)
            end
        end
    end 
		----smruf
		if lobbyComm:IsHost() then
		--WARN("1")
			local playerspawn = gameInfo.GameOptions['TeamSpawn']
			if playerspawn == 'balances_smurf' or playerspawn == 'nomal_smurf' then
					--WARN("2")
				for id, player in gameInfo.PlayerOptions:pairs() do
						--WARN("3")
					if player.Human then
							--WARN("4")
						local needColor = GetAvailableColor()
						local playSlot = FindSlotForID(FindIDForName(player.PlayerName))
						SetPlayerColor(gameInfo.PlayerOptions[playSlot],needColor)
						lobbyComm:BroadcastData( { Type = 'SetColor', Color = needColor, Slot = playSlot } )
						--SetSlotInfo(playSlot, gameInfo.PlayerOptions[playSlot])
						WARN("检查中(v.Human:"..tostring(player.Human).." / playSlot:"..tostring(playSlot).." / val:"..tostring(GetAvailableColor())..")")
					end
				end
			end
		end

        -- Redundantly send the observer list, because we're mental.
        sendObserversList()

        -- These two things must happen before the flattening step, mostly for terrible reasons.
        -- This isn't ideal, as it leads to redundant UI repaints :/
        AssignAutoTeams()

        -- Force observers to start with the UEF skin to prevent them from launching as "random".
        if IsObserver(localPlayerID) then
            UIUtil.SetCurrentSkin("uef")
        end
    
        -- Eliminate the WatchedValue structures.
        gameInfo = GameInfo.Flatten(gameInfo)

        if gameInfo.GameOptions['RandomMap'] ~= 'Off' then
            autoRandMap = true
            autoMap()
        end

        SetFrontEndData('NextOpBriefing', nil)
        -- assign random factions just as game is launched
        AssignRandomFactions()
        AssignRandomStartSpots()
		
		randstring = randomString(16, "%l%d")
        gameInfo.GameOptions['ReplayID'] = randstring
		
		local VersionName = GameVersion()
		
		if VersionName then
            gameInfo.GameOptions['VersionName'] = VersionName
        else
			gameInfo.GameOptions['VersionName'] = VersionName
        end
		
        AssignAINames()
        local allRatings = {}
        for k,v in gameInfo.PlayerOptions do
			if v.Human then
				--如果是启动器模式，传递分数
				if argv.onlinecheck == 1 and v.PScore then
					allRatings[v.PlayerName] = v.PScore
				elseif v.hx then
					allRatings[v.PlayerName] = v.hx
				end
            end
        end
        gameInfo.GameOptions['Ratings'] = allRatings
		--存一下humaix数据到选项里
		local allHumaixBuildMult = {}
		local allHumaixCheatMult = {}
		local allHumaixHealthMult = {}
        for k,v in gameInfo.PlayerOptions do
            if v.Human and v.BuildMult and v.CheatMult and v.HealthMult then
                allHumaixBuildMult[v.PlayerName] = v.BuildMult
				allHumaixCheatMult[v.PlayerName] = v.CheatMult
				allHumaixHealthMult[v.PlayerName] = v.HealthMult
            end
        end
        gameInfo.GameOptions['HumaixBuild'] = allHumaixBuildMult
		gameInfo.GameOptions['HumaixCheat'] = allHumaixCheatMult
		gameInfo.GameOptions['HumaixHealth'] = allHumaixHealthMult
		
		--FXF210302 上传图标数据
		--------------------------------------------------------------------------------------------------
		UploadIconData(gameInfo)
		--LOG('****icon setted')
		
        -- Tell everyone else to launch and then launch ourselves.
        -- TODO: Sending gamedata here isn't necessary unless lobbyComm is fucking stupid and allows
        -- out-of-order message delivery.

		
        lobbyComm:BroadcastData({ Type = 'Launch', GameInfo = gameInfo })

        -- set the mods
        gameInfo.GameMods = Mods.GetGameMods(gameInfo.GameMods)

        scenarioInfo = MapUtil.LoadScenario(gameInfo.GameOptions.ScenarioFile)
        SetWindowedLobby(false)
		--[[for i = 1, LobbyComm.maxPlayerSlots do
			if gameInfo.ClosedSlots[i] then
				UpdateSlotBackground(i)
			else
				if gameInfo.PlayerOptions[i] then
					LOG('*PlayInfo:{')
					LOG('	PlayerName'..repr(gameInfo.PlayerOptions[i].PlayerName))
					LOG('	PlayerTeam:'..repr(gameInfo.PlayerOptions[i].Team))
					--LOG('	PlayerGameID:'..repr(gameInfo.PlayerOptions[i].GID))
					LOG('}')
				else
					ClearSlotInfo(i)
				end
			end
		end --]]
		--LOG('88888888******8888888888'..repr(gameInfo))
        lobbyComm:LaunchGame(gameInfo)
    end
	--输出开局信息
	--LOG('*Test:',repr(Prefs.GetFromCurrentProfile('options')))
	
	LOG('*GameInfo:',repr(gameInfo.GameOptions))
	LOG('*GameVersion:'..repr(GameVersion()))
	--[[for i = 1, LobbyComm.maxPlayerSlots do
        if gameInfo.ClosedSlots[i] then
            UpdateSlotBackground(i)
        else
            if gameInfo.PlayerOptions[i] then
				LOG('*PlayInfo:{')
				LOG('	PlayerName'..repr(gameInfo.PlayerOptions[i].PlayerName))
				LOG('	PlayerTeam:'..repr(gameInfo.PlayerOptions[i].Team))
				LOG('	PlayerGameID:'..repr(gameInfo.PlayerOptions[i].GID))
				LOG('}')
            else
                ClearSlotInfo(i)
            end
        end
    end ]]--
	#LOG('*GAMEID:'..repr(GameIDcode))
    LaunchGame()
end

function randomString(Length, CharSet)
   -- Length (number)
   -- CharSet (string, optional); e.g. %l%d for lower case letters and digits
    local Chars = {}
    for Loop = 0, 255 do
        Chars[Loop+1] = string.char(Loop)
    end
    local String = table.concat(Chars)

    local Built = {['.'] = Chars}

    local AddLookup = function(CharSet)
        local Substitute = string.gsub(String, '[^'..CharSet..']', '')
        local Lookup = {}
        for Loop = 1, string.len(Substitute) do
            Lookup[Loop] = string.sub(Substitute, Loop, Loop)
        end
        Built[CharSet] = Lookup
        return Lookup
    end

    local CharSet = CharSet or '.'

    if CharSet == '' then
        return ''
    else
        local Result = {}
        local Lookup = Built[CharSet] or AddLookup(CharSet)
        local Range = table.getn(Lookup)

        for Loop = 1,Length do
            Result[Loop] = Lookup[math.random(1, Range)]
        end

        return table.concat(Result)
    end
end

local function AlertHostMapMissing()
    if lobbyComm:IsHost() then
        HostPlayerMissingMapAlert(localPlayerID)
    else
        lobbyComm:SendData(hostID, {Type = 'MissingMap', Id = localPlayerID})
    end
end
-- 关于玩家状态的LOG
local function refreshPlayerLog()
	LOG("*PLAYERLOG REFRESHED:{")
	if gameInfo.PlayerOptions:pairs() then
		for slot,player in gameInfo.PlayerOptions:pairs() do
			if player.Human then
				LOG("	PLAYER="..player.PlayerName..",FACTION="..FACTION_NAMES[player.Faction])
			end
		end
	end
	for slot, observer in gameInfo.Observers:pairs() do
		LOG("	PLAYER="..observer.PlayerName..",FACTION=observer")
	end
	LOG("*PLAYERLOG END")
end

-- Refresh (with a sledgehammer) all the items in the observer list.
local function refreshObserverList()
    GUI.observerList:DeleteAllItems()
	
	--FACN obsever output
	--LOG("*OBSERVER REFRESHED")

    for slot, observer in gameInfo.Observers:pairs() do
        observer.ObserverListIndex = GUI.observerList:GetItemCount() -- Pin-head William made this zero-based

        -- Create a label for this observer of the form:
        -- PlayerName (R:xxx, P:xxx, C:xxx)
        -- Such conciseness is necessary as the field in the UI is rather narrow...
        local observer_label = observer.PlayerName .. " (R:" .. observer.PL
		
		
		--FACN obsever output
		--LOG("*OBSERVERNAME:"..repr(observer.PlayerName))
		

        -- Add the ping only if this entry refers to a different client.
        if observer and (observer.OwnerID ~= localPlayerID) and observer.ObserverListIndex then
            local peer = lobbyComm:GetPeer(observer.OwnerID)

            local ping = 0
            if peer.ping ~= nil then
                ping = math.floor(peer.ping)
            end

            observer_label = observer_label .. ", P:" .. ping
        end

        -- Add the CPU score if one is available.
        local score_CPU = CPU_Benchmarks[observer.PlayerName]
        if score_CPU then
            observer_label = observer_label .. ", C:" .. score_CPU
        end
        observer_label = observer_label .. ")"

        GUI.observerList:AddItem(observer_label)
    end
	refreshPlayerLog()
	--FACN obsever output
	--LOG("*OBSERVER END")
end

--- Called by the host when someone's readyness state changes to update the enabledness of buttons.
local function HostRefreshButtonEnabledness()
    -- disable options when all players are marked ready
    -- Is at least one person not ready?
    local playerNotReady = GetPlayersNotReady() ~= false

    UIUtil.setEnabled(GUI.gameoptionsButton, playerNotReady)
    UIUtil.setEnabled(GUI.defaultOptions, playerNotReady)
    UIUtil.setEnabled(GUI.randMap, playerNotReady)
    UIUtil.setEnabled(GUI.autoTeams, playerNotReady)

    -- Launch button enabled if everyone is ready.
    UIUtil.setEnabled(GUI.launchGameButton, singlePlayer or not playerNotReady)
end

local function UpdateGame()
    LOGX('>> UpdateGame', 'UpdateGame')
    -- This allows us to assume the existence of UI elements throughout.
    if not GUI.uiCreated then
        WARN(debug.traceback(nil, "UpdateGame() pointlessly called before UI creation!"))
        return
    end

    local scenarioInfo
	OLtag = false

    if gameInfo.GameOptions.ScenarioFile and (gameInfo.GameOptions.ScenarioFile ~= "") then
        scenarioInfo = MapUtil.LoadScenario(gameInfo.GameOptions.ScenarioFile)

        if scenarioInfo and scenarioInfo.map and scenarioInfo.map ~= '' then
            GUI.mapView:SetScenario(scenarioInfo)
            ShowMapPositions(GUI.mapView, scenarioInfo)
            ConfigureMapListeners(GUI.mapView, scenarioInfo)
        else
            AlertHostMapMissing()
            GUI.mapView:Clear()
        end
    end

    local isHost = lobbyComm:IsHost()

    local localPlayerSlot = FindSlotForID(localPlayerID)
    if localPlayerSlot then
        local playerOptions = gameInfo.PlayerOptions[localPlayerSlot]

        -- Disable some controls if the user is ready.
        local notReady = not playerOptions.Ready

        UIUtil.setEnabled(GUI.becomeObserver, notReady)
        -- This button is enabled for all non-host players to view the configuration, and for the
        -- host to select presets (rather confusingly, one object represents both potential buttons)
        UIUtil.setEnabled(GUI.restrictedUnitsOrPresetsBtn, not isHost or notReady)

        UIUtil.setEnabled(GUI.LargeMapPreview, notReady)
        UIUtil.setEnabled(GUI.factionSelector, notReady)
    end

    local numPlayers = GetPlayerCount()

    local numAvailStartSpots = LobbyComm.maxPlayerSlots
    if scenarioInfo then
        local armyTable = MapUtil.GetArmies(scenarioInfo)
        if armyTable then
            numAvailStartSpots = table.getn(armyTable)
        end
    end

    UpdateAvailableSlots(numAvailStartSpots)

    -- Update all slots.
    for i = 1, LobbyComm.maxPlayerSlots do
        if gameInfo.ClosedSlots[i] then
            UpdateSlotBackground(i)
        else
            if gameInfo.PlayerOptions[i] then
                SetSlotInfo(i, gameInfo.PlayerOptions[i])
            else
                ClearSlotInfo(i)
            end
        end
    end

    if not singlePlayer then
        refreshObserverList()
    end

    HostRefreshButtonEnabledness()
    RefreshOptionDisplayData(scenarioInfo)

    -- Update the map background to reflect the possibly-changed map.
    if Prefs.GetFromCurrentProfile('LobbyBackground') == 4 then
        RefreshLobbyBackground()
    end

    -- Set the map name at the top right corner in lobby
    if scenarioInfo.name then
        GUI.MapNameLabel:StreamText(scenarioInfo.name, 20)
		--FXF210417 map log
		LOG("*MAPNAME:"..repr(scenarioInfo.name))
		LOG("*MAPFILE:"..repr(scenarioInfo.file))
		LOG("*MAPSIZE:"..repr(scenarioInfo.size))
    end

    -- Add Tooltip info on Map Name Label
    if scenarioInfo then
        local TTips_map_version = scenarioInfo.map_version or "1"
        local TTips_army = table.getsize(scenarioInfo.Configurations.standard.teams[1].armies)
        local TTips_sizeX = scenarioInfo.size[1] / 51.2
        local TTips_sizeY = scenarioInfo.size[2] / 51.2

        local mapTooltip = {
            text = scenarioInfo.name,
            body = '- 地图版本 : '..TTips_map_version..'\n '..
                   '- 地图玩家数 : '..TTips_army..' max'..'\n '..
                   '- 地图大小 : '..TTips_sizeX..'km x '..TTips_sizeY..'km'
        }

        Tooltip.AddControlTooltip(GUI.MapNameLabel, mapTooltip)
        Tooltip.AddControlTooltip(GUI.GameQualityLabel, mapTooltip)
    end

    -- If the large map is shown, update it.
    RefreshLargeMap()

    SetRuleTitleText(gameInfo.GameOptions.GameRules or "")
	
	refreshPlayerLog()
end

--- Update the game quality display
function ShowGameQuality()
    GUI.GameQualityLabel:SetText("")

    -- Can't compute a game quality for random spawns!
    if gameInfo.GameOptions.TeamSpawn ~= 'fixed' then
        return
    end

    local teams = Teams.create()

    -- Everything catches fire if the teams aren't numbered sequentially from 1.
    -- I hope it is not the case that everything catches fire when there are >2 teams, but in
    -- principle that should work...

    -- Start by creating a map from each *used* team to an element from an ascending set of integers.
    local tsTeam = 1
    local teamMap = {}
    for i = 1, LobbyComm.maxPlayerSlots do
        local playerOptions = gameInfo.PlayerOptions[i]
        -- Team 1 represents "No team", so these people are all singleton teams.
        if playerOptions and (teamMap[playerOptions.Team] == nil or playerOptions.Team == 1) then
            teamMap[playerOptions.Team] = tsTeam
            tsTeam = tsTeam + 1
        end
    end

    -- Now we just use the map to relate real teams to trueSkill teams.
    for i = 1, LobbyComm.maxPlayerSlots do
        local playerOptions = gameInfo.PlayerOptions[i]
        if playerOptions then
            -- Can't do it for AI, either, not sensibly.
            if not playerOptions.Human then
                return
            end

            local player = Player.create(
                playerOptions.PlayerName,
                Rating.create(playerOptions.Score, playerOptions.DEV or 0)
            )

            teams:addPlayer(teamMap[playerOptions.Team], player)
        end
    end

    -- Nothing to do if we have only one team...
    if table.getn(teams:getTeams()) < 2 then
        return
    end

    local quality = Trueskill.computeQuality(teams)

    if quality > 0 then
        gameInfo.GameOptions.Quality = quality
        GUI.GameQualityLabel:StreamText("游戏体验指数 : " .. quality .. "%", 20)
    end
end

-- Update our local gameInfo.GameMods from selected map name and selected mods, then
-- notify other clients about the change.
local function HostUpdateMods(newPlayerID, newPlayerName)
    if lobbyComm:IsHost() then
        local newmods = {}
        local missingmods = {}
        for k,modId in selectedMods do
            if IsModAvailable(modId) then
                newmods[modId] = true
            else
                table.insert(missingmods, modId)
            end
        end
        if not table.equal(gameInfo.GameMods, newmods) and not newPlayerID then
            gameInfo.GameMods = newmods
            lobbyComm:BroadcastData { Type = "ModsChanged", GameMods = gameInfo.GameMods }
            local nummods = 0
            local uids = ""

            for k in gameInfo.GameMods do
                nummods = nummods + 1
                if uids == "" then
                    uids =  k
                else
                    uids = string.format("%s %s", uids, k)
                end

            end
            GpgNetSend('GameMods', "activated", nummods)

            if nummods > 0 then
                GpgNetSend('GameMods', "uids", uids)
            end
        elseif not table.equal(gameInfo.GameMods, newmods) and newPlayerID then
            local modnames = ""
            local totalMissing = table.getn(missingmods)
            local totalListed = 0
            if totalMissing > 0 then
                for index, id in missingmods do
                    for k,mod in Mods.GetGameMods() do
                        if mod.uid == id then
                            totalListed = totalListed + 1
                            if totalMissing == totalListed then
                                modnames = modnames .. " " .. mod.name
                            else
                                modnames = modnames .. " " .. mod.name .. " + "
                            end
                        end
                    end
                end
            end
            local reason = (LOCF('<LOC lobui_0588>You were automaticly removed from the lobby because you ' ..
                               'don\'t have the following mod(s):\n%s \nPlease, install the mod before you join the game lobby',
                               modnames))
            -- TODO: Verify this functionality
            if FindNameForID(newPlayerID) then
                AddChatText(FindNameForID(newPlayerID)..' kicked because he does not have this mod : '..modnames)
            else
                if newPlayerName then
                    AddChatText(newPlayerName..' kicked because he does not have this mod : '..modnames)
                else
                    AddChatText('The last player is kicked because he does not have this mod : '..modnames)
                end
            end
            lobbyComm:EjectPeer(newPlayerID, reason)
        end
    end
	--FXF210117 mod log
	LOG("*MODRELOADED")
	for k,mod in Mods.GetGameMods() do
		LOG("*MODNUM:"..repr(k))
		LOG("*MODNAME:"..repr(mod.name))
		LOG("*MODLOCA:"..repr(mod.location))
		LOG("*MODUID:"..repr(mod.uid))
	end
	LOG("*MODEnd")
end


--updata ver

local function HostUpdateVersion(newPlayerID, newPlayerName)

    if lobbyComm:IsHost() then
        
		
        local newVersion = GameVersion()
		local hostOL = argv.onlinecheck
		local reason = (LOCF('There is no reason 略略略'))
            LOGX('>> IsHostrun', 'DEBUGGame')
			
		--检测游戏版本
        if checkVersion[newPlayerID] != newVersion and newPlayerID then

            local versionnames = GameVersion()

            reason = (LOCF('<LOC lobui_0588>\n你版本太低了，' ..
                               '\n我们现在联机都是\n.%s了，需要更新到最新版本 \n\n下载地址：QQ群659797309 ',
                               versionnames))
            -- TODO: 验证函数
            if FindNameForID(newPlayerID) then
                AddChatText(FindNameForID(newPlayerID)..'被移出游戏，版本与主机不符:主机版本 '..versionnames..'	客户端版本：可能是3640或以前')
            else
                if newPlayerName then
                    AddChatText(newPlayerName..' 因为版本不符而被移出游戏 主机版本 : '..versionnames..'	客户端版本：'..checkVersion[newPlayerID])

                else
                    AddChatText('这个玩家因为版本不符而被移出游戏 主机版本：'..versionnames..'	客户端版本：可能是3640或以前')
                end
            end

			LOGX('>> :EjectPeer' , 'DEBUGGame')
            lobbyComm:EjectPeer(newPlayerID, reason)
            
        end
    end
end

-- Holds some utility functions to do with game option management.
local OptionUtils = {
    -- Set all game options to their default values.
    SetDefaults = function()
        local options = {}
        for index, option in globalOpts do
            options[option.key] = option.values[option.default].key
        end

        for index, option in AIOpts do
            options[option.key] = option.values[option.default].key
        end

        SetGameOptions(options)
    end
}

-- callback when Mod Manager dialog finishes (modlist==nil on cancel)
-- FIXME: The mod manager should be given a list of game mods set by the host, which
-- clients can look at but not changed, and which don't get saved in our local prefs.
function OnModsChanged(modlist, ignoreRefresh)
    if modlist then
        Mods.SetSelectedMods(modlist)
        if lobbyComm:IsHost() then
            selectedMods = table.map(function (m) return m.uid end, Mods.GetGameMods())
            HostUpdateMods()
        end
        if not ignoreRefresh then
            UpdateGame()
        end
    end
end

function HostSetSlotClosed(slot, closed)
    -- Don't close an occupied slot.
    if gameInfo.PlayerOptions[slot] then
        return
    end

    lobbyComm:BroadcastData(
        {
            Type = 'SlotClosed',
            Slot = slot,
            Closed = closed
        }
    )

            gameInfo.ClosedSlots[slot] = closed
            gameInfo.SpawnMex[slot] = false
            ClearSlotInfo(slot)
end

function SetSlotClosedSpawnMex (slot)
            -- Don't close an occupied slot.
            if gameInfo.PlayerOptions[slot] then
                return
            end

            lobbyComm:BroadcastData(
                {
                    Type = 'SlotClosedSpawnMex',
                    Slot = slot,
                    ClosedSpawnMex = true
                }
            )

            gameInfo.ClosedSlots[slot] = true
            gameInfo.SpawnMex[slot] = true
            ClearSlotInfo(slot)
end
		
function GetAvailableColor()
    for colorIndex, colorVal in gameColors.PlayerColors do
        if IsColorFree(colorIndex) then
            return colorIndex
        end
    end
end

--- This function is retarded.
-- Unfortunately, we're stuck with it.
-- The game requires both ArmyColor and PlayerColor be set. We don't want to have to write two fields
-- all the time, and the magic that makes PlayerData work precludes adding member functions to it.
-- So, we have this. Tough shit. :P
function SetPlayerColor(playerData, newColor)
    playerData.ArmyColor = newColor
    playerData.PlayerColor = newColor
end

--- Find and return the id of an unoccupied slot.
--
-- @return The id of an empty slot, of -1 if none is available.
function HostFindEmptySlot()
    for i = 1, numOpenSlots do
        if not gameInfo.PlayerOptions[i] and not gameInfo.ClosedSlots[i] then
            return i
        end
    end

    return -1
end



--- Attempt to add a player to a slot. If no is available, add them as an observer.
--
-- @param senderID The peer ID of the player we're adding.
-- @param slot The slot to insert the player to. A value of less than 1 indicates "any slot"
-- @param playerData A PlayerData object representing the player to add.
function HostTryAddPlayer(senderID, slot, playerData)
    LOGX('>> HostTryAddPlayer > requestedPlayerName='..tostring(playerData.PlayerName), 'Connecting')

    -- CPU benchmark code
    if playerData.Human and not singlePlayer then
        lobbyComm:SendData(senderID, {Type='CPUBenchmark', Benchmarks=CPU_Benchmarks})
    end

    local newSlot = slot

    if not slot or slot < 1 or newSlot > numOpenSlots then
        newSlot = HostFindEmptySlot()
    end

    -- if no slot available, and human, try to make them an observer
    if newSlot == -1 then
        PrivateChat(senderID, LOC("<LOC lobui_0237>No slots available, attempting to make you an observer"))
        if playerData.Human then
			HostTryAddObserver(senderID, playerData)
        end
        return
    end

    playerData.PlayerName = lobbyComm:MakeValidPlayerName(senderID, playerData.PlayerName)

    -- if a color is requested, attempt to use that color if available, otherwise, assign first available
    if not IsColorFree(playerData.PlayerColor) then
        SetPlayerColor(playerData, GetAvailableColor())
    end

    gameInfo.PlayerOptions[newSlot] = playerData
    lobbyComm:BroadcastData(
        {
            Type = 'SlotAssigned',
            Slot = newSlot,
            Options = playerData:AsTable(),
        }
    )

    SetSlotInfo(newSlot, gameInfo.PlayerOptions[newSlot])
    -- This is far from optimally efficient, as it will SetSlotInfo twice when autoteams is enabled.
    AssignAutoTeams()
end

function HostTryMovePlayer(senderID, currentSlot, requestedSlot)
    #LOG("SenderID: " .. senderID .. " currentSlot: " .. currentSlot .. " requestedSlot: " .. requestedSlot)

    if gameInfo.PlayerOptions[currentSlot].Ready then
        #LOG("HostTryMovePlayer: player is marked ready and can not move")
        return
    end

    if gameInfo.PlayerOptions[requestedSlot] then
        #LOG("HostTryMovePlayer: requested slot " .. requestedSlot .. " already occupied")
        return
    end

    if gameInfo.ClosedSlots[requestedSlot] then
        #LOG("HostTryMovePlayer: requested slot " .. requestedSlot .. " is closed")
        return
    end

    if requestedSlot > numOpenSlots or requestedSlot < 1 then
        #LOG("HostTryMovePlayer: requested slot " .. requestedSlot .. " is out of range")
        return
    end

    gameInfo.PlayerOptions[requestedSlot] = gameInfo.PlayerOptions[currentSlot]
    gameInfo.PlayerOptions[currentSlot] = nil
    ClearSlotInfo(currentSlot)
    SetSlotInfo(requestedSlot, gameInfo.PlayerOptions[requestedSlot])

    lobbyComm:BroadcastData(
        {
            Type = 'SlotMove',
            OldSlot = currentSlot,
            NewSlot = requestedSlot,
            Options = gameInfo.PlayerOptions[requestedSlot]:AsTable(),
        }
    )

    -- This is far from optimally efficient, as it will SetSlotInfo twice when autoteams is enabled.
    AssignAutoTeams()
end

--- Add an observer
--
-- @param observerData A PlayerData object representing this observer.
function HostTryAddObserver(senderID, observerData)
    local index = 1
    while gameInfo.Observers[index] do
        index = index + 1
    end

    LOGX('>> HostTryAddObserver > requestedObserverName='..tostring(observerData.PlayerName), 'Connecting')
    observerData.PlayerName = lobbyComm:MakeValidPlayerName(senderID, observerData.PlayerName)

    gameInfo.Observers[index] = observerData

    lobbyComm:BroadcastData(
        {
            Type = 'ObserverAdded',
            Slot = index,
            Options = observerData:AsTable(),
        }
    )
    SendSystemMessage(LOCF("<LOC lobui_0202>%s has joined as an observer.",observerName), "lobui_0202")
    refreshObserverList()
end

function HostConvertPlayerToObserver(senderID, playerSlot, ignoreMsg)
    -- make sure player exists
    if not gameInfo.PlayerOptions[playerSlot] then
        WARN("HostConvertPlayerToObserver for nonexistent player in slot " .. tostring(playerSlot))
        return
    end

    -- find a free observer slot
    local index = 1
    while gameInfo.Observers[index] do
        index = index + 1
    end

    local playerName = gameInfo.PlayerOptions[playerSlot].PlayerName
    gameInfo.Observers[index] = gameInfo.PlayerOptions[playerSlot]
    gameInfo.PlayerOptions[playerSlot] = nil

    if lobbyComm:IsHost() then
        GpgNetSend('PlayerOption', string.format("team %s %d %s", playerName, -1, 0))
    end

    ClearSlotInfo(playerSlot)
    refreshObserverList()

    -- TODO: can probably avoid transmitting the options map here. The slot number should be enough.
    lobbyComm:BroadcastData(
        {
            Type = 'ConvertPlayerToObserver',
            OldSlot = playerSlot,
            NewSlot = index,
            Options = gameInfo.Observers[index]:AsTable(),
        }
    )

    if ignoreMsg then
        SendSystemMessage(LOCF("<LOC lobui_0226>%s has switched from a player to an observer.", gameInfo.Observers[index].PlayerName), "lobui_0226")
    end
end

function HostConvertObserverToPlayer(senderID, fromObserverSlot, toPlayerSlot, ignoreMsg)
    -- If no slot is specified (user clicked "go player" button), select a default.
    if not toPlayerSlot or toPlayerSlot < 1 or toPlayerSlot > numOpenSlots then
        toPlayerSlot = HostFindEmptySlot()
    end

    if not gameInfo.Observers[fromObserverSlot] then -- IF no Observer on the current slot : QUIT
        return
    elseif gameInfo.PlayerOptions[toPlayerSlot] then -- IF Player is in the target slot : QUIT
        return
    elseif gameInfo.ClosedSlots[toPlayerSlot] then -- IF target slot is Closed : QUIT
        return
    end

    local incomingPlayer = gameInfo.Observers[fromObserverSlot]

    -- Give them a default colour if the one they already have isn't free.
    if not IsColorFree(incomingPlayer.PlayerColor) then
        local newColour = GetAvailableColor()
        SetPlayerColor(incomingPlayer, newColour)
    end

    gameInfo.PlayerOptions[toPlayerSlot] = incomingPlayer
    gameInfo.Observers[fromObserverSlot] = nil

    lobbyComm:BroadcastData(
        {
            Type = 'ConvertObserverToPlayer',
            OldSlot = fromObserverSlot,
            NewSlot = toPlayerSlot,
            Options =  gameInfo.PlayerOptions[toPlayerSlot]:AsTable(),
        }
    )

    if ignoreMsg then
        SendSystemMessage(LOCF("<LOC lobui_0227>%s has switched from an observer to player.", incomingPlayer.PlayerName), "lobui_0227")
    end

    refreshObserverList()
    SetSlotInfo(toPlayerSlot, gameInfo.PlayerOptions[toPlayerSlot])

    -- This is far from optimally efficient, as it will SetSlotInfo twice when autoteams is enabled.
    AssignAutoTeams()
end

function HostRemoveAI(slot)
    if gameInfo.PlayerOptions[slot].Human then
        WARN('Use EjectPlayer to remove humans')
        return
    end

    ClearSlotInfo(slot)
    gameInfo.PlayerOptions[slot] = nil
    lobbyComm:BroadcastData(
        {
            Type = 'ClearSlot',
            Slot = slot,
        }
    )
	
	--FACN check AI
	LOG("*REMOVED AI IN SLOT:"..repr(slot))
end

function autoMap()
    local randomAutoMap
    if gameInfo.GameOptions['RandomMap'] == 'Official' then
        randomAutoMap = import('/lua/ui/dialogs/mapselect.lua').randomAutoMap(true)
    else
        randomAutoMap = import('/lua/ui/dialogs/mapselect.lua').randomAutoMap(false)
    end
end

function HostPlayerMissingMapAlert(id)
    local slot = FindSlotForID(id)
    local name
    local needMessage = false
    if slot then
        name = gameInfo.PlayerOptions[slot].PlayerName
        if not gameInfo.PlayerOptions[slot].BadMap then
            needMessage = true
        end
        gameInfo.PlayerOptions[slot].BadMap = true
    else
        slot = FindObserverSlotForID(id)
        if slot then
            name = gameInfo.Observers[slot].PlayerName
            if not gameInfo.Observers[slot].BadMap then
                needMessage = true
            end
            gameInfo.Observers[slot].BadMap = true
        end
    end

    if needMessage then
        SendSystemMessage(LOCF("<LOC lobui_0330>%s is missing map %s.", name, gameInfo.GameOptions.ScenarioFile))
        #LOG('>> '..name..' is missing map '..gameInfo.GameOptions.ScenarioFile)
        if name == localPlayerName then
            #LOG('>> '..gameInfo.GameOptions.ScenarioFile..' replaced with '..'SCMP_009')
            SetGameOption('ScenarioFile', '/maps/scmp_009/scmp_009_scenario.lua')
        end
    end
end

function ClientsMissingMap()
    local ret = nil

    for index, player in gameInfo.PlayerOptions:pairs() do
        if player.BadMap then
            if not ret then ret = {} end
            table.insert(ret, player.PlayerName)
        end
    end

    for index, observer in gameInfo.Observers:pairs() do
        if observer.BadMap then
            if not ret then ret = {} end
            table.insert(ret, observer.PlayerName)
        end
    end

    return ret
end

function ClearBadMapFlags()
    for index, player in gameInfo.PlayerOptions:pairs() do
        player.BadMap = false
    end

    for index, observer in gameInfo.Observers:pairs() do
        observer.BadMap = false
    end
end

function EnableSlot(slot)
	GUI.slots[slot].ecocheatText:Enable()
	GUI.slots[slot].buildcheatText:Enable()
	GUI.slots[slot].healthcheatText:Enable()
	GUI.slots[slot].hxlmText:Enable()
    GUI.slots[slot].team:Enable()
    GUI.slots[slot].color:Enable()
    GUI.slots[slot].faction:Enable()
    GUI.slots[slot].ready:Enable()
end

function DisableSlot(slot, exceptReady)
	GUI.slots[slot].ecocheatText:Disable()
	GUI.slots[slot].buildcheatText:Disable()
	GUI.slots[slot].healthcheatText:Disable()
	GUI.slots[slot].hxlmText:Disable()
    GUI.slots[slot].team:Disable()
    GUI.slots[slot].color:Disable()
    GUI.slots[slot].faction:Disable()
    if not exceptReady then
        GUI.slots[slot].ready:Disable()
    end
end

-- set up player "slots" which is the line representing a player and player specific options
function CreateSlotsUI(makeLabel)
    local Combo = import('/lua/ui/controls/combo.lua').Combo
    local BitmapCombo = import('/lua/ui/controls/combo.lua').BitmapCombo
    local StatusBar = import('/lua/maui/statusbar.lua').StatusBar
    local ColumnLayout = import('/lua/ui/controls/columnlayout.lua').ColumnLayout

    -- The dimensions of the columns used for slot UI controls.
    local COLUMN_POSITIONS = {1, 11, 532 , 582, 632, 35, 35, 85, 135, 322, 392, 462, 682, 754}
    local COLUMN_WIDTHS = {20, 20, 45, 45, 45, 45, 45, 45, 187, 59, 59, 59, 62, 51}

    local labelGroup = ColumnLayout(GUI.playerPanel, COLUMN_POSITIONS, COLUMN_WIDTHS)

    GUI.labelGroup = labelGroup
    labelGroup.Width:Set(791)
    labelGroup.Height:Set(21)
    LayoutHelpers.AtLeftTopIn(labelGroup, GUI.playerPanel, 5, 5)
	
	local slotLabel = makeLabel("#", 14)
    labelGroup:AddChild(slotLabel)
	Tooltip.AddControlTooltip(slotLabel, 'slot_number')
	
	-- No label required for the first column (flag), so skip it. (evil hack)
    labelGroup.numChildren = labelGroup.numChildren + 1
    local ecocheatLabel = makeLabel("经济", 14)
    labelGroup:AddChild(ecocheatLabel)
    Tooltip.AddControlTooltip(ecocheatLabel, 'ecocheat')
	
    local buildcheatLabel = makeLabel("建造", 14)
    labelGroup:AddChild(buildcheatLabel)
    Tooltip.AddControlTooltip(buildcheatLabel, 'buildcheat')
	
	local healthcheatLabel = makeLabel("血量", 14)
    labelGroup:AddChild(healthcheatLabel)
    Tooltip.AddControlTooltip(healthcheatLabel, 'healthcheat')
	
	local score = makeLabel("分数", 14)
    labelGroup:AddChild(score)
    Tooltip.AddControlTooltip(score, 'rating')
	
	local hxlm = makeLabel("分数", 14)
    labelGroup:AddChild(hxlm)
    Tooltip.AddControlTooltip(hxlm, 'hx')
	
	local gamenum = makeLabel("局数", 14)
    labelGroup:AddChild(gamenum)
    Tooltip.AddControlTooltip(gamenum, 'num')

    local nameLabel = makeLabel("名字", 14)
    labelGroup:AddChild(nameLabel)
    Tooltip.AddControlTooltip(nameLabel, 'lob_slot')

    local colorLabel = makeLabel("颜色", 14)
    labelGroup:AddChild(colorLabel)
    Tooltip.AddControlTooltip(colorLabel, 'lob_color')

    local factionLabel = makeLabel("阵营", 14)
    labelGroup:AddChild(factionLabel)
    Tooltip.AddControlTooltip(factionLabel, 'lob_faction')

    local teamLabel = makeLabel("联盟", 14)
    labelGroup:AddChild(teamLabel)
    Tooltip.AddControlTooltip(teamLabel, 'lob_team')

    if not singlePlayer then
        labelGroup:AddChild(makeLabel("Ping/CPU", 14))
        labelGroup:AddChild(makeLabel("就绪", 14))
    end

    for i= 1, LobbyComm.maxPlayerSlots do
        -- Capture the index in the current closure so it's accessible on callbacks
        local curRow = i

        -- The background is parented on the GUI so it doesn't vanish when we hide the slot.
        local slotBackground = Bitmap(GUI, UIUtil.SkinnableFile("/SLOT/slot-dis.dds"))

        -- Inherit dimensions of the slot control from the background image.
        local newSlot = ColumnLayout(GUI.playerPanel, COLUMN_POSITIONS, COLUMN_WIDTHS)
        newSlot.Width:Set(slotBackground.Width)
        newSlot.Height:Set(slotBackground.Height)

        LayoutHelpers.AtLeftTopIn(slotBackground, newSlot)
        newSlot.SlotBackground = slotBackground

        -- Default mouse behaviours for the slot.
        local defaultHandler = function(self, event)
            if curRow > numOpenSlots then
                return
            end

            local associatedMarker = GUI.mapView.startPositions[curRow]
            if event.Type == 'MouseEnter' then
                if gameInfo.GameOptions['TeamSpawn'] == 'fixed' then
                    associatedMarker.indicator:Play()
                end
            elseif event.Type == 'MouseExit' then
                associatedMarker.indicator:Stop()
            elseif event.Type == 'ButtonDClick' then
                DoSlotBehavior(curRow, 'occupy', '')
            end

            return Group.HandleEvent(self, event)
        end
        newSlot.HandleEvent = defaultHandler
		
        -- Slot number
        local slotNumber = UIUtil.CreateText(newSlot, i, 14, 'Arial')
        slotNumber.Width:Set(COLUMN_WIDTHS[1])
        slotNumber.Height:Set(newSlot.Height)
        newSlot:AddChild(slotNumber)
        newSlot.tooltipnumber = Tooltip.AddControlTooltip(slotNumber, 'slot_number')
		
        -- COUNTRY
        -- Added a bitmap on the left of Rating, the bitmap is a Flag of Country
        local flag = Bitmap(newSlot, UIUtil.SkinnableFile("/countries/world.dds"))
        newSlot.KinderCountry = flag
        flag.Width:Set(COLUMN_WIDTHS[2])
        flag.Height:Set(15)
        newSlot:AddChild(flag)

--]]
		--ecocheat 2021-8-19 LinLin
        local ecocheatText = Edit(newSlot)
		ecocheatText.Width:Set(180)
		ecocheatText.Height:Set(16)
		ecocheatText:SetFont(UIUtil.bodyFont, 14)
		ecocheatText:SetForegroundColor(UIUtil.fontColor)
		--主机可编辑，背景偏白，其他为透明
		if lobbyComm:IsHost() then
			ecocheatText:SetBackgroundColor("55555555")
		else
			ecocheatText:SetBackgroundColor("00000000")
		end
		ecocheatText:ShowBackground(true)
		ecocheatText:SetDropShadow(true)
        newSlot.ecocheatText = ecocheatText
        newSlot:AddChild(ecocheatText)
        ecocheatText.Width:Set(COLUMN_WIDTHS[3])
		--字符改变后执行
        ecocheatText.OnTextChanged = function(self, newText, oldText)
			local multNum
			--如果什么都没用那加成就是1
			if newText == "" then
				multNum = 1
			else
			--排除掉数字以外的字符
				multNum = tonumber(newText)
			end
			--范围
			if multNum < 0 or multNum > 1000 then
				WARN("try to set an out ranged ecomult number:"..repr(newText))
				self:SetText(oldText)
			else
				--数字不为1即设置为红色
				if multNum ~= 1 then
					self:SetForegroundColor("FFFF5555")
				else--否则白色
					ecocheatText:SetForegroundColor(UIUtil.fontColor)
				end
				if lobbyComm:IsHost() then
					
					--选项
					options = {};
					
					--参数
					options.CheatMult = multNum
					--发送到客户端
					SetPlayerOptions(curRow, options, true)
				end
			end
        end

        -- buildcheat
		local buildcheatText = Edit(newSlot)
		buildcheatText.Width:Set(180)
		buildcheatText.Height:Set(16)
		buildcheatText:SetFont(UIUtil.bodyFont, 14)
		buildcheatText:SetForegroundColor(UIUtil.fontColor)
		--主机可编辑，背景偏白，其他为透明
		if lobbyComm:IsHost() then
			buildcheatText:SetBackgroundColor("55555555")
		else
			buildcheatText:SetBackgroundColor("00000000")
		end
		buildcheatText:ShowBackground(true)
		buildcheatText:SetDropShadow(true)
        newSlot.buildcheatText = buildcheatText
        newSlot:AddChild(buildcheatText)
        buildcheatText.Width:Set(COLUMN_WIDTHS[4])
		--字符改变后执行
        buildcheatText.OnTextChanged = function(self, newText, oldText)
			local multNum
			--如果什么都没用那加成就是1
			if newText == "" then
				multNum = 1
			else
			--排除掉数字以外的字符
				multNum = tonumber(newText)
			end
			--范围
			if multNum < 0 or multNum > 1000 then
				WARN("try to set an out ranged buildmult number:"..repr(newText))
				self:SetText(oldText)
			else
				--数字不为1即设置为红色
				if multNum ~= 1 then
					self:SetForegroundColor("FFFF5555")
				else--否则白色
					buildcheatText:SetForegroundColor(UIUtil.fontColor)
				end
				if lobbyComm:IsHost() then
					
					--选项
					options = {};
					
					--参数
					options.BuildMult = multNum
					--发送到客户端
					SetPlayerOptions(curRow, options, true)
				end
			end
        end
		
		 -- healthcheat
		local healthcheatText = Edit(newSlot)
		healthcheatText.Width:Set(180)
		healthcheatText.Height:Set(16)
		healthcheatText:SetFont(UIUtil.bodyFont, 14)
		healthcheatText:SetForegroundColor(UIUtil.fontColor)
		--主机可编辑，背景偏白，其他为透明
		if lobbyComm:IsHost() then
			healthcheatText:SetBackgroundColor("55555555")
		else
			healthcheatText:SetBackgroundColor("00000000")
		end
		healthcheatText:ShowBackground(true)
		healthcheatText:SetDropShadow(true)
        newSlot.healthcheatText = healthcheatText
        newSlot:AddChild(healthcheatText)
        healthcheatText.Width:Set(COLUMN_WIDTHS[5])
		--字符改变后执行
        healthcheatText.OnTextChanged = function(self, newText, oldText)
			local multNum
			--如果什么都没用那加成就是1
			if newText == "" then
				multNum = 1
			else
			--排除掉数字以外的字符
				multNum = tonumber(newText)
			end
			--范围
			if multNum < 0 or multNum > 1000 then
				WARN("try to set an out ranged healthmult number:"..repr(newText))
				self:SetText(oldText)
			else
				--数字不为1即设置为红色
				if multNum ~= 1 then
					self:SetForegroundColor("FFFF5555")
				else--否则白色
					healthcheatText:SetForegroundColor(UIUtil.fontColor)
				end
				if lobbyComm:IsHost() then
					
					--选项
					options = {};
					
					--参数
					options.HealthMult = multNum
					--发送到客户端
					SetPlayerOptions(curRow, options, true)
				end
			end
        end
        

		-- score(新分数系统)
		local scoreText = UIUtil.CreateText(newSlot, "", 14, 'Arial')
		newSlot.scoreText = scoreText
		scoreText:SetColor('B9BFB9')
		scoreText:SetDropShadow(true)
		newSlot:AddChild(scoreText)
		scoreText.Width:Set(COLUMN_WIDTHS[6])
		newSlot.tooltiprating = Tooltip.AddControlTooltip(scoreText, 'rating')
			
		
		-- hxhx(老分级系统)
		local hxlmText = BitmapCombo(newSlot, hxlmIcons, 1, false, nil, "UI_Tab_Rollover_01", "UI_Tab_Click_01")
		newSlot.hxlmText = hxlmText
		newSlot:AddChild(hxlmText)
		hxlmText.Width:Set(COLUMN_WIDTHS[7])
		hxlmText.OnClick = function(self, index, text)
			Tooltip.DestroyMouseoverDisplay()
			#WARN("检查中(slot:"..tostring(curRow).." / key:"..tostring(index).." / val:"..tostring(gameInfo.PlayerOptions[curRow].PlayerName).." / hxlm信息:"..tostring(hxlmtable[index])..")")
			--如果是服务器，则发送信息到客户端
			if lobbyComm:IsHost() then
			
				--选项
				options = {};
			
				--参数
				options.hx = hxlmtable[index];
				options.hxIndex = index;
				
				--发送到客户端
				SetPlayerOptions(curRow, options, true)
				
			end
		end
		Tooltip.AddControlTooltip(hxlmText, '分数')
		Tooltip.AddComboTooltip(hxlmText, hxlmTooltips)
		hxlmText.OnEvent = defaultHandler
		
		
		--游戏数
		local gamenumText = UIUtil.CreateText(newSlot, "", 14, 'Arial')
		newSlot.gamenumText = gamenumText
		gamenumText:SetColor('B9BFB9')
		gamenumText:SetDropShadow(true)
		newSlot:AddChild(gamenumText)
		gamenumText.Width:Set(COLUMN_WIDTHS[8])
		newSlot.tooltiprating = Tooltip.AddControlTooltip(gamenumText, 'gamenum')
		
		
        -- Name
        local nameLabel = Combo(newSlot, 14, 12, true, nil, "UI_Tab_Rollover_01", "UI_Tab_Click_01")
        newSlot.name = nameLabel
        nameLabel._text:SetFont('Arial Gras', 15)
        newSlot:AddChild(nameLabel)
        nameLabel.Width:Set(COLUMN_WIDTHS[9])
		

        -- left deal with name clicks
        nameLabel.OnEvent = defaultHandler
        nameLabel.OnClick = function(self, index, text)
            DoSlotBehavior(curRow, self.slotKeys[index], text)
        end
		
	
        -- Color
        local colorSelector = BitmapCombo(newSlot, gameColors.PlayerColors, 1, true, nil, "UI_Tab_Rollover_01", "UI_Tab_Click_01")
        newSlot.color = colorSelector

        newSlot:AddChild(colorSelector)
        colorSelector.Width:Set(COLUMN_WIDTHS[10])
        colorSelector.OnClick = function(self, index)
            if not lobbyComm:IsHost() then
                lobbyComm:SendData(hostID, { Type = 'RequestColor', Color = index, Slot = curRow } )
                SetPlayerColor(gameInfo.PlayerOptions[curRow], index)
                UpdateGame()
            else
                if IsColorFree(index) then
                    lobbyComm:BroadcastData( { Type = 'SetColor', Color = index, Slot = curRow } )
                    SetPlayerColor(gameInfo.PlayerOptions[curRow], index)
                    UpdateGame()
                else
                    self:SetItem( gameInfo.PlayerOptions[curRow].PlayerColor )
                end
            end
        end
        colorSelector.OnEvent = defaultHandler
        Tooltip.AddControlTooltip(colorSelector, 'lob_color')

        -- Faction
        -- builds the faction tables, and then adds random faction icon to the end
        local factionBmps = {}
        local factionTooltips = {}
        for index, tbl in FactionData.Factions do
            factionBmps[index] = tbl.SmallIcon
            factionTooltips[index] = tbl.TooltipID
        end
        table.insert(factionBmps, "/faction_icon-sm/random_ico.dds")
        table.insert(factionTooltips, 'lob_random')

        local factionSelector = BitmapCombo(newSlot, factionBmps, table.getn(factionBmps), nil, nil, "UI_Tab_Rollover_01", "UI_Tab_Click_01")
        newSlot.faction = factionSelector
        newSlot:AddChild(factionSelector)
        factionSelector.Width:Set(COLUMN_WIDTHS[11])
        factionSelector.OnClick = function(self, index)
            SetPlayerOption(curRow, 'Faction', index)
            if curRow == FindSlotForID(FindIDForName(localPlayerName)) then
                GUI.factionSelector:SetSelected(index)
            end

            Tooltip.DestroyMouseoverDisplay()
        end
        Tooltip.AddControlTooltip(factionSelector, 'lob_faction')
        Tooltip.AddComboTooltip(factionSelector, factionTooltips)
        factionSelector.OnEvent = defaultHandler

        -- Team
        local teamSelector = BitmapCombo(newSlot, teamIcons, 1, false, nil, "UI_Tab_Rollover_01", "UI_Tab_Click_01")
        newSlot.team = teamSelector
        newSlot:AddChild(teamSelector)
        teamSelector.Width:Set(COLUMN_WIDTHS[12])
        teamSelector.OnClick = function(self, index, text)
            Tooltip.DestroyMouseoverDisplay()
            SetPlayerOption(curRow, 'Team', index)
        end
        Tooltip.AddControlTooltip(teamSelector, 'lob_team')
        Tooltip.AddComboTooltip(teamSelector, teamTooltips)
        teamSelector.OnEvent = defaultHandler

        -- Ping
        local pingGroup = Group(newSlot)
        newSlot.pingGroup = pingGroup
        pingGroup.Width:Set(COLUMN_WIDTHS[13])
        pingGroup.Height:Set(newSlot.Height)
        newSlot:AddChild(pingGroup)

        local pingStatus = StatusBar(pingGroup, 0, 500, false, false,
            UIUtil.SkinnableFile('/game/unit_bmp/bar-back_bmp.dds'),
            UIUtil.SkinnableFile('/game/unit_bmp/bar-01_bmp.dds'),
            true)
        newSlot.pingStatus = pingStatus
        LayoutHelpers.AtTopIn(pingStatus, pingGroup, 5)
        LayoutHelpers.AtLeftIn(pingStatus, pingGroup, 0)
        LayoutHelpers.AtRightIn(pingStatus, pingGroup, 0)
		Tooltip.AddControlTooltip(pingStatus, 'lob_ping')
        -- Ready Checkbox
        local readyBox = UIUtil.CreateCheckbox(newSlot, '/CHECKBOX/')
        newSlot.ready = readyBox
        newSlot:AddChild(readyBox)
		readyBox.Width:Set(COLUMN_WIDTHS[14])
        readyBox.OnCheck = function(self, checked)
            UIUtil.setEnabled(GUI.becomeObserver, not checked)
            if checked then
                DisableSlot(curRow, true)
            else
                EnableSlot(curRow)
            end
            SetPlayerOption(curRow, 'Ready', checked)
        end

        newSlot.HideControls = function()
            -- hide these to clear slot of visible data
			scoreText:Hide()
			gamenumText:Hide()
            flag:Hide()
            ecocheatText:Hide()
            buildcheatText:Hide()
			healthcheatText:Hide()
			hxlmText:Hide()
            factionSelector:Hide()
            colorSelector:Hide()
            teamSelector:Hide()
            readyBox:Hide()
            pingGroup:Hide()
        end
        newSlot.HideControls()

        if singlePlayer then
            -- TODO: Use of groups may allow this to be simplified...
            readyBox:Hide()
            pingGroup:Hide()
            pingStatus:Hide()
        end

        if i == 1 then
            LayoutHelpers.Below(newSlot, GUI.labelGroup)
        else
            LayoutHelpers.Below(newSlot, GUI.slots[i - 1], 3)
        end

        GUI.slots[i] = newSlot
    end
end


-- create UI won't typically be called directly by another module
function CreateUI(maxPlayers)
    local Checkbox = import('/lua/maui/checkbox.lua').Checkbox
    local Text = import('/lua/maui/text.lua').Text
    local ResourceMapPreview = import('/lua/ui/controls/resmappreview.lua').ResourceMapPreview
    local MapPreview = import('/lua/ui/controls/mappreview.lua').MapPreview
    local MultiLineText = import('/lua/maui/multilinetext.lua').MultiLineText
    local EffectHelpers = import('/lua/maui/effecthelpers.lua')
    local ItemList = import('/lua/maui/itemlist.lua').ItemList
    local Prefs = import('/lua/user/prefs.lua')
    local Tooltip = import('/lua/ui/game/tooltip.lua')

    local isHost = lobbyComm:IsHost()
    local lastFaction = GetSanitisedLastFaction()
    UIUtil.SetCurrentSkin(FACTION_NAMES[lastFaction])

    ---------------------------------------------------------------------------
    -- Set up main control panels
    ---------------------------------------------------------------------------
    GUI.panel = Bitmap(GUI, UIUtil.SkinnableFile("/scx_menu/lan-game-lobby/lobby.dds"))
    LayoutHelpers.AtCenterIn(GUI.panel, GUI)
    GUI.panelWideLeft = Bitmap(GUI, UIUtil.SkinnableFile('/scx_menu/lan-game-lobby/wide.dds'))
    LayoutHelpers.CenteredLeftOf(GUI.panelWideLeft, GUI.panel)
    GUI.panelWideLeft.Left:Set(function() return GUI.Left() end)
    GUI.panelWideRight = Bitmap(GUI, UIUtil.SkinnableFile('/scx_menu/lan-game-lobby/wide.dds'))
    LayoutHelpers.CenteredRightOf(GUI.panelWideRight, GUI.panel)
    GUI.panelWideRight.Right:Set(function() return GUI.Right() end)

    -- Create a label with a given size and initial text
    local function makeLabel(text, size)
        return UIUtil.CreateText(GUI.panel, text, size, 'Arial Gras', true)
    end

    -- Map Name Label TODO: Localise!
    GUI.MapNameLabel = makeLabel("Loading...", 17)
    LayoutHelpers.AtRightTopIn(GUI.MapNameLabel, GUI.panel, 5, 45)

    -- Game Quality Label
    GUI.GameQualityLabel = makeLabel("", 11)
    LayoutHelpers.AtRightTopIn(GUI.GameQualityLabel, GUI.panel, 5, 64)

    -- Title Label
    GUI.titleText = makeLabel("FA联机联网", 17)
    LayoutHelpers.AtLeftTopIn(GUI.titleText, GUI.panel, 5, 20)
    
    -- Rule Label
    local RuleLabel = TextArea(GUI.panel, 350, 34)
    GUI.RuleLabel = RuleLabel
    RuleLabel:SetFont('Arial Gras', 11)
    RuleLabel:SetColors("B9BFB9", "00000000", "B9BFB9", "00000000")
    LayoutHelpers.AtLeftTopIn(RuleLabel, GUI.panel, 5, 44)
    RuleLabel:DeleteAllItems()
    local tmptext
    if isHost then
        tmptext = 'FA联机QQ群659797309'
        RuleLabel:SetColors("FFCC00")
    else
        tmptext = '新手联机教程、录像、MOD，请加QQ群659797309'
    end
    RuleLabel:SetText(tmptext)
    if isHost then
        RuleLabel.OnClick = function(self)
            ShowRuleDialog(RuleLabel)
        end
    end
	---------------------------------------------------------------------------
    -- set Observer
    ---------------------------------------------------------------------------
	if isHost and not singlePlayer then
		local Nober = UIUtil.CreateCheckbox(GUI.titleText, '/CHECKBOX/', '不许自行进入ob',true,11)
			LayoutHelpers.AtRightTopIn(Nober, GUI.titleText, -700, 20)
			Tooltip.AddCheckboxTooltip(Nober, {text='禁止新增观察员', body='选中以后除了主机选定或已经进入的观战员，其他人不准进入'})
			Nober.OnCheck = function(self, checked)
				if checked then
				allowobers = false
				else
				allowobers = true
				end
				lobbyComm:BroadcastData( { Type = 'SetObserver', Obdata = allowobers} )
		end
	end
	
    -- Mod Label
    GUI.ModFeaturedLabel = makeLabel("", 13)
    LayoutHelpers.AtLeftTopIn(GUI.ModFeaturedLabel, GUI.panel, 50, 61)

    -- Set the mod name to a value appropriate for the mod in use.
    local modLabels = {
        ["init_faf.lua"] = "FA Forever",
        ["init_blackops.lua"] = "BlackOps",
        ["init_coop.lua"] = "COOP",
        ["init_balancetesting.lua"] = "Balance Testing",
        ["init_gw.lua"] = "Galactic War",
        ["init_labwars.lua"] = "Labwars",
        ["init_ladder1v1.lua"] = "Ladder 1v1",
        ["init_nomads.lua"] = "Nomads Mod",
        ["init_phantomx.lua"] = "PhantomX",
        ["init_supremedestruction.lua"] = "SupremeDestruction",
        ["init_xtremewars.lua"] = "XtremeWars",

    }
    GUI.ModFeaturedLabel:StreamText(modLabels[argv.initName] or "", 20)

    -- Lobby options panel
    GUI.LobbyOptions = UIUtil.CreateButtonWithDropshadow(GUI.panel, '/BUTTON/medium/', "大厅设置")
    LayoutHelpers.AtRightTopIn(GUI.LobbyOptions, GUI.panel, 44, 3)
    GUI.LobbyOptions.OnClick = function()
        ShowLobbyOptionsDialog()
    end
    
    -- Logo
    GUI.logo = Bitmap(GUI, '/textures/ui/common/scx_menu/lan-game-lobby/logo.dds')
    LayoutHelpers.AtLeftTopIn(GUI.logo, GUI, 1, 1)
    

	    -- 新式版本管理器
    local bool ShowPatch = false
    GUI.gameVersionText = UIUtil.CreateText(GUI.panel, "FA" .. GameVersion(), 9, UIUtil.bodyFont)
    GUI.gameVersionText:SetColor('CCCCCC')
    GUI.gameVersionText:SetDropShadow(true)
    LayoutHelpers.AtLeftTopIn(GUI.gameVersionText, GUI.panel, 70, 3)
    GUI.gameVersionText.HandleEvent = function (self, event)
        if event.Type == 'MouseEnter' then
            self:SetColor('ffffff')
        elseif event.Type == 'MouseExit' then
            self:SetColor('677983')
        elseif event.Type == 'ButtonPress' then
            Changelog.CreateUI(GUI, true)
        end
    end
	

    -- Player Slots
    GUI.playerPanel = Group(GUI.panel, "playerPanel")
    LayoutHelpers.AtLeftTopIn(GUI.playerPanel, GUI.panel, 6, 70)
    GUI.playerPanel.Width:Set(706)
    GUI.playerPanel.Height:Set(307)

    -- Observer section
    GUI.observerPanel = Group(GUI.panel, "observerPanel")
    UIUtil.SurroundWithBorder(GUI.observerPanel, '/scx_menu/lan-game-lobby/frame/')

    -- Scale the observer panel according to the buttons we are showing.
    local obsOffset
    local obsHeight
    if isHost then
        obsHeight = 159
        obsOffset = 545
    else
        obsHeight = 206
        obsOffset = 503
    end
    LayoutHelpers.AtLeftTopIn(GUI.observerPanel, GUI.panel, 512, obsOffset)
    GUI.observerPanel.Width:Set(278)
    GUI.observerPanel.Height:Set(obsHeight)

    -- Chat
    GUI.chatPanel = Group(GUI.panel, "chatPanel")
    UIUtil.SurroundWithBorder(GUI.chatPanel, '/scx_menu/lan-game-lobby/frame/')
    LayoutHelpers.AtLeftTopIn(GUI.chatPanel, GUI.panel, 11, 459)
    GUI.chatPanel.Width:Set(478)
    GUI.chatPanel.Height:Set(245)

    -- Map Preview
    GUI.mapPanel = Group(GUI.panel, "mapPanel")
    UIUtil.SurroundWithBorder(GUI.mapPanel, '/scx_menu/lan-game-lobby/frame/')
    LayoutHelpers.AtLeftTopIn(GUI.mapPanel, GUI.panel, 813, 88)
    GUI.mapPanel.Width:Set(198)
    GUI.mapPanel.Height:Set(198)
    LayoutHelpers.DepthOverParent(GUI.mapPanel, GUI.panel, 2)

    GUI.optionsPanel = Group(GUI.panel, "optionsPanel") -- ORANGE Square in Screenshoot
    UIUtil.SurroundWithBorder(GUI.optionsPanel, '/scx_menu/lan-game-lobby/frame/')
    LayoutHelpers.AtLeftTopIn(GUI.optionsPanel, GUI.panel, 813, 325)
    GUI.optionsPanel.Width:Set(198)
    GUI.optionsPanel.Height:Set(337)
    LayoutHelpers.DepthOverParent(GUI.optionsPanel, GUI.panel, 2)

    ---------------------------------------------------------------------------
    -- set up map panel
    ---------------------------------------------------------------------------
    GUI.mapView = ResourceMapPreview(GUI.mapPanel, 200, 3, 5)
    LayoutHelpers.AtLeftTopIn(GUI.mapView, GUI.mapPanel, -1, -1)
    LayoutHelpers.DepthOverParent(GUI.mapView, GUI.mapPanel, -1)

    GUI.LargeMapPreview = UIUtil.CreateButtonWithDropshadow(GUI.mapPanel, '/BUTTON/zoom/', "")
    LayoutHelpers.AtRightIn(GUI.LargeMapPreview, GUI.mapPanel, -1)
    LayoutHelpers.AtBottomIn(GUI.LargeMapPreview, GUI.mapPanel, -1)
    LayoutHelpers.DepthOverParent(GUI.LargeMapPreview, GUI.mapPanel, 2)
    Tooltip.AddButtonTooltip(GUI.LargeMapPreview, 'lob_click_LargeMapPreview')
    GUI.LargeMapPreview.OnClick = function()
        CreateBigPreview(GUI)
    end

    -- Checkbox Show changed Options
    -- TODO: Localise!
    local cbox_ShowChangedOption = UIUtil.CreateCheckbox(GUI.optionsPanel, '/CHECKBOX/', '隐藏主机默认选项', true, 11)
    LayoutHelpers.AtLeftTopIn(cbox_ShowChangedOption, GUI.optionsPanel, 35, -32)

    Tooltip.AddCheckboxTooltip(cbox_ShowChangedOption, {text='隐藏主机默认选项', body='只显示主机更改的选项'})
    cbox_ShowChangedOption.OnCheck = function(self, checked)
        HideDefaultOptions = checked
        RefreshOptionDisplayData()
        GUI.OptionContainer.ScrollSetTop(GUI.OptionContainer, 'Vert', 0)
        Prefs.SetToCurrentProfile('LobbyHideDefaultOptions', tostring(checked))
    end

    -- GAME OPTIONS // MODS MANAGER BUTTON --
    if isHost then     -- GAME OPTION
        GUI.gameoptionsButton = UIUtil.CreateButtonWithDropshadow(GUI.optionsPanel, '/BUTTON/medium/', "<LOC _Options>")
        Tooltip.AddButtonTooltip(GUI.gameoptionsButton, 'lob_select_map')
        GUI.gameoptionsButton.OnClick = function(self)
            local mapSelectDialog

            autoRandMap = false
            local function selectBehavior(selectedScenario, changedOptions, restrictedCategories)
                local options = {}
                if autoRandMap then
                    options['ScenarioFile'] = selectedScenario.file
                else
                    mapSelectDialog:Destroy()
                    GUI.chatEdit:AcquireFocus()
                    for optionKey, data in changedOptions do
                        options[optionKey] = data.value
                    end
                    options['ScenarioFile'] = selectedScenario.file
                    options['RestrictedCategories'] = restrictedCategories

                    -- every new map, clear the flags, and clients will report if a new map is bad
                    ClearBadMapFlags()
                    HostUpdateMods()
                    SetGameOptions(options)
                end
            end

            local function exitBehavior()
                mapSelectDialog:Close()
                GUI.chatEdit:AcquireFocus()
                UpdateGame()
            end

            GUI.chatEdit:AbandonFocus()

            mapSelectDialog = import('/lua/ui/dialogs/mapselect.lua').CreateDialog(
                selectBehavior,
                exitBehavior,
                GUI,
                singlePlayer,
                gameInfo.GameOptions.ScenarioFile,
                gameInfo.GameOptions,
                availableMods,
                OnModsChanged
            )
        end
    else
        GUI.gameoptionsButton = UIUtil.CreateButtonWithDropshadow(GUI.optionsPanel, '/BUTTON/medium/', "Mod管理器")
        GUI.gameoptionsButton.OnClick = function(self, modifiers)
            import('/lua/ui/lobby/ModsManager.lua').NEW_MODS_GUI(GUI, false, gameInfo.GameMods)
        end
        Tooltip.AddButtonTooltip(GUI.gameoptionsButton, 'Lobby_Mods')
    end

    LayoutHelpers.AtBottomIn(GUI.gameoptionsButton, GUI.optionsPanel, -51)
    LayoutHelpers.AtHorizontalCenterIn(GUI.gameoptionsButton, GUI.optionsPanel, 1)

    ---------------------------------------------------------------------------
    -- set up chat display
    ---------------------------------------------------------------------------
    GUI.chatDisplay = TextArea(
        GUI.chatPanel,
        function() return GUI.chatPanel.Width() - 20 end,
        function() return GUI.chatPanel.Height() - GUI.chatBG.Height() - 2 end
    )
    GUI.chatDisplay:SetFont(UIUtil.bodyFont, tonumber(Prefs.GetFromCurrentProfile('LobbyChatFontSize')) or 14)
    LayoutHelpers.AtLeftTopIn(GUI.chatDisplay, GUI.chatPanel, 4, 2)

    -- Annoying evil extra Bitmap to make chat box have padding inside its background.
    local chatBG = Bitmap(GUI.chatPanel)
    GUI.chatBG = chatBG
    chatBG:SetSolidColor('FF212123')
    LayoutHelpers.Below(chatBG, GUI.chatDisplay, 1)
    LayoutHelpers.AtLeftIn(chatBG, GUI.chatDisplay, -5)
    chatBG.Width:Set(GUI.chatPanel.Width() - 16)
    chatBG.Height:Set(24)

    GUI.chatEdit = Edit(GUI.chatPanel)
    LayoutHelpers.AtLeftTopIn(GUI.chatEdit, GUI.chatBG, 4, 3)
    GUI.chatEdit.Width:Set(GUI.chatBG.Width() - 9)
    GUI.chatEdit.Height:Set(22)
    GUI.chatEdit:SetFont(UIUtil.bodyFont, 16)
    GUI.chatEdit:SetForegroundColor(UIUtil.fontColor)
    GUI.chatEdit:ShowBackground(false)
    GUI.chatEdit:SetDropShadow(true)
    GUI.chatEdit:AcquireFocus()

    GUI.chatDisplayScroll = UIUtil.CreateLobbyVertScrollbar(GUI.chatDisplay, 1, 24, -1)

    GUI.chatEdit:SetMaxChars(200)
    GUI.chatEdit.OnCharPressed = function(self, charcode)
        if charcode == UIUtil.VK_TAB then
            return true
        end

        local charLim = self:GetMaxChars()
        if STR_Utf8Len(self:GetText()) >= charLim then
            local sound = Sound({Cue = 'UI_Menu_Error_01', Bank = 'Interface',})
            PlaySound(sound)
        end
    end

    -- We work extremely hard to keep keyboard focus on the chat box, otherwise users can trigger
    -- in-game keybindings in the lobby.
    -- That would be very bad. We should probably instead just not assign those keybindings yet...
    GUI.chatEdit.OnLoseKeyboardFocus = function(self)
        GUI.chatEdit:AcquireFocus()
    end

    local commandQueueIndex = 0
    local commandQueue = {}
    GUI.chatEdit.OnEnterPressed = function(self, text)
        if text ~= "" then
            GpgNetSend('Chat', text)
            table.insert(commandQueue, 1, text)
            commandQueueIndex = 0
            if string.sub(text, 1, 1) == '/' then
                local spaceStart = string.find(text, " ") or string.len(text) + 1
                local comKey = string.sub(text, 2, spaceStart - 1)
                local params = string.sub(text, spaceStart + 1)
                local commandFunc = commands[string.lower(comKey)]
                if not commandFunc then
                    AddChatText(LOCF("<LOC lobui_0396>Command Not Known: %s", comKey))
                    return
                end

                commandFunc(params)
            else
                PublicChat(text)
            end
        end
    end

    --- Handle up/down arrow presses for the chat box.
    GUI.chatEdit.OnNonTextKeyPressed = function(self, keyCode)
        if AddUnicodeCharToEditText(self, keyCode) then
            return
        end
        if commandQueue and table.getsize(commandQueue) > 0 then
            if keyCode == 38 then
                if commandQueue[commandQueueIndex + 1] then
                    commandQueueIndex = commandQueueIndex + 1
                    self:SetText(commandQueue[commandQueueIndex])
                end
            end
            if keyCode == 40 then
                if commandQueueIndex ~= 1 then
                    if commandQueue[commandQueueIndex - 1] then
                        commandQueueIndex = commandQueueIndex - 1
                        self:SetText(commandQueue[commandQueueIndex])
                    end
                else
                    commandQueueIndex = 0
                    self:ClearText()
                end
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Option display
    ---------------------------------------------------------------------------
    GUI.OptionContainer = Group(GUI.optionsPanel)
    GUI.OptionContainer.Bottom:Set(function() return GUI.optionsPanel.Bottom() end)

    -- Leave space for the scrollbar.
    GUI.OptionContainer.Width:Set(function() return GUI.optionsPanel.Width() - 18 end)
    GUI.OptionContainer.top = 0
    LayoutHelpers.AtLeftTopIn(GUI.OptionContainer, GUI.optionsPanel, 1, 1)
    LayoutHelpers.DepthOverParent(GUI.OptionContainer, GUI.optionsPanel, -1)

    GUI.OptionDisplay = {}

    function CreateOptionElements()
        local function CreateElement(index)
            local element = Group(GUI.OptionContainer)

            element.bg = Bitmap(element)
            element.bg:SetSolidColor('ff333333')
            element.bg.Left:Set(element.Left)
            element.bg.Right:Set(element.Right)
            element.bg.Bottom:Set(function() return element.value.Bottom() + 2 end)
            element.bg.Top:Set(element.Top)

            element.bg2 = Bitmap(element)
            element.bg2:SetSolidColor('ff000000')
            element.bg2.Left:Set(function() return element.bg.Left() + 1 end)
            element.bg2.Right:Set(function() return element.bg.Right() - 1 end)
            element.bg2.Bottom:Set(function() return element.bg.Bottom() - 1 end)
            element.bg2.Top:Set(function() return element.value.Top() + 0 end)

            element.Height:Set(36)
            element.Width:Set(GUI.OptionContainer.Width)
            element:DisableHitTest()

            element.text = UIUtil.CreateText(element, '', 14, "Arial")
            element.text:SetColor(UIUtil.fontColor)
            element.text:DisableHitTest()
            LayoutHelpers.AtLeftTopIn(element.text, element, 5)

            element.value = UIUtil.CreateText(element, '', 14, "Arial")
            element.value:SetColor(UIUtil.fontOverColor)
            element.value:DisableHitTest()
            LayoutHelpers.AtRightTopIn(element.value, element, 5, 16)

            GUI.OptionDisplay[index] = element
        end

        CreateElement(1)
        LayoutHelpers.AtLeftTopIn(GUI.OptionDisplay[1], GUI.OptionContainer)

        local index = 2
        while index ~= 10 do
            CreateElement(index)
            LayoutHelpers.Below(GUI.OptionDisplay[index], GUI.OptionDisplay[index-1])
            index = index + 1
        end
    end
    CreateOptionElements()

    local numLines = function() return table.getsize(GUI.OptionDisplay) end

    local function DataSize()
        if HideDefaultOptions then
            return table.getn(nonDefaultFormattedOptions)
        else
            return table.getn(formattedOptions)
        end
    end

    -- called when the scrollbar for the control requires data to size itself
    -- GetScrollValues must return 4 values in this order:
    -- rangeMin, rangeMax, visibleMin, visibleMax
    -- aixs can be "Vert" or "Horz"
    GUI.OptionContainer.GetScrollValues = function(self, axis)
        local size = DataSize()
        --LOG(size, ":", self.top, ":", math.min(self.top + numLines, size))
        return 0, size, self.top, math.min(self.top + numLines(), size)
    end

    -- called when the scrollbar wants to scroll a specific number of lines (negative indicates scroll up)
    GUI.OptionContainer.ScrollLines = function(self, axis, delta)
        self:ScrollSetTop(axis, self.top + math.floor(delta))
    end

    -- called when the scrollbar wants to scroll a specific number of pages (negative indicates scroll up)
    GUI.OptionContainer.ScrollPages = function(self, axis, delta)
        self:ScrollSetTop(axis, self.top + math.floor(delta) * numLines())
    end

    -- called when the scrollbar wants to set a new visible top line
    GUI.OptionContainer.ScrollSetTop = function(self, axis, top)
        top = math.floor(top)
        if top == self.top then return end
        local size = DataSize()
        self.top = math.max(math.min(size - numLines() , top), 0)
        self:CalcVisible()
    end

    -- called to determine if the control is scrollable on a particular access. Must return true or false.
    GUI.OptionContainer.IsScrollable = function(self, axis)
        return true
    end
    -- determines what controls should be visible or not
    GUI.OptionContainer.CalcVisible = function(self)
        local function SetTextLine(line, data, lineID)
            if data.mod then
                -- The special label at the top stating the number of mods.
                line.text:SetColor('ffff7777')
                LayoutHelpers.AtHorizontalCenterIn(line.text, line, 5)
                LayoutHelpers.AtHorizontalCenterIn(line.value, line, 5, 16)
                LayoutHelpers.ResetRight(line.value)
            else
                -- Game options.
                line.text:SetColor(UIUtil.fontColor)
                LayoutHelpers.AtLeftTopIn(line.text, line, 5)
                LayoutHelpers.AtRightTopIn(line.value, line, 5, 16)
                LayoutHelpers.ResetLeft(line.value)
            end
            line.text:SetText(LOC(data.text))
            line.bg:Show()
            line.value:SetText(LOC(data.value))
            line.bg2:Show()
            line.bg.HandleEvent = Group.HandleEvent
            line.bg2.HandleEvent = Bitmap.HandleEvent
            if data.tooltip then
                Tooltip.AddControlTooltip(line.bg, data.tooltip)
                Tooltip.AddControlTooltip(line.bg2, data.valueTooltip)
            end
        end

        local optionsToUse
        if HideDefaultOptions then
            optionsToUse = nonDefaultFormattedOptions
        else
            optionsToUse = formattedOptions
        end

        for i, v in GUI.OptionDisplay do
            if optionsToUse[i + self.top] then
                SetTextLine(v, optionsToUse[i + self.top], i + self.top)
            else
                v.text:SetText('')
                v.value:SetText('')
                v.bg:Hide()
                v.bg2:Hide()
            end
        end
    end

    GUI.OptionContainer.HandleEvent = function(self, event)
        if event.Type == 'WheelRotation' then
            local lines = 1
            if event.WheelRotation > 0 then
                lines = -1
            end
            self:ScrollLines(nil, lines)
        end
    end

    RefreshOptionDisplayData()

    GUI.OptionContainerScroll = UIUtil.CreateLobbyVertScrollbar(GUI.OptionContainer, 2)
    LayoutHelpers.DepthOverParent(GUI.OptionContainerScroll, GUI.OptionContainer, 2)

    -- Launch Button
    local launchGameButton = UIUtil.CreateButtonWithDropshadow(GUI.chatPanel, '/BUTTON/large/', "传送！")
    GUI.launchGameButton = launchGameButton
    LayoutHelpers.AtHorizontalCenterIn(launchGameButton, GUI)
    LayoutHelpers.AtBottomIn(launchGameButton, GUI.panel, -8)
    Tooltip.AddButtonTooltip(launchGameButton, 'Lobby_Launch')
    UIUtil.setVisible(launchGameButton, isHost)
    launchGameButton.OnClick = function(self)
        TryLaunch(false)
    end

    -- Create skirmish mode's "load game" button.
    local loadButton = UIUtil.CreateButtonWithDropshadow(GUI.optionsPanel, '/BUTTON/medium/',"<LOC lobui_0176>Load")
    GUI.loadButton = loadButton
    UIUtil.setVisible(loadButton, singlePlayer)
    LayoutHelpers.LeftOf(loadButton, launchGameButton, 10)
    LayoutHelpers.AtVerticalCenterIn(loadButton, launchGameButton)
    loadButton.OnClick = function(self, modifiers)
        import('/lua/ui/dialogs/saveload.lua').CreateLoadDialog(GUI)
    end
    Tooltip.AddButtonTooltip(loadButton, 'Lobby_Load')

    -- Create the "Lobby presets" button for the host. If not the host, the same field is occupied
    -- instead by the read-only "Unit Manager" button.
    GUI.restrictedUnitsOrPresetsBtn = UIUtil.CreateButtonWithDropshadow(GUI.optionsPanel, '/BUTTON/medium/', "设置保存")

    if singlePlayer then
        GUI.restrictedUnitsOrPresetsBtn:Hide()
    elseif isHost then
        -- TODO: Localise!
        GUI.restrictedUnitsOrPresetsBtn.label:SetText("保存模板")
        GUI.restrictedUnitsOrPresetsBtn.OnClick = function(self, modifiers)
            ShowPresetDialog()
        end
        -- TODO: Localise!
        Tooltip.AddButtonTooltip(GUI.restrictedUnitsOrPresetsBtn, 'Lobby_presetDescription')
    else
        -- TODO: Localise!
        GUI.restrictedUnitsOrPresetsBtn.label:SetText("单位管理器")
        GUI.restrictedUnitsOrPresetsBtn.OnClick = function(self, modifiers)
            import('/lua/ui/lobby/restrictedUnitsDlg.lua').CreateDialog(GUI.panel, gameInfo.GameOptions.RestrictedCategories, function() end, function() end, false)
        end
        Tooltip.AddButtonTooltip(GUI.restrictedUnitsOrPresetsBtn, 'lob_RestrictedUnitsClient')
    end
    LayoutHelpers.AtHorizontalCenterIn(GUI.restrictedUnitsOrPresetsBtn, GUI.gameoptionsButton)
    LayoutHelpers.Below(GUI.restrictedUnitsOrPresetsBtn, GUI.gameoptionsButton, 9)

    ---------------------------------------------------------------------------
    -- Checkbox Show changed Options
    ---------------------------------------------------------------------------
    cbox_ShowChangedOption:SetCheck(HideDefaultOptions, false)

    ---------------------------------------------------------------------------
    -- set up : player grid
    ---------------------------------------------------------------------------

    -- For disgusting reasons, we pass the label factory as a parameter.
    CreateSlotsUI(makeLabel)

    -- Exit Button
    GUI.exitButton = UIUtil.CreateButtonWithDropshadow(GUI.chatPanel, '/BUTTON/medium/','Exit')
    GUI.exitButton.label:SetText(LOC("<LOC _Exit>"))
    LayoutHelpers.AtLeftIn(GUI.exitButton, GUI.chatPanel, 33)
    LayoutHelpers.AtVerticalCenterIn(GUI.exitButton, launchGameButton, 7)
    GUI.exitButton.OnClick = GUI.exitLobbyEscapeHandler
    
			    -- 单位数据库链接
	if not singlePlayer then
    GUI.gameUnitdb = UIUtil.CreateText(GUI.panel, "浏览FA单位数据库", 12, UIUtil.bodyFont)
    GUI.gameUnitdb:SetColor('cccccc')
    GUI.gameUnitdb:SetDropShadow(true)
	LayoutHelpers.AtLeftIn(GUI.gameUnitdb, GUI.chatPanel, 205)
    LayoutHelpers.AtVerticalCenterIn(GUI.gameUnitdb, launchGameButton, -5)
    GUI.gameUnitdb.HandleEvent = function (self, event)
        if event.Type == 'MouseEnter' then
            self:SetColor('0000FF')
        elseif event.Type == 'MouseExit' then
            self:SetColor('cccccc')
        elseif event.Type == 'ButtonPress' then
            OpenURL('http://fa.mfency.cn:980/replay/unit')
        end
		end
	end
    -- Small buttons are 100 wide, 44 tall
    
    -- Default option button
    GUI.defaultOptions = UIUtil.CreateButtonStd(GUI.observerPanel, '/BUTTON/defaultoption/')
    -- If we're the host, position the buttons lower down (and eventually shrink the observer panel)
    if not isHost then
        GUI.defaultOptions:Hide()
    end
    LayoutHelpers.AtLeftTopIn(GUI.defaultOptions, GUI.observerPanel, 11, -94)

    Tooltip.AddButtonTooltip(GUI.defaultOptions, 'lob_click_rankedoptions')
    if not isHost then
        GUI.defaultOptions:Disable()
    else
        GUI.defaultOptions.OnClick = function()
            -- Return all options to their default values.
            OptionUtils.SetDefaults()
            lobbyComm:BroadcastData( { Type = "SetAllPlayerNotReady" } )
            UpdateGame()
        end
    end

    -- RANDOM MAP BUTTON --
    GUI.randMap = UIUtil.CreateButtonStd(GUI.observerPanel, '/BUTTON/randommap/')
    LayoutHelpers.RightOf(GUI.randMap, GUI.defaultOptions, -19)
    Tooltip.AddButtonTooltip(GUI.randMap, 'lob_click_randmap')
    if not isHost then
        GUI.randMap:Hide()
    else
        GUI.randMap.OnClick = function()
            local randomMap
            local mapSelectDialog

            autoRandMap = false

            -- Load the set of all available maps, with a slight evil hack on the mapselect module.
            local mapDialog = import('/lua/ui/dialogs/mapselect.lua')
            local allMaps = mapDialog.LoadScenarios()  -- Result will be cached.

            -- Only include maps which have enough slots for the players we have.
            local filteredMaps = table.filter(allMaps,
                function(scenInfo)
                    local supportedPlayers = table.getsize(scenInfo.Configurations.standard.teams[1].armies)
                    return supportedPlayers >= GetPlayerCount()
                end
            )
            local mapCount = table.getn(filteredMaps)
            local selectedMap = filteredMaps[math.floor(math.random(1, mapCount))]

            -- Set the new map.
            SetGameOption('ScenarioFile', selectedMap.file)
            ClearBadMapFlags()
            UpdateGame()
        end
    end

    local autoteamButtonStates = {
        {
            key = 'tvsb',
            tooltip = 'lob_auto_tvsb'
        },
        {
            key = 'lvsr',
            tooltip = 'lob_auto_lvsr'
        },
        {
            key = 'pvsi',
            tooltip = 'lob_auto_pvsi'
        },
        {
            key = 'manual',
            tooltip = 'lob_auto_manual'
        },
        {
            key = 'none',
            tooltip = 'lob_auto_none'
        },
    }

    local initialState = Prefs.GetFromCurrentProfile("LobbyOpt_AutoTeams") or "none"
    GUI.autoTeams = ToggleButton(GUI.observerPanel, '/BUTTON/autoteam/', autoteamButtonStates, initialState)

    LayoutHelpers.RightOf(GUI.autoTeams, GUI.randMap, -19)
    if not isHost then
        GUI.autoTeams:Hide()
    else
        GUI.autoTeams.OnStateChanged = function(self, newState)
            SetGameOption('AutoTeams', newState)
            AssignAutoTeams()
        end
    end
	
	 -- CLOSE/OPEN EMPTY SLOTS BUTTON --
    GUI.closeEmptySlots = UIUtil.CreateButtonStd(GUI.observerPanel, '/BUTTON/closeslots/')
    LayoutHelpers.AtLeftTopIn(GUI.closeEmptySlots, GUI.defaultOptions, 0, 47)
    Tooltip.AddButtonTooltip(GUI.closeEmptySlots, 'lob_close_empty_slots')
    if not isHost then
        GUI.closeEmptySlots:Hide()
        LayoutHelpers.AtLeftTopIn(GUI.closeEmptySlots, GUI.defaultOptions, -40, 47)
    else
        GUI.closeEmptySlots.OnClick = function(self, modifiers)
            if lobbyComm:IsHost() then
                if modifiers.Ctrl then
                    for slot = 1,numOpenSlots do
                        HostSetSlotClosed(slot, false)
                    end
                    return
                end
                local openSpot = false
                for slot = 1,numOpenSlots do
                    openSpot = openSpot or not (gameInfo.PlayerOptions[slot] or gameInfo.ClosedSlots[slot])
                end
                if modifiers.Right and gameInfo.AdaptiveMap then
                    for slot = 1,numOpenSlots do
                        if openSpot then
                            if not (gameInfo.PlayerOptions[slot] or gameInfo.ClosedSlots[slot]) then
                                SetSlotClosedSpawnMex(slot)
                            end
                        else
                            if gameInfo.ClosedSlots[slot] and gameInfo.SpawnMex[slot] then
                                HostSetSlotClosed(slot, false)
                            end
                        end
                    end
                else
                    for slot = 1,numOpenSlots do
                        if not gameInfo.SpawnMex[slot] then
                            HostSetSlotClosed(slot, openSpot)
                        end
                    end
                end
            end
        end
    end
    
    -- GO OBSERVER BUTTON --

    GUI.becomeObserver = UIUtil.CreateButtonStd(GUI.observerPanel, '/BUTTON/observer/')
    LayoutHelpers.RightOf(GUI.becomeObserver, GUI.closeEmptySlots, -19)
    Tooltip.AddButtonTooltip(GUI.becomeObserver, 'lob_become_observer')
    GUI.becomeObserver.OnClick = function()
        if IsPlayer(localPlayerID) then
            if isHost then
                HostConvertPlayerToObserver(hostID, FindSlotForID(localPlayerID))
            elseif allowobers then
					lobbyComm:SendData(hostID, {Type = 'RequestConvertToObserver', RequestedSlot = FindSlotForID(localPlayerID)})
			else 
				    UIUtil.QuickDialog(GUI, "<LOC lobui_nober>Host has not allow you to join observers.","<LOC _Yes>", nil,"<LOC _Cancel>", nil,nil, nil,true,{worldCover = false, enterButton = 1, escapeButton = 2})
			end
        elseif IsObserver(localPlayerID) then
            if isHost then
                HostConvertObserverToPlayer(hostID, FindObserverSlotForID(localPlayerID))
            else
                lobbyComm:SendData(hostID, {Type = 'RequestConvertToPlayer', ObserverSlot = FindObserverSlotForID(localPlayerID)})
            end
        end
    end

    -- CPU BENCH BUTTON --
    GUI.rerunBenchmark = UIUtil.CreateButtonStd(GUI.observerPanel, '/BUTTON/cputest/', '', 11)
    LayoutHelpers.RightOf(GUI.rerunBenchmark, GUI.becomeObserver, -20)
    Tooltip.AddButtonTooltip(GUI.rerunBenchmark,{text='运行基准测试', body='重新计算你的CPU评级'})

    -- Observer List
    GUI.observerList = ItemList(GUI.observerPanel, "observer list")
    GUI.observerList:SetFont(UIUtil.bodyFont, 12)
    GUI.observerList:SetColors(UIUtil.fontColor, "00000000", UIUtil.fontOverColor, UIUtil.highlightColor, "ffbcfffe")
    GUI.observerList.Left:Set(function() return GUI.observerPanel.Left() + 4 end)
    GUI.observerList.Bottom:Set(function() return GUI.observerPanel.Bottom() end)
    GUI.observerList.Top:Set(function() return GUI.observerPanel.Top() + 2 end)
    GUI.observerList.Right:Set(function() return GUI.observerPanel.Right() - 15 end)
    GUI.observerList.OnClick = function(self, row, event)
        if isHost and event.Modifiers.Right then
            UIUtil.QuickDialog(GUI, "<LOC lobui_0166>Are you sure?",
                                    "<LOC lobui_0167>Kick Player", function()
                                        lobbyComm:EjectPeer(gameInfo.Observers[row+1].OwnerID, "KickedByHost")
                                    end,
                                    "<LOC _Cancel>", nil,
                                    nil, nil,
                                    true,
                                    {worldCover = false, enterButton = 1, escapeButton = 2}
            )
        end
		if isHost and event.Modifiers.Left then
		
            UIUtil.QuickDialog(GUI, "<LOC lobui_obtopl>Are you sure?",
                                    "<LOC lobui_obtopl1>Ob to player", function()
										HostConvertObserverToPlayer(gameInfo.Observers[row+1].OwnerID, FindObserverSlotForID(gameInfo.Observers[row+1].OwnerID))
                                    end,
                                    "<LOC _Cancel>", nil,
                                    nil, nil,
                                    true,
                                    {worldCover = false, enterButton = 1, escapeButton = 2}
            )
        end
    end
    UIUtil.CreateLobbyVertScrollbar(GUI.observerList, 0, 0, -1)

    if singlePlayer then
        -- observers are always allowed in skirmish games.
        SetGameOption("AllowObservers",true)
        -- Hide all the multiplayer-only UI elements (we still create them because then we get to
        -- mostly forget that we're in single-player mode everywhere else (stuff silently becomes a
        -- nop, instead of needing to keep checking if UI controls actually exist...
		GUI.closeEmptySlots:Hide()
        GUI.becomeObserver:Hide()
        GUI.autoTeams:Hide()
        GUI.defaultOptions:Hide()
        GUI.rerunBenchmark:Hide()
        GUI.randMap:Hide()
        GUI.observerPanel:Hide()
    end

    -- Setup large pretty faction selector and set the factional background to its initial value.
    local lastFaction = GetSanitisedLastFaction()
    CreateUI_Faction_Selector(lastFaction)

    RefreshLobbyBackground(lastFaction)

    ---------------------------------------------------------------------------
    -- other logic, including lobby callbacks
    ---------------------------------------------------------------------------
    GUI.posGroup = false
    -- get ping times
    GUI.pingThread = ForkThread(
    function()
        while lobbyComm do
            for slot, player in gameInfo.PlayerOptions:pairs() do
                if player.Human and player.OwnerID ~= localPlayerID then
                    local peer = lobbyComm:GetPeer(player.OwnerID)
                    local ping = peer.ping
                    local connectionStatus = CalcConnectionStatus(peer)
					
                    if ping then
                        ping = math.floor(peer.ping)
                        GUI.slots[slot].pingStatus:SetValue(ping)
						GUI.slots[slot].pingStatus:Show()
                        --UIUtil.setEnabled(GUI.slots[slot].pingStatus, ping >= 500)

                        -- Set the ping bar to a colour representing the status of our connection.
						if (ping <= 150) then
                        GUI.slots[slot].pingStatus._bar:SetTexture(UIUtil.SkinnableFile('/game/unit_bmp/bar-02_bmp.dds'))
						elseif (ping > 150 and ping < 300) then
						GUI.slots[slot].pingStatus._bar:SetTexture(UIUtil.SkinnableFile('/game/unit_bmp/bar-01_bmp.dds'))
						elseif (ping >= 300) then
						GUI.slots[slot].pingStatus._bar:SetTexture(UIUtil.SkinnableFile('/game/unit_bmp/bar-03_bmp.dds'))
						else
						GUI.slots[slot].pingStatus._bar:SetTexture(UIUtil.SkinnableFile('/game/unit_bmp/bar-03_bmp.dds'))
						end
						
						
						
						

                    else
                        GUI.slots[slot].pingStatus:Hide()
                    end
                end
            end
            WaitSeconds(1)
        end
    end)

    if not singlePlayer then
        CreateCPUMetricUI()
        ForkThread(function() UpdateBenchmark() end)
    end

    GUI.uiCreated = true
end

function RefreshOptionDisplayData(scenarioInfo)
    local globalOpts = import('/lua/ui/lobby/lobbyOptions.lua').globalOpts
    local teamOptions = import('/lua/ui/lobby/lobbyOptions.lua').teamOptions
    local AIOpts = import('/lua/ui/lobby/lobbyOptions.lua').AIOpts
    if not scenarioInfo and gameInfo.GameOptions.ScenarioFile and (gameInfo.GameOptions.ScenarioFile ~= "") then
        scenarioInfo = MapUtil.LoadScenario(gameInfo.GameOptions.ScenarioFile)
    end
    formattedOptions = {}
    nonDefaultFormattedOptions = {}

    --// Check Mod active
    local modStr = false
    local modNum = table.getn(Mods.GetGameMods(gameInfo.GameMods)) or 0
    local modNumUI = table.getn(Mods.GetUiMods()) or 0
    if modNum > 0 and modNumUI > 0 then
        modStr = modNum..' Mods (and '..modNumUI..' UI Mods)'
        if modNum == 1 and modNumUI > 1 then
            modStr = modNum..' Mod (and '..modNumUI..' UI Mods)'
        elseif modNum > 1 and modNumUI == 1 then
            modStr = modNum..' Mods (and '..modNumUI..' UI Mod)'
        elseif modNum == 1 and modNumUI == 1 then
            modStr = modNum..' Mod (and '..modNumUI..' UI Mod)'
        else
            modStr = modNum..' Mods (and '..modNumUI..' UI Mods)'
        end
    elseif modNum > 0 and modNumUI == 0 then
        modStr = modNum..' Mods'
        if modNum == 1 then
            modStr = modNum..' Mod'
        end
    elseif modNum == 0 and modNumUI > 0 then
        modStr = modNumUI..' UI Mods'
        if modNum == 1 then
            modStr = modNumUI..' UI Mod'
        end
    end
    if modStr then
        local option = {
            text = modStr,
            value = LOC('<LOC lobby_0003>Check Mod Manager'),
            mod = true,
            tooltip = 'Lobby_Mod_Option',
            valueTooltip = 'Lobby_Mod_Option'
        }

        table.insert(formattedOptions, option)
        table.insert(nonDefaultFormattedOptions, option)
    end
    --\\ Stop Check Mod active

    -- Update the unit restrictions display.
    if gameInfo.GameOptions.RestrictedCategories ~= nil then
        local restrNum = table.getn(gameInfo.GameOptions.RestrictedCategories)
        if restrNum ~= 0 then
            -- TODO: Localise label.
            local restrictLabel
            if restrNum == 1 then -- just 1
                restrictLabel = "1 Build Restriction"
            else
                restrictLabel = restrNum.." Build Restrictions"
            end

            local option = {
                text = restrictLabel,
                value = "Check Unit Manager",
                mod = true,
                tooltip = 'Lobby_BuildRestrict_Option',
                valueTooltip = 'Lobby_BuildRestrict_Option'
            }

            table.insert(formattedOptions, option)
            table.insert(nonDefaultFormattedOptions, option)
        end
    end

    -- Add an option to the formattedOption lists
    local function addFormattedOption(optData, gameOption)
        -- Don't show multiplayer-only options in single-player
        if optData.mponly and singlePlayer then
            return
        end

        local option = {
            text = optData.label,
            tooltip = { text = optData.label, body = optData.help }
        }

        -- Options are stored as keys from the values array in optData. We want to display the
        -- descriptive string in the UI, so let's go dig it out.

        -- Scan the values array to find the one with the key matching our value for that option.
        for k, val in optData.values do
            if val.key == gameOption then
                option.value = val.text
                option.valueTooltip = {text = optData.label, body = val.help }

                table.insert(formattedOptions, option)

                -- Add this option to the non-default set for the UI.
                if k ~= optData.default then
                    table.insert(nonDefaultFormattedOptions, option)
                end

                break
            end
        end
    end
--[[ 
    -- Add options from globalOpts to the formattedOption lists.
    for index, optData in globalOpts do
        local gameOption = gameInfo.GameOptions[optData.key]
        addFormattedOption(optData, gameOption)
    end
--]] 
    local function addOptionsFrom(optionObject)
        for index, optData in optionObject do
            local gameOption = gameInfo.GameOptions[optData.key]
            addFormattedOption(optData, gameOption)
        end
    end

    -- Add the core options to the formatted option lists
    addOptionsFrom(globalOpts)
    addOptionsFrom(teamOptions)
    addOptionsFrom(AIOpts)

    -- Add options from the scenario object, if any are provided.
    if scenarioInfo.options then
        if not MapUtil.ValidateScenarioOptions(scenarioInfo.options, true) then
            AddChatText('The options included in this map specified invalid defaults. See moholog for details.')
            AddChatText('An arbitrary option has been selected for now: check the game options screen!')
        end

        for index, optData in scenarioInfo.options do
            addFormattedOption(optData, gameInfo.GameOptions[optData.key])
        end
    end

    GUI.OptionContainer:CalcVisible()
end

function wasConnected(peer)
    for _,v in pairs(connectedTo) do
        if v == peer then
            return true
        end
    end
    return false
end

--- Return a status code representing the status of our connection to a peer.
-- @param peer, native table as returned by lobbyComm:GetPeer()
-- @return A value describing the connectivity to given peer.
-- 1 means no connectivity, 2 means they haven't reported that they can talk to us, 3 means
--
-- @todo: This function has side effects despite the naming suggesting that it shouldn't.
--        These need to go away.
function CalcConnectionStatus(peer)
    if peer.status ~= 'Established' then
        return 1
    else
        if not wasConnected(peer.id) then
            local peerSlot = FindSlotForID(peer.id)
            GUI.slots[peerSlot].name:SetTitleText(peer.name)
            GUI.slots[peerSlot].name._text:SetFont('Arial Gras', 15)
            if not table.find(ConnectionEstablished, peer.name) then
                if gameInfo.PlayerOptions[peerSlot].Human and not IsLocallyOwned(peerSlot) then
                    if table.find(ConnectedWithProxy, peer.id) then
                        AddChatText(LOCF("<LOC Engine0032>Connected to %s via the FAF proxy.", peer.name), "Engine0032")
                    end
                    table.insert(ConnectionEstablished, peer.name)
                    for k, v in CurrentConnection do -- Remove PlayerName in this Table
                        if v == peer.name then
                            CurrentConnection[k] = nil
                            break
                        end
                    end
                end
            end
		
            table.insert(connectedTo, peer.id)
            GpgNetSend('Connected', string.format("%d", peer.id))
			refreshPlayerLog()
        end
        if not table.find(peer.establishedPeers, lobbyComm:GetLocalPlayerID()) then
            -- they haven't reported that they can talk to us?
            return 2
        end

        local peers = lobbyComm:GetPeers()
        for k,v in peers do
            if v.id ~= peer.id and v.status == 'Established' then
                if not table.find(peer.establishedPeers, v.id) then
                    -- they can't talk to someone we can talk to.
                    return 2
                end
            end
        end
        return 3
    end
end

function EveryoneHasEstablishedConnections()
    local important = {}
    for slot,player in gameInfo.PlayerOptions:pairs() do
        if not table.find(important, player.OwnerID) then
            table.insert(important, player.OwnerID)
        end
    end
    for slot,observer in gameInfo.Observers:pairs() do
        if not table.find(important, observer.OwnerID) then
            table.insert(important, observer.OwnerID)
        end
    end
    local result = true
    for k,id in important do
        if id ~= localPlayerID then
        local peer = lobbyComm:GetPeer(id)
        for k2,other in important do
            if id ~= other and not table.find(peer.establishedPeers, other) then
                result = false
                AddChatText(LOCF("<LOC lobui_0299>%s doesn't have an established connection to %s",
                                 peer.name,
                                 lobbyComm:GetPeer(other).name
                ))
            end
        end
    end
end
return result
end

function AddChatText(text)
    if not GUI.chatDisplay then
        #LOG("Can't add chat text -- no chat display")
        #LOG("text=" .. repr(text))
        return
    end

    GUI.chatDisplay:AppendLine(text)
    GUI.chatDisplay:ScrollToBottom()
end

--- Update a slot display in a single map control.
function RefreshMapPosition(mapCtrl, slotIndex)

    local playerInfo = gameInfo.PlayerOptions[slotIndex]
	

    -- Evil autoteams voodoo.
    if gameInfo.GameOptions.AutoTeams and not gameInfo.AutoTeams[slotIndex] and lobbyComm:IsHost() then
        gameInfo.AutoTeams[slotIndex] = 2
    end

    -- The ACUButton instance representing this slot, if any.
    local marker = mapCtrl.startPositions[slotIndex]
    if marker then
        marker:SetClosed(gameInfo.ClosedSlots[slotIndex])
    end

    -- Nothing more for us to do for a closed or missing slot.
    if gameInfo.ClosedSlots[slotIndex] or not marker then
        return
    end

    if gameInfo.GameOptions['TeamSpawn'] ~= 'fixed' then
        marker:SetColor("00777777")
    else
        -- If spawns are fixed, show the colour/team of the person in this slot.
        if playerInfo then
            marker:SetColor(gameColors.PlayerColors[playerInfo.PlayerColor])
            marker:SetTeam(playerInfo.Team)
        else
            marker:Clear()
        end
    end

    if gameInfo.GameOptions.AutoTeams then
        if gameInfo.GameOptions.AutoTeams == 'lvsr' then
            local midLine = mapCtrl.Left() + (mapCtrl.Width() / 2)
            if gameInfo.GameOptions['TeamSpawn'] ~= 'fixed' then
                local markerPos = marker.Left()
                if markerPos < midLine then
                    marker:SetTeam(2)
                else
                    marker:SetTeam(3)
                end
            end
        elseif gameInfo.GameOptions.AutoTeams == 'tvsb' then
            local midLine = mapCtrl.Top() + (mapCtrl.Height() / 2)
            if gameInfo.GameOptions['TeamSpawn'] ~= 'fixed' then
                local markerPos = marker.Top()
                if markerPos < midLine then
                    marker:SetTeam(2)
                else
                    marker:SetTeam(3)
                end
            end
        elseif gameInfo.GameOptions.AutoTeams == 'pvsi' then
            if gameInfo.GameOptions['TeamSpawn'] ~= 'fixed' then
                if math.mod(slotIndex, 2) ~= 0 then
                    marker:SetTeam(2)
                else
                    marker:SetTeam(3)
                end
            end
        elseif gameInfo.GameOptions.AutoTeams == 'manual' and gameInfo.GameOptions['TeamSpawn'] ~= 'fixed' then
            marker:SetTeam(gameInfo.AutoTeams[slotIndex] or 1)
        end
    end
end

--- Update a single slot in all displayed map controls.
function RefreshMapPositionForAllControls(slot)
    RefreshMapPosition(GUI.mapView, slot)
    if LrgMap and not LrgMap.isHidden then
        RefreshMapPosition(LrgMap.content.mapPreview, slot)
    end
end

function ShowMapPositions(mapCtrl, scenario)
    local playerArmyArray = MapUtil.GetArmies(scenario)

    for inSlot, army in playerArmyArray do
        RefreshMapPosition(mapCtrl, inSlot)
    end
end

function ConfigureMapListeners(mapCtrl, scenario)
    local playerArmyArray = MapUtil.GetArmies(scenario)

    for inSlot, army in playerArmyArray do
        local slot = inSlot -- Closure copy.

        -- The ACUButton instance representing this slot.
        local marker = mapCtrl.startPositions[inSlot]

        marker.OnClick = function(self)
            if gameInfo.GameOptions['TeamSpawn'] == 'fixed' then
                if FindSlotForID(localPlayerID) ~= slot and gameInfo.PlayerOptions[slot] == nil then
                    if IsPlayer(localPlayerID) then
                        if lobbyComm:IsHost() then
                            HostTryMovePlayer(hostID, FindSlotForID(localPlayerID), slot)
                        else
                            lobbyComm:SendData(hostID, {Type = 'MovePlayer', CurrentSlot = FindSlotForID(localPlayerID), RequestedSlot = slot})
                        end
                    elseif IsObserver(localPlayerID) then
                        if lobbyComm:IsHost() then
                            local requestedFaction = GetSanitisedLastFaction()
                            HostConvertObserverToPlayer(hostID, FindObserverSlotForID(localPlayerID), slot)
                        else
                            lobbyComm:SendData(
                                hostID,
                                {
                                    Type = 'RequestConvertToPlayer',
                                    ObserverSlot = FindObserverSlotForID(localPlayerID),
                                    PlayerSlot = slot
                                }
                            )
                        end
                    end
                end
            else
                if gameInfo.GameOptions.AutoTeams and lobbyComm:IsHost() then
                    -- Handle the manual-mode reassignment of slots to teams.
                    if gameInfo.GameOptions.AutoTeams == 'manual' then
                        if not gameInfo.ClosedSlots[slot] and (gameInfo.PlayerOptions[slot] or gameInfo.GameOptions['TeamSpawn'] ~= 'fixed') then
                            local targetTeam
                            if gameInfo.AutoTeams[slot] == 7 then
                                -- 2 here corresponds to team 1, since a team value of 1 represents
                                -- "no team". Apparently GPG really, really didn't like zero.
                                targetTeam = 2
                            else
                                targetTeam = gameInfo.AutoTeams[slot] + 1
                            end

                            marker:SetTeam(targetTeam)
                            gameInfo.AutoTeams[slot] = targetTeam

                            lobbyComm:BroadcastData(
                                {
                                    Type = 'AutoTeams',
                                    Slots = slot,
                                    Team = gameInfo.AutoTeams[slot],
                                }
                            )
                            UpdateGame()
                        end
                    end
                end
            end
        end

        if lobbyComm:IsHost() then
            marker.OnRightClick = function(self)
                HostSetSlotClosed(slot, not gameInfo.ClosedSlots[slot])
            end
        end
    end
end

--function GetOL()
--	return argv.onlinecheck
--end

function SendCompleteGameStateToPeer(peerId)
    lobbyComm:SendData(peerId, {Type = 'GameInfo', GameInfo = GameInfo.Flatten(gameInfo)})
end

-- LobbyComm Callbacks
function InitLobbyComm(protocol, localPort, desiredPlayerName, localPlayerUID, natTraversalProvider)
    lobbyComm = LobbyComm.CreateLobbyComm(protocol, localPort, desiredPlayerName, localPlayerUID, natTraversalProvider)

    if not lobbyComm then
        error('Failed to create lobby using port ' .. tostring(localPort))
    end

    lobbyComm.ConnectionFailed = function(self, reason)
        #LOG("CONNECTION FAILED " .. reason)
        GUI.connectionFailedDialog = UIUtil.ShowInfoDialog(GUI.panel, LOCF(Strings.ConnectionFailed, Strings[reason] or reason),
                                                           "<LOC _OK>", ReturnToMenu)

        lobbyComm:Destroy()
        lobbyComm = nil
    end

    lobbyComm.LaunchFailed = function(self,reasonKey)
        AddChatText(LOC(Strings[reasonKey] or reasonKey))
    end

    lobbyComm.Ejected = function(self,reason)
        #LOG("EJECTED " .. reason)

        GUI.connectionFailedDialog = UIUtil.ShowInfoDialog(GUI, LOCF(Strings.Ejected, Strings[reason] or reason), "<LOC _OK>", ReturnToMenu)
        lobbyComm:Destroy()
        lobbyComm = nil
    end

    lobbyComm.ConnectionToHostEstablished = function(self,myID,myName,theHostID)
        #LOG("CONNECTED TO HOST")
        hostID = theHostID
        localPlayerID = myID
        localPlayerName = myName

        GpgNetSend('connectedToHost', string.format("%d", hostID))
        lobbyComm:SendData(hostID, { Type = 'SetAvailableMods', Mods = GetLocallyAvailableMods(), Name = localPlayerName} )
        lobbyComm:SendData(hostID, { Type = 'GameVersion', Vers = GameVersion(), Name = localPlayerName} )
        lobbyComm:SendData(hostID,
            {
                Type = 'AddPlayer',
                PlayerOptions = GetLocalPlayerData():AsTable()
            }
        )

        local function KeepAliveThreadFunc()
            local threshold = LobbyComm.quietTimeout
            local active = true
            local prev = 0
            while lobbyComm do
                local host = lobbyComm:GetPeer(hostID)
                if active and host.quiet > threshold then
                    active = false
                    local function OnRetry()
                        host = lobbyComm:GetPeer(hostID)
                        threshold = host.quiet + LobbyComm.quietTimeout
                        active = true
                    end
                    UIUtil.QuickDialog(GUI, "<LOC lobui_0266>Connection to host timed out.",
                      


                      "<LOC lobui_0267>Keep Trying", OnRetry,
                                            "<LOC lobui_0268>Give Up", ReturnToMenu,
                                            nil, nil,
                                            true,
                                            {worldCover = false, escapeButton = 2})
                elseif host.quiet < prev then
                    threshold = LobbyComm.quietTimeout
                end
                prev = host.quiet
                WaitSeconds(1)
            end
        end -- KeepAliveThreadFunc

        GUI.keepAliveThread = ForkThread(KeepAliveThreadFunc)
        CreateUI(LobbyComm.maxPlayerSlots)
    end

    lobbyComm.DataReceived = function(self,data)
        -- Messages anyone can receive
        if data.Type == 'PlayerOptions' then
            local options = data.Options
            local isHost = lobbyComm:IsHost()
            for key, val in options do
                -- The host *is* allowed to set options on slots he doesn't own, of course.
                if data.SenderID ~= hostID then
                    if key == 'Team' and gameInfo.GameOptions['AutoTeams'] ~= 'none' then
                        WARN("Attempt to set Team while Auto Teams are on.")
                        return
                    elseif gameInfo.PlayerOptions[data.Slot].OwnerID ~= data.SenderID then
                        WARN("Attempt to set option on unowned slot.")
                        return
                    end
                end

                gameInfo.PlayerOptions[data.Slot][key] = val
                if isHost then
                    GpgNetSend('PlayerOption', data.Slot, key, val)

                    -- TODO: This should be a global listener on PlayerData objects, but I'm in too
                    -- much pain to implement that listener system right now. EVIL HACK TIME
                    if key == "Ready" then
                        HostRefreshButtonEnabledness()
                    end
                    -- DONE.
                end
            end
			
			
            SetSlotInfo(data.Slot, gameInfo.PlayerOptions[data.Slot])
        elseif data.Type == 'PublicChat' then
            AddChatText("["..data.SenderName.."] "..data.Text)
        elseif data.Type == 'PrivateChat' then
            AddChatText("<<"..data.SenderName..">> "..data.Text)
        elseif data.Type == 'CPUBenchmark' then
            -- CPU benchmark code
            local benchmarks = {}
            if data.PlayerName then
                benchmarks[data.PlayerName] = data.Result
            else
                benchmarks = data.Benchmarks
            end

            for name, result in benchmarks do
                CPU_Benchmarks[name] = result
                local id = FindIDForName(name)
                local slot = FindSlotForID(id)
                if slot then
                    SetSlotCPUBar(slot, gameInfo.PlayerOptions[slot])
                else
                    refreshObserverList()
                end
            end
        elseif data.Type == 'SetPlayerNotReady' then
            EnableSlot(data.Slot)
            GUI.becomeObserver:Enable()

            SetPlayerOption(data.Slot, 'Ready', false)
        end

        if lobbyComm:IsHost() then
            -- Host only messages
            if data.Type == 'AddPlayer' then
                -- create empty slot if possible and give it to the player
                SendCompleteGameStateToPeer(data.SenderID)
                HostTryAddPlayer(data.SenderID, 0, PlayerData(data.PlayerOptions))
                PlayVoice(Sound{Bank = 'XGG',Cue = 'XGG_Computer__04716'}, true)
				 lobbyComm:SendData( data.SenderID,{ Type = 'SetObserver', Obdata = allowobers} )
            elseif data.Type == 'MovePlayer' then
                -- attempt to move a player from current slot to empty slot
                HostTryMovePlayer(data.SenderID, data.CurrentSlot, data.RequestedSlot)
            elseif data.Type == 'RequestConvertToObserver' then
                HostConvertPlayerToObserver(data.SenderID, data.RequestedSlot)
            elseif data.Type == 'RequestConvertToPlayer' then
                HostConvertObserverToPlayer(data.SenderID, data.ObserverSlot, data.PlayerSlot)
            elseif data.Type == 'RequestColor' then
                if IsColorFree(data.Color) then
                    -- Color is available, let everyone else know
                    SetPlayerColor(gameInfo.PlayerOptions[data.Slot], data.Color)
                    lobbyComm:BroadcastData( { Type = 'SetColor', Color = data.Color, Slot = data.Slot } )
                    SetSlotInfo(data.Slot, gameInfo.PlayerOptions[data.Slot])
                else
                    -- Sorry, it's not free. Force the player back to the color we have for him.
                    lobbyComm:SendData( data.SenderID, { Type = 'SetColor', Color =
                    gameInfo.PlayerOptions[data.Slot].PlayerColor, Slot = data.Slot } )
                end
            elseif data.Type == 'ClearSlot' then
                if gameInfo.PlayerOptions[data.Slot].OwnerID == data.SenderID then
                    HostRemoveAI(data.Slot)
                else
                    WARN("Attempt to clear unowned slot")
                end
            elseif data.Type == 'SetAvailableMods' then
                availableMods[data.SenderID] = data.Mods
                HostUpdateMods(data.SenderID, data.Name)
            elseif data.Type == 'MissingMap' then
                HostPlayerMissingMapAlert(data.Id)
			elseif data.Type == 'GameVersion' then
				checkVersion[data.SenderID]=data.Vers
            end
			HostUpdateVersion(data.SenderID, data.Name) --HostUpdateVersion
        else -- Non-host only messages			
            if data.Type == 'SystemMessage' then
                AddChatText(data.Text)
            elseif data.Type == 'SetAllPlayerNotReady' then
                if not IsPlayer(localPlayerID) then
                    return
                end
                local localSlot = FindSlotForID(localPlayerID)
                EnableSlot(localSlot)
                GUI.becomeObserver:Enable()
                SetPlayerOption(localSlot, 'Ready', false)
            elseif data.Type == 'Peer_Really_Disconnected' then
				LOGX('>> DATA RECEIVE : Peer_Really_Disconnected (slot:'..data.Slot..')', 'Disconnected')
                if data.Observ == false then
                    gameInfo.PlayerOptions[data.Slot] = nil
                elseif data.Observ == true then
                    gameInfo.Observers[data.Slot] = nil
                end
                AddChatText(LOCF("<LOC Engine0003>Lost connection to %s.", data.Options.PlayerName), "Engine0003")
                ClearSlotInfo(data.Slot)
                UpdateGame()
            elseif data.Type == 'SlotAssigned' then
                gameInfo.PlayerOptions[data.Slot] = PlayerData(data.Options)
                PlayVoice(Sound{Bank = 'XGG',Cue = 'XGG_Computer__04716'}, true)
                SetSlotInfo(data.Slot, gameInfo.PlayerOptions[data.Slot])
            elseif data.Type == 'SlotMove' then
                gameInfo.PlayerOptions[data.OldSlot] = nil
                gameInfo.PlayerOptions[data.NewSlot] = PlayerData(data.Options)
                ClearSlotInfo(data.OldSlot)
                SetSlotInfo(data.NewSlot, gameInfo.PlayerOptions[data.NewSlot])
            elseif data.Type == 'ObserverAdded' then
                gameInfo.Observers[data.Slot] = PlayerData(data.Options)
                refreshObserverList()
            elseif data.Type == 'ConvertObserverToPlayer' then
                gameInfo.Observers[data.OldSlot] = nil
                gameInfo.PlayerOptions[data.NewSlot] = PlayerData(data.Options)
                refreshObserverList()
                SetSlotInfo(data.NewSlot, gameInfo.PlayerOptions[data.NewSlot])
            elseif data.Type == 'ConvertPlayerToObserver' then
                gameInfo.Observers[data.NewSlot] = PlayerData(data.Options)
                gameInfo.PlayerOptions[data.OldSlot] = nil
                ClearSlotInfo(data.OldSlot)
                refreshObserverList()
			elseif data.Type == 'SetColor' then
                SetPlayerColor(gameInfo.PlayerOptions[data.Slot], data.Color)
                SetSlotInfo(data.Slot, gameInfo.PlayerOptions[data.Slot])
            elseif data.Type == 'GameInfo' then
                -- Completely update the game state. To be used exactly once: when first connecting.
                local hostFlatInfo = data.GameInfo
                gameInfo = GameInfo.CreateGameInfo(LobbyComm.maxPlayerSlots, hostFlatInfo)
                UpdateGame()
            elseif data.Type == 'GameOptions' then
                for key, value in data.Options do
                    gameInfo.GameOptions[key] = value
                end

                UpdateGame()
            elseif data.Type == 'Launch' then
                local info = data.GameInfo
                info.GameMods = Mods.GetGameMods(info.GameMods)
                SetWindowedLobby(false)

                -- Evil hack to correct the skin for randomfaction players before launch.
                for index, player in info.PlayerOptions do
                    -- Set the skin to the faction you'll be playing as, whatever that may be. (prevents
                    -- random-faction people from ending up with something retarded)
                    if player.OwnerID == localPlayerID then
                        UIUtil.SetCurrentSkin(FACTION_NAMES[player.Faction])
                    end
                 end
				 
				UploadIconData(info)
                lobbyComm:LaunchGame(info)
            elseif data.Type == 'ClearSlot' then
                gameInfo.PlayerOptions[data.Slot] = nil
                ClearSlotInfo(data.Slot)
            elseif data.Type == 'ModsChanged' then
                gameInfo.GameMods = data.GameMods
                UpdateGame()
                import('/lua/ui/lobby/ModsManager.lua').UpdateClientModStatus(gameInfo.GameMods)
            elseif data.Type == 'SlotClosed' then
                gameInfo.ClosedSlots[data.Slot] = data.Closed
                ClearSlotInfo(data.Slot)
			elseif data.Type == 'SetObserver' then
                allowobers = data.Obdata				
            end
        end
    end

    lobbyComm.SystemMessage = function(self, text)
        AddChatText(text)
    end

    lobbyComm.GameLaunched = function(self)
        local player = lobbyComm:GetLocalPlayerID()
		if not lobbyComm:IsHost() then
			--LOG('*Test:',repr(Prefs.GetFromCurrentProfile('options')))
		
			LOG('*GameInfo:',repr(gameInfo.GameOptions))
			LOG('*GameVersion:'..repr(GameVersion()))
			for i = 1, LobbyComm.maxPlayerSlots do
				if gameInfo.ClosedSlots[i] then
					UpdateSlotBackground(i)
				else
					if gameInfo.PlayerOptions[i] then
						LOG('*PlayInfo:{')
						LOG('	PlayerName'..repr(gameInfo.PlayerOptions[i].PlayerName))
						LOG('	PlayerTeam:'..repr(gameInfo.PlayerOptions[i].Team))
						--LOG('	PlayerGameID:'..repr(gameInfo.PlayerOptions[i].GID))
						LOG('}')
					else
						ClearSlotInfo(i)
					end
				end
			end 
		end
        for i, v in gameInfo.PlayerOptions do
            if v.Human and v.OwnerID == player then
                Prefs.SetToCurrentProfile('LoadingFaction', v.Faction)
                break
            end
        end

        GpgNetSend('GameState', 'Launching')
        if GUI.pingThread then
            KillThread(GUI.pingThread)
        end
        if GUI.keepAliveThread then
            KillThread(GUI.keepAliveThread)
        end
        GUI:Destroy()
        GUI = false
        MenuCommon.MenuCleanup()
        lobbyComm:Destroy()
        lobbyComm = false

        -- determine if cheat keys should be mapped
        if not DebugFacilitiesEnabled() then
            IN_ClearKeyMap()
            IN_AddKeyMapTable(import('/lua/keymap/keymapper.lua').GetKeyMappings(gameInfo.GameOptions['CheatsEnabled']=='true'))
        end
    end

    lobbyComm.Hosting = function(self)
        localPlayerID = lobbyComm:GetLocalPlayerID()
        hostID = localPlayerID
        selectedMods = table.map(function (m) return m.uid end, Mods.GetGameMods())
        HostUpdateMods()

        -- Given an option key, find the value stored in the profile (if any) and assign either it,
        -- or that option's default value, to the current game state.
        local setOptionsFromPref = function(option)
            local defValue = Prefs.GetFromCurrentProfile("LobbyOpt_" .. option.key) or option.values[option.default].key
            SetGameOption(option.key, defValue, true)
        end

        -- Give myself the first slot
        local myPlayerData = GetLocalPlayerData()

        gameInfo.PlayerOptions[1] = myPlayerData

        -- set default lobby values
        for index, option in globalOpts do
            setOptionsFromPref(option)
        end

        for index, option in teamOpts do
            setOptionsFromPref(option)
        end

        for index, option in AIOpts do
            setOptionsFromPref(option)
        end

        -- The key, LastScenario, is referred to from GPG code we don't hook.
        self.desiredScenario = self.desiredScenario or Prefs.GetFromCurrentProfile("LastScenario")
        if self.desiredScenario and self.desiredScenario ~= "" then
            SetGameOption('ScenarioFile', self.desiredScenario, true)
        end

        GUI.keepAliveThread = ForkThread(
        -- Eject players who haven't sent a heartbeat in a while
        function()
            while true and lobbyComm do
                local peers = lobbyComm:GetPeers()
                for k,peer in peers do
                    if peer.quiet > LobbyComm.quietTimeout then
                        lobbyComm:EjectPeer(peer.id,'TimedOutToHost')
                        SendSystemMessage(LOCF("<LOC lobui_0226>%s timed out.", peer.name), "lobui_0205")
                        
                        -- Search and Remove the peer disconnected
                        for k, v in CurrentConnection do
                            if v == peer.name then
                                CurrentConnection[k] = nil
                                break
                            end
                        end
                        for k, v in ConnectionEstablished do
                            if v == peer.name then
                                ConnectionEstablished[k] = nil
                                break
                            end
                        end
                        for k, v in ConnectedWithProxy do
                            if v == peer.id then
                                ConnectedWithProxy[k] = nil
                                break
                            end
                        end
                    end
                end
                WaitSeconds(1)
            end
        end
        )

        CreateUI(LobbyComm.maxPlayerSlots)
        UpdateGame()
    end

    lobbyComm.PeerDisconnected = function(self,peerName,peerID) -- Lost connection or try connect with proxy
		LOGX('>> PeerDisconnected : peerName='..peerName..' peerID='..peerID, 'Disconnected')
        
         -- Search and Remove the peer disconnected
        for k, v in CurrentConnection do
            if v == peerName then
                CurrentConnection[k] = nil
                break
            end
        end
        for k, v in ConnectionEstablished do
            if v == peerName then
                ConnectionEstablished[k] = nil
                break
            end
        end
        for k, v in ConnectedWithProxy do
            if v == peerID then
                ConnectedWithProxy[k] = nil
                break
            end
        end
        
        if IsPlayer(peerID) then
            local slot = FindSlotForID(peerID)
            if slot and lobbyComm:IsHost() then
                PlayVoice(Sound{Bank = 'XGG',Cue = 'XGG_Computer__04717'}, true)
                lobbyComm:BroadcastData(
                {
                    Type = 'Peer_Really_Disconnected',
                    Options =  gameInfo.PlayerOptions[slot]:AsTable(),
                    Slot = slot,
                    Observ = false,
                }
                )
                ClearSlotInfo(slot)
                gameInfo.PlayerOptions[slot] = nil
                UpdateGame()
            end
        elseif IsObserver(peerID) then
            local slot2 = FindObserverSlotForID(peerID)
            if slot2 and lobbyComm:IsHost() then
                lobbyComm:BroadcastData(
                {
                    Type = 'Peer_Really_Disconnected',
                    Options =  gameInfo.Observers[slot2]:AsTable(),
                    Slot = slot2,
                    Observ = true,
                }
                )
                gameInfo.Observers[slot2] = nil
                UpdateGame()
            end
        end

        availableMods[peerID] = nil
        HostUpdateMods()
    end

    lobbyComm.GameConfigRequested = function(self)
        return {
            Options = gameInfo.GameOptions,
            HostedBy = localPlayerName,
            PlayerCount = GetPlayerCount(),
            GameName = gameName,
            ProductCode = import('/lua/productcode.lua').productCode,
        }
    end
end

function SetPlayerOptions(slot, options, ignoreRefresh)
    if not IsLocallyOwned(slot) and not lobbyComm:IsHost() then
        WARN("Hey you can't set a player option on a slot you don't own. (slot:"..tostring(slot).." / key:"..tostring(key).." / val:"..tostring(val)..")")
        return
    end

    for key, val in options do
        gameInfo.PlayerOptions[slot][key] = val
    end
        
    lobbyComm:BroadcastData(
    {
        Type = 'PlayerOptions',
        Options = options,
        Slot = slot,
    })

    if not ignoreRefresh then
        UpdateGame()
    end
end

function SetPlayerOption(slot, key, val, ignoreRefresh)
    local options = {}
    options[key] = val
    SetPlayerOptions(slot, options, ignoreRefresh)
end

function SetGameOptions(options, ignoreRefresh)
    if not lobbyComm:IsHost() then
        WARN('Attempt to set game option by a non-host')
        return
    end

    for key, val in options do
        #LOG('SetGameOption(key='..repr(key)..',val='..repr(val)..')')
        Prefs.SetToCurrentProfile('LobbyOpt_' .. key, val)
        gameInfo.GameOptions[key] = val

        -- don't want to send all restricted categories to gpgnet, so just send bool
        -- note if more things need to be translated to gpgnet, a translation table would be a better implementation
        -- but since there's only one, we'll call it out here
        if key == 'RestrictedCategories' then
            local restrictionsEnabled = false
            if val ~= nil then
                if table.getn(val) ~= 0 then
                    restrictionsEnabled = true
                end
            end
            GpgNetSend('GameOption', key, restrictionsEnabled)
        elseif key == 'ScenarioFile' then
            -- Special-snowflake the LastScenario key (used by GPG code).
            Prefs.SetToCurrentProfile('LastScenario', val)
            GpgNetSend('GameOption', key, val)
            if gameInfo.GameOptions.ScenarioFile and (gameInfo.GameOptions.ScenarioFile ~= '') then
                -- Warn about attempts to load nonexistent maps.
                if not DiskGetFileInfo(gameInfo.GameOptions.ScenarioFile) then
                    AddChatText('The selected map does not exist.')
                else
                    local scenarioInfo = MapUtil.LoadScenario(gameInfo.GameOptions.ScenarioFile)
                    if scenarioInfo and scenarioInfo.map and (scenarioInfo.map ~= '') then
                        GpgNetSend('GameOption', 'Slots', table.getsize(scenarioInfo.Configurations.standard.teams[1].armies))
                    end
                end
            end
        elseif key == "GameRules" then
            -- Oh, the cargo-culting.
            SetRuleTitleText(val)
            GpgNetSend('GameOption', key, val)
        else
            GpgNetSend('GameOption', key, val)
        end
    end

    lobbyComm:BroadcastData {
        Type = 'GameOptions',
        Options = options
    }

    if not ignoreRefresh then
        UpdateGame()
    end
end

function SetGameOption(key, val, ignoreRefresh)
    local options = {}
    options[key] = val
    SetGameOptions(options, ignoreRefresh)
end

function DebugDump()
    if lobbyComm then
        lobbyComm:DebugDump()
    end
end

-- Perform one-time setup of the large map preview
function CreateBigPreview(parent)
    if LrgMap then
        LrgMap.isHidden = false
        RefreshLargeMap()
        LrgMap:Show()
        return
    end

    -- Size of the map preview to generate.
    local MAP_PREVIEW_SIZE = 721

    -- The size of the mass/hydrocarbon icons
    local HYDROCARBON_ICON_SIZE = 14
    local MASS_ICON_SIZE = 10

    local dialogContent = Group(parent)
    dialogContent.Width:Set(MAP_PREVIEW_SIZE + 10)
    dialogContent.Height:Set(MAP_PREVIEW_SIZE + 10)

    LrgMap = Popup(parent, dialogContent)

    -- The LrgMap shouldn't be destroyed due to issues related to texture pooling. Evil hack ensues.
    local onTryMapClose = function()
        LrgMap:Hide()
        LrgMap.isHidden = true
    end
    LrgMap.OnEscapePressed = onTryMapClose
    LrgMap.OnShadowClicked = onTryMapClose

    -- Create the map preview
    local mapPreview = ResourceMapPreview(dialogContent, MAP_PREVIEW_SIZE, MASS_ICON_SIZE, HYDROCARBON_ICON_SIZE)
    dialogContent.mapPreview = mapPreview
    LayoutHelpers.AtCenterIn(mapPreview, dialogContent)

    local closeBtn = UIUtil.CreateButtonStd(dialogContent, '/dialogs/close_btn/close')
    LayoutHelpers.AtRightTopIn(closeBtn, dialogContent, 1, 1)
    closeBtn.OnClick = onTryMapClose

    -- Keep the close button on top of the border (which is itself on top of the map preview)
    LayoutHelpers.DepthOverParent(closeBtn, mapPreview, 2)

    RefreshLargeMap()
end

-- Refresh the large map preview (so it can update if something changes while it's open)
function RefreshLargeMap()
    if not LrgMap or LrgMap.isHidden then
        return
    end

    local scenarioInfo = MapUtil.LoadScenario(gameInfo.GameOptions.ScenarioFile)
    LrgMap.content.mapPreview:SetScenario(scenarioInfo, true)
    ConfigureMapListeners(LrgMap.content.mapPreview, scenarioInfo)
    ShowMapPositions(LrgMap.content.mapPreview, scenarioInfo)
end

--CPU Status Bar Configuration
local barMax = 450
local barMin = 0
local greenBarMax = 300
local yellowBarMax = 375
local scoreSkew1 = 0 --Skews all CPU scores up or down by the amount specified (0 = no skew)
local scoreSkew2 = 1.0 --Skews all CPU scores specified coefficient (1.0 = no skew)

--Variables for CPU Test
local BenchTime

--------------------------------------------------
--  CPU Benchmarking Functions
--------------------------------------------------
function CPUBenchmark()
    --This function gives the CPU some busy work to do.
    --CPU score is determined by how quickly the work is completed.
    local totalTime = 0
    local lastTime
    local currTime
    local countTime = 0
    --Make everything a local variable
    --This is necessary because we don't want LUA searching through the globals as part of the benchmark
    local h
    local i
    local j
    local k
    local l
    local m
    for h = 1, 48, 1 do
        -- If the need for the benchmark no longer exists, abort it now.
        if not lobbyComm then
            return
        end

        lastTime = GetSystemTimeSeconds()
        for i = 1.0, 25.0, 0.0008 do
            --This instruction set should cover most LUA operators
            j = i + i   --Addition
            k = i * i   --Multiplication
            l = k / j   --Division
            m = j - i   --Subtraction
            j = i ^ 4   --Power
            l = -i      --Negation
            m = {'One', 'Two', 'Three'} --Create Table
            table.insert(m, 'Four')     --Insert Table Value
            table.remove(m, 1)          --Remove Table Value
            l = table.getn(m)           --Get Table Length
            k = i < j   --Less Than
            k = i == j  --Equality
            k = i <= j  --Less Than or Equal to
            k = not k
        end
        currTime = GetSystemTimeSeconds()
        totalTime = totalTime + currTime - lastTime

        if totalTime > countTime then
            --This is necessary in order to make this 'thread' yield so other things can be done.
            countTime = totalTime + .125
            WaitSeconds(0)
        end
    end
    BenchTime = math.ceil(totalTime * 100)
end

--------------------------------------------------
--  CPU GUI Functions
--------------------------------------------------
function CreateCPUMetricUI()
    --This function handles creation of the CPU benchmark UI elements (statusbars, buttons, tooltips, etc)
    local StatusBar = import('/lua/maui/statusbar.lua').StatusBar
    if not singlePlayer then
        for i= 1, LobbyComm.maxPlayerSlots do
            GUI.slots[i].CPUSpeedBar = StatusBar(GUI.slots[i].pingGroup, barMin, barMax, false, false,
            UIUtil.UIFile('/game/unit_bmp/bar_black_bmp.dds'),
            UIUtil.UIFile('/game/unit_bmp/bar_purple_bmp.dds'),
            true)
            LayoutHelpers.AtBottomIn(GUI.slots[i].CPUSpeedBar, GUI.slots[i].pingGroup, 2)
            LayoutHelpers.AtLeftIn(GUI.slots[i].CPUSpeedBar, GUI.slots[i].pingGroup, 0)
            LayoutHelpers.AtRightIn(GUI.slots[i].CPUSpeedBar, GUI.slots[i].pingGroup, 0)
            CPU_AddControlTooltip(GUI.slots[i].CPUSpeedBar, 0, i)
            GUI.slots[i].CPUSpeedBar.CPUActualValue = 450

        end

        GUI.rerunBenchmark.OnClick = function(self, modifiers)
            ForkThread(function() UpdateBenchmark(true) end)
        end
    end
end

function CPU_AddControlTooltip(control, delay, slotNumber)
    --This function creates the benchmark tooltip for a slot along with necessary mouseover function.
    --It is called during the UI creation.
    --    control: The control to which the tooltip is to be added.
    --    delay: Amount of time to delay before showing tooltip.  See Tooltip.CreateMouseoverDisplay for info.
    --  slotNumber: The slot number associated with the control.
    if not control.oldHandleEvent then
        control.oldHandleEvent = control.HandleEvent
    end
    control.HandleEvent = function(self, event)
        if event.Type == 'MouseEnter' then
            local slot = slotNumber
            Tooltip.CreateMouseoverDisplay(self, {text='CPU 等级: '..GUI.slots[slot].CPUSpeedBar.CPUActualValue,
            body='0=最快, 450=最慢'}, delay, true)
        elseif event.Type == 'MouseExit' then
            Tooltip.DestroyMouseoverDisplay()
        end
        return self.oldHandleEvent(self, event)
    end
end

--- Get the CPU benchmark score for the local machine.
-- If a previously-calculated benchmark score is found in the profile, it is returned immediately.
-- Otherwise, a fresh score is calculated and stored (enjoy the lag!).
--
-- @param force If truthy, a fresh score is always calculated.
-- @return A benchmark score between 0 and 450, or nil if StressCPU returned nil (which occurs iff
--         the lobby is exited before the calculation is complete. Callers should abort gracefully
--         in this situation).
-- @see StressCPU
function GetBenchmarkScore(force)
    local wait = 10
    local benchmark

    if force then
        wait = 0
    else
        benchmark = GetPreference('CPUBenchmark')
    end

    if not benchmark then
        -- We defer the calculation by 10s here because, often, non-forced requests are occurring on
        -- startup, and we want to give other tasks, such as connection negotiation, a fighting
        -- chance of completing before we ruin everything.
        --
        -- Benchmark scores are associated with the machine, not the profile: hence SetPreference.

        benchmark = StressCPU(wait)
        SetPreference('CPUBenchmark', benchmark)
    end

    return benchmark
end

--- Updates the displayed benchmark score for the local player.
--
-- @param force Passed as the `force` parameter to GetBenchmarkScore.
-- @see GetBenchmarkScore
function UpdateBenchmark(force)
    local benchmark = GetBenchmarkScore(force)

    if benchmark then
        CPU_Benchmarks[localPlayerName] = benchmark
        lobbyComm:BroadcastData({ Type = 'CPUBenchmark', PlayerName = localPlayerName, Result = benchmark })
        if FindObserverSlotForID(localPlayerID) then
            refreshObserverList()
        else
            UpdateCPUBar(localPlayerName)
        end
    end
end

-- This function instructs the PC to do a CPU score benchmark.
-- It handles the necessary UI updates during the benchmark, sends
-- the benchmark result to other players when finished, and it updates the local
-- user's UI with their new result.
--    waitTime: The delay in seconds that this function should wait before starting the benchmark.
function StressCPU(waitTime)
    GUI.rerunBenchmark:Disable()
    for i = waitTime, 1, -1 do
        GUI.rerunBenchmark.label:SetText(i..'s')
        WaitSeconds(1)

        -- lobbyComm is destroyed when the lobby is exited. If the user left the lobby, we no longer
        -- want to run the benchmark (it just introduces lag as the user is trying to do something
        -- else.
        if not lobbyComm then
            return
        end
    end

    --Get our last benchmark (if there was one)
    local currentBestBenchmark = 10000

    GUI.rerunBenchmark.label:SetText('. . .')

    --Run three benchmarks and keep the best one
    for i=1, 3, 1 do
        BenchTime = 0
        CPUBenchmark()

        BenchTime = scoreSkew2 * BenchTime + scoreSkew1

        -- The bench might have yeilded to a launcher, so we verify the lobbyComm is available when
        -- we need it in a moment here (as well as aborting if we're wasting our time more than usual)
        if not lobbyComm then
            return
        end

        --If this benchmark was better than our best so far...
        if BenchTime < currentBestBenchmark then
            currentBestBenchmark = BenchTime
        end
    end

    --Reset Button UI
    GUI.rerunBenchmark:Enable()
    GUI.rerunBenchmark.label:SetText('')

    return currentBestBenchmark
end

function UpdateCPUBar(playerName)
    --This function updates the UI with a CPU benchmark bar for the specified playerName.
    --    playerName: The name of the player whose benchmark should be updated.
    local playerId = FindIDForName(playerName)
    local playerSlot = FindSlotForID(playerId)
    if playerSlot ~= nil then
        SetSlotCPUBar(playerSlot, gameInfo.PlayerOptions[playerSlot])
    end
end

function SetSlotCPUBar(slot, playerInfo)
    --This function updates the UI with a CPU benchmark bar for the specified slot/playerInfo.
    --    slot: a numbered slot (1-however many slots there are for this map)
    --    playerInfo: The corresponding playerInfo object from gameInfo.PlayerOptions[slot].


    if GUI.slots[slot].CPUSpeedBar then
        GUI.slots[slot].CPUSpeedBar:Hide()
        if playerInfo.Human then
            local b = CPU_Benchmarks[playerInfo.PlayerName]
            if b then
                -- For display purposes, the bar has a higher minimum that the actual barMin value.
                -- This is to ensure that the bar is visible for very small values

                -- Lock values to the largest possible result.
                if b > barMax then
                    b = barMax
                end

                GUI.slots[slot].CPUSpeedBar:SetValue(b)
                GUI.slots[slot].CPUSpeedBar.CPUActualValue = b

                GUI.slots[slot].CPUSpeedBar:Show()
            end
        end
    end
end

-- Rule title
function SetRuleTitleText(rule)
    GUI.RuleLabel:SetColors("B9BFB9")
    if rule == '' then
        if lobbyComm:IsHost() then
            GUI.RuleLabel:SetColors("FFCC00")
            rule = '新手联机教程、录像、MOD，请加QQ群659797309'
        else
            rule = "FA联机QQ群659797309"
        end
    end

    GUI.RuleLabel:SetText(rule)
end

-- Show the rule change dialog.
function ShowRuleDialog(RuleLabel)
    local ruleDialog = InputDialog(GUI, '游戏声明')
    GUI.ruleDialog = ruleDialog
    ruleDialog.OnInput = function(self, rules)
        SetGameOption("GameRules", rules, true)
    end
end

-- Faction selector
function CreateUI_Faction_Selector(lastFaction)
    -- Build a list of button objects from the list of defined factions. Each faction will use the
    -- faction key as its RadioButton texture path offset.
    local buttons = {}
    for i, faction in FactionData.Factions do
        buttons[i] = {
            texturePath = faction.Key
        }
    end

    -- Special-snowflaking for the random faction.
    table.insert(buttons, {
        texturePath = "random"
    })

    local factionSelector = RadioButton(GUI.panel, "/factionselector/", buttons, lastFaction, true)
    GUI.factionSelector = factionSelector
    LayoutHelpers.AtLeftTopIn(factionSelector, GUI.panel, 407, 20)
    factionSelector.OnChoose = function(self, targetFaction, key)
        local localSlot = FindSlotForID(localPlayerID)
        Prefs.SetToCurrentProfile('LastFaction', targetFaction)
        GUI.slots[localSlot].faction:SetItem(targetFaction)
        SetPlayerOption(localSlot, 'Faction', targetFaction)
        gameInfo.PlayerOptions[localSlot].Faction = targetFaction

        RefreshLobbyBackground(targetFaction)
        UIUtil.SetCurrentSkin(FACTION_NAMES[targetFaction])
    end
end

function RefreshLobbyBackground(faction)
    local LobbyBackground = Prefs.GetFromCurrentProfile('LobbyBackground') or 1
    if GUI.background then
        GUI.background:Destroy()
    end
    if LobbyBackground == 1 then -- Factions
        faction = faction or GetSanitisedLastFaction()
        if FACTION_NAMES[faction] then
            GUI.background = Bitmap(GUI, "/textures/ui/common/BACKGROUND/faction/faction-background-paint_" .. FACTION_NAMES[faction] .. "_bmp.dds")
        else
            return
        end
    elseif LobbyBackground == 2 then -- Concept art
        GUI.background = Bitmap(GUI, "/textures/ui/common/BACKGROUND/art/art-background-paint0" .. math.random(1, 5) .. "_bmp.dds")
    elseif LobbyBackground == 3 then -- Screenshot
        GUI.background = Bitmap(GUI, "/textures/ui/common/BACKGROUND/scrn/scrn-background-paint" .. math.random(1, 14) .. "_bmp.dds")
    elseif LobbyBackground == 4 then -- Map
        local MapPreview = import('/lua/ui/controls/mappreview.lua').MapPreview
        GUI.background = MapPreview(GUI) -- Background map
        if gameInfo.GameOptions.ScenarioFile and (gameInfo.GameOptions.ScenarioFile ~= '') then
            local scenarioInfo = MapUtil.LoadScenario(gameInfo.GameOptions.ScenarioFile)
            if scenarioInfo and scenarioInfo.map and (scenarioInfo.map ~= '') and scenarioInfo.preview then
                if not GUI.background:SetTexture(scenarioInfo.preview) then
                    GUI.background:SetTextureFromMap(scenarioInfo.map)
                end
            end
        end
	elseif LobbyBackground == 5 then -- m2
	GUI.background = Bitmap(GUI, "/textures/ui/common/BACKGROUND/m2/m2-background-paint" .. math.random(1, 15) .. "_bmp.dds")
	elseif LobbyBackground == 6 then -- rv
	GUI.background = Bitmap(GUI, "/textures/ui/common/BACKGROUND/rv/rv-background-paint" .. math.random(1, 15) .. "_bmp.dds")
    elseif LobbyBackground == 7 then -- None
        return
    end

    local LobbyBackgroundStretch = Prefs.GetFromCurrentProfile('LobbyBackgroundStretch') or 'true'
    LayoutHelpers.AtCenterIn(GUI.background, GUI)
    LayoutHelpers.DepthUnderParent(GUI.background, GUI.panel)
    if LobbyBackgroundStretch == 'true' then
        LayoutHelpers.FillParent(GUI.background, GUI)
    else
        LayoutHelpers.FillParentPreserveAspectRatio(GUI.background, GUI)
    end
end

function ShowLobbyOptionsDialog()
    local dialogContent = Group(GUI)
    dialogContent.Width:Set(420)
    dialogContent.Height:Set(240)

    local dialog = Popup(GUI, dialogContent)
    GUI.lobbyOptionsDialog = dialog

    local buttons = {
        {
            label = LOC("<LOC lobui_0406>") -- Factions
        },
        {
            label = LOC("<LOC lobui_0407>")  -- Concept art
        },
        {
            label = LOC("<LOC lobui_0408>") -- Screenshot
        },
        {
            label = LOC("<LOC lobui_0409>") -- Map
        },
		{
            label = LOC("<LOC lobui_m2>") -- m2
        },
		{
            label = LOC("<LOC lobui_rv>") -- rv
        },
        {
            label = LOC("<LOC lobui_0410>") -- None
        }
    }

    -- Label shown above the background mode selection radiobutton.
    local backgroundLabel = UIUtil.CreateText(dialogContent, LOC("<LOC lobui_0405> "), 16, 'Arial', true)
    local selectedBackgroundState = Prefs.GetFromCurrentProfile("LobbyBackground") or 1
    local backgroundRadiobutton = RadioButton(dialogContent, '/RADIOBOX/', buttons, selectedBackgroundState, false, true)

    LayoutHelpers.AtLeftTopIn(backgroundLabel, dialogContent, 15, 15)
    LayoutHelpers.AtLeftTopIn(backgroundRadiobutton, dialogContent, 15, 40)

    backgroundRadiobutton.OnChoose = function(self, index, key)
        Prefs.SetToCurrentProfile("LobbyBackground", index)
        RefreshLobbyBackground()
    end
	--
	local currentFontSize = Prefs.GetFromCurrentProfile('LobbyChatFontSize') or 14
	local slider_Chat_SizeFont_TEXT = UIUtil.CreateText(dialogContent, LOC("<LOC lobui_0404> ").. currentFontSize, 14, 'Arial', true)
    LayoutHelpers.AtRightTopIn(slider_Chat_SizeFont_TEXT, dialogContent, 27, 136)

	local slider_Chat_SizeFont = Slider(dialogContent, false, 9, 18, UIUtil.SkinnableFile('/slider02/slider_btn_up.dds'), UIUtil.SkinnableFile('/slider02/slider_btn_over.dds'), UIUtil.SkinnableFile('/slider02/slider_btn_down.dds'), UIUtil.SkinnableFile('/slider02/slider-back_bmp.dds'))
    LayoutHelpers.AtRightTopIn(slider_Chat_SizeFont, dialogContent, 20, 156)
    slider_Chat_SizeFont:SetValue(currentFontSize)

	slider_Chat_SizeFont.OnValueChanged = function(self, newValue)
        local sliderValue = math.floor(slider_Chat_SizeFont._currentValue())
        slider_Chat_SizeFont_TEXT:SetText(LOC("<LOC lobui_0404> ").. sliderValue)
        GUI.chatDisplay:SetFont(UIUtil.bodyFont, sliderValue)
        Prefs.SetToCurrentProfile('LobbyChatFontSize', sliderValue)
	end
	--
    local cbox_WindowedLobby = UIUtil.CreateCheckbox(dialogContent, '/CHECKBOX/', LOC("<LOC lobui_0402>"))
    LayoutHelpers.AtRightTopIn(cbox_WindowedLobby, dialogContent, 20, 42)
    Tooltip.AddCheckboxTooltip(cbox_WindowedLobby, {text='窗口模式', body=LOC("<LOC lobui_0403>")})
    cbox_WindowedLobby.OnCheck = function(self, checked)
        local option
        if checked then
            option = 'true'
        else
            option = 'false'
        end
        Prefs.SetToCurrentProfile('WindowedLobby', option)
        SetWindowedLobby(checked)
    end
    --
    local cbox_StretchBG = UIUtil.CreateCheckbox(dialogContent, '/CHECKBOX/', LOC("<LOC lobui_0400>"))
    LayoutHelpers.AtRightTopIn(cbox_StretchBG, dialogContent, 20, 68)
    Tooltip.AddCheckboxTooltip(cbox_StretchBG, {text='拉伸背景', body=LOC("<LOC lobui_0401>")})
    cbox_StretchBG.OnCheck = function(self, checked)
        if checked then
            Prefs.SetToCurrentProfile('LobbyBackgroundStretch', 'true')
        else
            Prefs.SetToCurrentProfile('LobbyBackgroundStretch', 'false')
        end
        RefreshLobbyBackground()
    end
    -- Quit button
    local QuitButton = UIUtil.CreateButtonWithDropshadow(dialogContent, '/BUTTON/medium/', "关")
    LayoutHelpers.AtHorizontalCenterIn(QuitButton, dialogContent, 0)
    LayoutHelpers.AtBottomIn(QuitButton, dialogContent, 10)

    QuitButton.OnClick = function(self)
        dialog:Hide()
    end
    --
    local WindowedLobby = Prefs.GetFromCurrentProfile('WindowedLobby') or 'true'
    cbox_WindowedLobby:SetCheck(WindowedLobby == 'true', true)
	if defaultMode == 'windowed' then
		-- Already set Windowed in Game
		cbox_WindowedLobby:Disable()
	end
    --
    local LobbyBackgroundStretch = Prefs.GetFromCurrentProfile('LobbyBackgroundStretch') or 'true'
    cbox_StretchBG:SetCheck(LobbyBackgroundStretch == 'true', true)
end

-- Load and return the current list of presets from persistent storage.
function LoadPresetsList()
    return Prefs.GetFromCurrentProfile("LobbyPresets") or {}
end

-- Write the given list of preset profiles to persistent storage.
function SavePresetsList(list)
    Prefs.SetToCurrentProfile("LobbyPresets", list)
    SavePreferences()
end

-- Show the lobby preset UI.
function ShowPresetDialog()
    local dialogContent = Group(GUI)
    dialogContent.Width:Set(600)
    dialogContent.Height:Set(530)

    local presetDialog = Popup(GUI, dialogContent)
    presetDialog.OnClosed = presetDialog.Destroy
    GUI.presetDialog = presetDialog

    -- Title
    local titleText = UIUtil.CreateText(dialogContent, '储存选项', 17, 'Arial Gras', true)
    LayoutHelpers.AtHorizontalCenterIn(titleText, dialogContent, 0)
    LayoutHelpers.AtTopIn(titleText, dialogContent, 10)

    -- Preset List
    local PresetList = ItemList(dialogContent)
    PresetList:SetFont(UIUtil.bodyFont, 14)
    PresetList:ShowMouseoverItem(true)
    PresetList.Width:Set(265)
    PresetList.Height:Set(430)
    LayoutHelpers.DepthOverParent(PresetList, dialogContent, 10)
    LayoutHelpers.AtLeftIn(PresetList, dialogContent, 14)
    LayoutHelpers.AtTopIn(PresetList, dialogContent, 38)
    UIUtil.CreateLobbyVertScrollbar(PresetList, 2)

    -- Info List
    local InfoList = ItemList(dialogContent)
    InfoList:SetFont(UIUtil.bodyFont, 11)
    InfoList:SetColors(nil, "00000000")
    InfoList:ShowMouseoverItem(true)
    InfoList.Width:Set(281)
    InfoList.Height:Set(430)
    LayoutHelpers.RightOf(InfoList, PresetList, 26)

    -- Quit button
    local QuitButton = UIUtil.CreateButtonStd(dialogContent, '/dialogs/close_btn/close')
    LayoutHelpers.AtRightIn(QuitButton, dialogContent, 1)
    LayoutHelpers.AtTopIn(QuitButton, dialogContent, 1)

    -- Load button
    local LoadButton = UIUtil.CreateButtonWithDropshadow(dialogContent, '/BUTTON/medium/', "加载")
    LayoutHelpers.AtLeftIn(LoadButton, dialogContent, -2)
    LayoutHelpers.AtBottomIn(LoadButton, dialogContent, 10)
    LoadButton:Disable()

    -- Create button. Occupies the same space as the load button, when available.
    local CreateButton = UIUtil.CreateButtonWithDropshadow(dialogContent, '/BUTTON/medium/', "创建")
    LayoutHelpers.RightOf(CreateButton, LoadButton, 28)

    -- Save button
    local SaveButton = UIUtil.CreateButtonWithDropshadow(dialogContent, '/BUTTON/medium/', "保存")
    LayoutHelpers.RightOf(SaveButton, CreateButton, 28)
    SaveButton:Disable()

    -- Delete button
    local DeleteButton = UIUtil.CreateButtonWithDropshadow(dialogContent, '/BUTTON/medium/', "删除")
    LayoutHelpers.RightOf(DeleteButton, SaveButton, 28)
    DeleteButton:Disable()

    LoadButton.OnClick = function(self)
        LoadPreset(PresetList:GetSelection() + 1)
    end
    
    QuitButton.OnClick = function(self)
        presetDialog:Hide()
    end

    CreateButton.OnClick = function(self)
        local dialogComplete = function(self, presetName)
            if not presetName or presetName == "" then
                return
            end
            local profiles = LoadPresetsList()
            table.insert(profiles, GetPresetFromSettings(presetName))
            SavePresetsList(profiles)

            RefreshAvailablePresetsList(PresetList)

            PresetList:SetSelection(0)
            PresetList:OnClick(0)
        end

        CreateInputDialog(GUI, "创建一个预设名字", dialogComplete)
    end

    SaveButton.OnClick = function(self)
        local selectedPreset = PresetList:GetSelection() + 1

        SavePreset(selectedPreset)
        ShowPresetDetails(selectedPreset, InfoList)
    end

    DeleteButton.OnClick = function(self)
        local profiles = LoadPresetsList()

        -- Converting between zero-based indexing in the list and the table indexing...
        table.remove(profiles, PresetList:GetSelection() + 1)

        SavePresetsList(profiles)
        RefreshAvailablePresetsList(PresetList)

        -- And clear the detail view.
        InfoList:DeleteAllItems()
    end

    -- Called when the selected item in the preset list changes.
    local onListItemChanged = function(self, row)
        ShowPresetDetails(row + 1, InfoList)
        LoadButton:Enable()
        SaveButton:Enable()
        DeleteButton:Enable()
    end

    -- Because GPG's event model is painfully retarded..
    PresetList.OnKeySelect = onListItemChanged
    PresetList.OnClick = function(self, row, event)
        self:SetSelection(row)
        onListItemChanged(self, row)
    end

    PresetList.OnDoubleClick = function(self, row)
        LoadPreset(row + 1)
    end

    -- When the user double-clicks on a metadata field, give them a popup to change its value.
    InfoList.OnDoubleClick = function(self, row)
        -- Closure copy, accounting for zero-based indexing in ItemList.
        local theRow = row + 1

        local nameChanged = function(self, str)
            if str == "" then
                return
            end

            local profiles = LoadPresetsList()
            profiles[theRow].Name = str
            SavePresetsList(profiles)

            -- Update the name displayed in the presets list, preserving selection.
            local lastselect = PresetList:GetSelection()
            RefreshAvailablePresetsList(PresetList)
            PresetList:SetSelection(lastselect)

            ShowPresetDetails(theRow, InfoList)
        end

        if row == 0 then
            CreateInputDialog(GUI, "Rename your preset", nameChanged)
        end
    end

    -- Show the "Double-click to edit" tooltip when the user mouses-over an editable field.
    InfoList.OnMouseoverItem = function(self, row)
        -- Determine which metadata cell they moused-over, if any.
        local metadataType
        -- For now, only name is editable. A nice mechanism to edit game preferences seems plausible.
        if row == 0 then
            metadataType = "Preset name"
        else
            Tooltip.DestroyMouseoverDisplay()
            return
        end

        local tooltip = {
            text = metadataType,
            body = "Double-click to edit"
        }

        Tooltip.CreateMouseoverDisplay(self, tooltip, 0, true)
    end

    RefreshAvailablePresetsList(PresetList)
    if PresetList:GetItemCount() == 0 then
        CreateHelpWindow()
    end
end

function CreateHelpWindow()
    local dialogContent = Group(GUI)
    dialogContent.Width:Set(420)
    dialogContent.Height:Set(225)

    local helpWindow = Popup(GUI, dialogContent)

    -- Help textfield
    local textArea = TextArea(dialogContent, 400, 163)
    LayoutHelpers.AtLeftIn(textArea, dialogContent, 13)
    LayoutHelpers.AtTopIn(textArea, dialogContent, 10)
    textArea:SetText(import('/lua/ui/lobby/presetHelp.lua').helpText)
    
    -- OK button
    local OkButton = UIUtil.CreateButtonWithDropshadow(dialogContent, '/BUTTON/medium/', "Ok")
	LayoutHelpers.AtHorizontalCenterIn(OkButton, dialogContent)
    LayoutHelpers.AtBottomIn(OkButton, dialogContent, 8)
    OkButton.OnClick = function(self)
        helpWindow:Close()
    end
end

-- Create an input dialog with the given title and listener function.
function CreateInputDialog(parent, title, listener)
    local dialog = InputDialog(parent, title, listener)
    dialog.OnInput = listener
end

-- Refresh list of presets
function RefreshAvailablePresetsList(PresetList)
    local profiles = LoadPresetsList()
    PresetList:DeleteAllItems()

    for k, v in profiles do
        PresetList:AddItem(v.Name)
    end
end

-- Update the right-hand panel of the preset dialog to show the contents of the currently selected
-- profile (passed by name as a parameter)
function ShowPresetDetails(preset, InfoList)
    local profiles = LoadPresetsList()
    InfoList:DeleteAllItems()
    InfoList:AddItem('预置名称: ' .. profiles[preset].Name)

    if DiskGetFileInfo(profiles[preset].MapPath) then
        InfoList:AddItem('地图: ' .. profiles[preset].MapName)
    else
        InfoList:AddItem('地图: 不可用 (' .. profiles[preset].MapName .. ')')
    end

    InfoList:AddItem('')

    -- For each mod, look up its name and pretty-print it.
    local allMods = Mods.AllMods()
    for modId, v in profiles[preset].GameMods do
        if v then
            InfoList:AddItem('Mod: ' .. allMods[modId].name)
        end
    end

    InfoList:AddItem('')
    InfoList:AddItem('详细设置内容 :')
    for k, v in sortedpairs(profiles[preset].GameOptions) do
        InfoList:AddItem('- '..k..' : '..tostring(v))
    end
end

-- Create a preset table representing the current configuration.
function GetPresetFromSettings(presetName)
    return {
        Name = presetName,
        MapName = MapUtil.LoadScenario(gameInfo.GameOptions.ScenarioFile).name,
        MapPath = gameInfo.GameOptions.ScenarioFile,
        GameOptions = gameInfo.GameOptions,
        GameMods = gameInfo.GameMods
    }
end

-- Load the given preset
function LoadPreset(presetIndex)
    local preset = LoadPresetsList()[presetIndex]

    SetGameOptions(preset.GameOptions, true)
    
    -- gameInfo.GameMods is a map from mod identifiers to truthy values for every activated mod.
    -- Unfortunately, HostUpdateMods is painfully stupid and reads selectedMods, which is a list of
    -- mod identifiers to be activated.
    -- Ultimately, we want to make HostUpdateMods not be stupid, so presets just pickle the GameMods
    -- map directly. For now, though, that means we have the following stupid loop to keep the
    -- retarded HostUpdateMods working.
    --
    -- Thanks, William.
    selectedMods = {}
    for k, v in preset.GameMods do
        if v then
            table.insert(selectedMods, k)
        end
    end

    HostUpdateMods()

    GUI.presetDialog:Hide()
    UpdateGame()
end

-- Write the current settings to the given preset profile index
function SavePreset(index)
    local profiles = LoadPresetsList()

    local selectedPreset = index
    profiles[selectedPreset] = GetPresetFromSettings(profiles[selectedPreset].Name)

    SavePresetsList(profiles)
end

-- Find the key for the given value in a table.
-- Nil keys are not supported.
function indexOf(table, needle)
    for k, v in table do
        if v == needle then
            return k
        end
    end
    return nil
end

-- Update the combobox for the given slot so it correctly shows the set of available colours.
-- causes availableColours[slot] to be repopulated.
function Check_Availaible_Color(slot)
    availableColours[slot] = {}

    -- For each possible colour, scan the slots to try and find it and, if unsuccessful, add it to
    -- the available colour set.
    local allColours = gameColors.PlayerColors
    for k, v in allColours do
        local found = false
        for ii = 1, LobbyComm.maxPlayerSlots do
            -- Skip this slot and empty slots.
            if slot ~= ii and gameInfo.PlayerOptions[ii] then
                if gameInfo.PlayerOptions[ii].PlayerColor == k then
                    found = true
                    break
                end
            end
        end

        if not found then
            availableColours[slot][k] = allColours[k]
        end
    end
    --
    GUI.slots[slot].color:ChangeBitmapArray(availableColours[slot], true)
    GUI.slots[slot].color:SetItem(gameInfo.PlayerOptions[slot].PlayerColor)
end

-- Changelog dialog
function Need_Changelog()
	local Changelog = import('/lua/ui/lobby/changelog.lua').changelog
	local Last_Changelog_Version = Prefs.GetFromCurrentProfile('LobbyChangelog') or 0
	local result = false
	for i, d in Changelog do
		if Last_Changelog_Version < d.version then
			result = true
			break
		end
	end
	return result
end

function GUI_Changelog()
    local dialogContent = Group(GUI)
    dialogContent.Width:Set(526)
    dialogContent.Height:Set(450)

    local Changelog = import('/lua/ui/lobby/changelog.lua')
    local changelogPopup = Popup(GUI, dialogContent)
    changelogPopup.OnClosed = function()
        Prefs.SetToCurrentProfile('LobbyChangelog', Changelog.last_version)
    end

    -- Title --
    local text0 = UIUtil.CreateText(dialogContent, LOC("<LOC lobui_0412>"), 17, 'Arial Gras', true)
    LayoutHelpers.AtHorizontalCenterIn(text0, dialogContent, 0)
    LayoutHelpers.AtTopIn(text0, dialogContent, 10)

    -- Info List --
    local InfoList = ItemList(dialogContent)
    InfoList:SetFont(UIUtil.bodyFont, 11)
    InfoList:SetColors(nil, "00000000")
    InfoList.Width:Set(498)
    InfoList.Height:Set(360)
    LayoutHelpers.AtLeftIn(InfoList, dialogContent, 10)
	LayoutHelpers.AtRightIn(InfoList, dialogContent, 26)
    LayoutHelpers.AtTopIn(InfoList, dialogContent, 38)
    UIUtil.CreateLobbyVertScrollbar(InfoList)
	InfoList.OnClick = function(self) end
	-- See only new Changelog by version
	local Last_Changelog_Version = Prefs.GetFromCurrentProfile('LobbyChangelog') or 0
	for i, d in Changelog.changelog do
		if Last_Changelog_Version < d.version then
			InfoList:AddItem(d.name)
			for k, v in d.description do
				InfoList:AddItem(v)
			end
			InfoList:AddItem('')
		end
	end
     
    -- OK button --
    local OkButton = UIUtil.CreateButtonWithDropshadow(dialogContent, '/BUTTON/medium/', "Ok")
	LayoutHelpers.AtLeftIn(OkButton, dialogContent, 0)
    LayoutHelpers.AtBottomIn(OkButton, dialogContent, 10)
    OkButton.OnClick = function()
        changelogPopup:Close()
    end
end
function table.binsert(t, value, cmp)
      local cmp = cmp or (function(a,b) return a < b end)
      local start, stop, mid, state = 1, table.getsize(t), 1, 0
      while start <= stop do
         mid = math.floor((start + stop) / 2)
         if cmp(value, t[mid]) then
            stop, state = mid - 1, 0
         else
            start, state = mid + 1, 1
         end
      end

      table.insert(t, mid + state, value)
      return mid + state
end