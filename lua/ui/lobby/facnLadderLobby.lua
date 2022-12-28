--*****************************************************************************
--* File: lua/modules/ui/lobby/facnLadderLobby.lua
--* Author: XH-LinLin
--* Summary: ladder lobby menu for FACN
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
local globalOpts = import('/lua/ui/lobby/lobbyOptions.lua').globalOpts
local teamOpts = import('/lua/ui/lobby/lobbyOptions.lua').teamOptions
local AIOpts = import('/lua/ui/lobby/lobbyOptions.lua').AIOpts
local gameColors = import('/lua/gameColors.lua').GameColors
local Movie = import('/lua/maui/movie.lua').Movie
local numOpenSlots = 2
local maxPlayerSlots = 8

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
}

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
        numGames = tonumber(GetCommandLineArgOrDefault("/numgames", 0)),
        playerMean = tonumber(GetCommandLineArgOrDefault("/mean", 1500)),
        playerClan = tostring(GetCommandLineArgOrDefault("/clan", "")),
		onlinecheck = tonumber(GetCommandLineArgOrDefault("/online", 0)),
		Score = tonumber(GetCommandLineArgOrDefault("/score", 0)),
		Faction = tonumber(GetCommandLineArgOrDefault("/ladder", 5)),
		Map = tostring(GetCommandLineArgOrDefault("/loadmap", 0)),
    }
end
local argv = parseCommandlineArguments()
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

    HostTryMovePlayer(fromOpts.OwnerID, moveFrom, moveTo) -- Move Player moveFrom to Slot moveTo
    HostConvertObserverToPlayer(toOpts.OwnerID, FindObserverSlotForID(toOpts.OwnerID), moveFrom)
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
            PlayerColor = 1,--FACN
            Faction = argv.Faction,
            PlayerClan = argv.playerClan,
            NG = argv.numGames,
            MEAN = argv.playerMean,
            Country = argv.PrefLanguage,
			BuildMult = 1,
			CheatMult = 1,
			BuildMultIndex = 1,
			CheatMultIndex = 1,
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
    numOpenSlots = 2
    gameInfo = GameInfo.CreateGameInfo(maxPlayerSlots)
end

--- Create a new, unconnected lobby.
function CreateLobby(protocol, localPort, desiredPlayerName, localPlayerUID, natTraversalProvider, over, exitBehavior, playerHasSupcom)
    Reset()
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
        UIUtil.QuickDialog(GUI,
            "<LOC lobby_0000>Exit game lobby?",
            "<LOC _Yes>", function()
				ExitApplication()
                EscapeHandler.PopEscapeHandler()
            end,
            "<LOC _Cancel>", function()
            end,
            nil, nil,
            true
        )
    end
    EscapeHandler.PushEscapeHandler(GUI.exitLobbyEscapeHandler)
	GUI.connectdialog =  UIUtil.QuickDialog(GUI,
        "连接中...    尝试次数："..repr(conTimes),
        Strings.AbortConnect, function()
			ReturnToMenu(false)
			ExitApplication()
        end,
        "重新连接", function()
			ReturnToMenu(true)
        end,
        nil, nil,
        true
    )
	conTimes = conTimes + 1
    GUI.connectdialog.OnEscapePressed = function() end
    GUI.connectdialog.OnShadowClicked = function() end

    InitLobbyComm(protocol, localPort, desiredPlayerName, localPlayerUID, natTraversalProvider)

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

-- create the lobby as a host
function HostGame(desiredGameName, scenarioFileName, inSinglePlayer)
	scenarioFileName = argv.Map
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
		LOG('>> ConnectToPeer > name='..tostring(name))
    else
        DisconnectFromPeer(uid)
        #LOG("ConnectToPeer (name=" .. name .. ", uid=" .. uid .. ", address=" .. addressAndPort ..", USE PROXY)")
		LOG('>> ConnectToPeer > name='..tostring(name)..' (with PROXY)')
        table.insert(ConnectedWithProxy, uid)
    end
    lobbyComm:ConnectToPeer(addressAndPort,name,uid)
end

function DisconnectFromPeer(uid)
    #LOG("DisconnectFromPeer (uid=" .. uid ..")")
    if wasConnected(uid) then
        table.remove(connectedTo, uid)
    end
	LOG('>> DisconnectFromPeer > name='..tostring(FindNameForID(uid)))
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
    end

    local slot = GUI.slots[slotNum]
    local isHost = lobbyComm:IsHost()
    local isLocallyOwned = IsLocallyOwned(slotNum)

    -- Set enabledness of controls according to host privelage etc.
    -- Yeah, we set it twice. No, it's not brilliant. Blurgh.
    local facColEnabled = isLocallyOwned or (isHost and not playerInfo.Human)
	

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
    -- Disable team selection if "auto teams" is controlling it. Moderatelty ick.
    local autoTeams = gameInfo.GameOptions.AutoTeams

    local hostKey
    if isHost then
        hostKey = 'host'
    else
        hostKey = 'client'
    end

    -- These states are used to select the appropriate strings with GetSlotMenuTables.
    local slotState
    if not playerInfo.Human then
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
    slot.name:Hide()
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

    slot.faction:Hide()
    slot.faction:SetItem(playerInfo.Faction)

    slot.color:Hide()
    Check_Availaible_Color(slotNum)

    slot.team:Hide()
    slot.team:SetItem(playerInfo.Team)
	
    if isHost then
        HostSendPlayerSettingsToServer(slotNum)
    end

    UIUtil.setVisible(slot.ready, playerInfo.Human and not singlePlayer)
    slot.ready:SetCheck(playerInfo.Ready, true)

    -- Show the player's nationality
    if not playerInfo.Country then
        slot.KinderCountry:Hide()
    else
        slot.KinderCountry:Hide()
        slot.KinderCountry:SetTexture(UIUtil.UIFile('/countries/'..playerInfo.Country..'.dds'))

        Tooltip.AddControlTooltip(slot.KinderCountry, {text=LOC("<LOC lobui_0413>Country"), body=CountryTooltips[playerInfo.Country]})
    end

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

local function AssignRandomStartSpots()
    if gameInfo.GameOptions['TeamSpawn'] == 'random' then
        local numAvailStartSpots = nil
        local scenarioInfo = nil
        if gameInfo.GameOptions.ScenarioFile and (gameInfo.GameOptions.ScenarioFile != "") then
            scenarioInfo = MapUtil.LoadScenario(gameInfo.GameOptions.ScenarioFile)
        end
        if scenarioInfo then
            local armyTable = MapUtil.GetArmies(scenarioInfo)
            if armyTable then
                numAvailStartSpots = table.getn(armyTable)
            end
        else
            WARN("Can't assign random start spots, no scenario selected.")
            return
        end
        
        for i = 1, numAvailStartSpots do
            if gameInfo.PlayerOptions[i] then
                -- don't select closed slots for random pick
                local randSlot
                repeat
                    randSlot = math.random(1,numAvailStartSpots)
                until gameInfo.ClosedSlots[randSlot] == nil
                
                local temp = nil
                if gameInfo.PlayerOptions[randSlot] then
                    temp = table.deepcopy(gameInfo.PlayerOptions[randSlot])
                end
                gameInfo.PlayerOptions[randSlot] = table.deepcopy(gameInfo.PlayerOptions[i])
                gameInfo.PlayerOptions[i] = temp
            end
        end
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

    for i = 1, maxPlayerSlots do
        if not gameInfo.ClosedSlots[i] and gameInfo.PlayerOptions[i] then
            local correctTeam = getTeam(i)
            if gameInfo.PlayerOptions[i].Team ~= correctTeam then
                SetPlayerOption(i, "Team", correctTeam, true)
                SetSlotInfo(i, gameInfo.PlayerOptions[i])
            end
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

    exitfn()
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
    if numAvailStartSpots > maxPlayerSlots then
        WARN("Lobby requests " .. numAvailStartSpots .. " but there are only " .. maxPlayerSlots .. " available")
    end

    -- if number of available slots has changed, update it
    if numOpenSlots == numAvailStartSpots then
        return
    end

    numOpenSlots = 2
    for i = 1, numAvailStartSpots do
        if gameInfo.ClosedSlots[i] then
			-- FXF210417 修复位置显示bug
			--gameInfo.ClosedSlots[i] = nil							 
            GUI.slots[i]:Hide()
            if not gameInfo.PlayerOptions[i] then
                ClearSlotInfo(i)
            end
            if not gameInfo.PlayerOptions[i].Ready then
                EnableSlot(i)
            end
        end
    end

    for i = numAvailStartSpots + 1, maxPlayerSlots do
        DisableSlot(i)
        GUI.slots[i]:Hide()
        gameInfo.ClosedSlots[i] = true
    end
end

local function TryLaunch(skipNoObserversCheck)
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
    --if gameInfo.GameOptions['Victory'] ~= 'sandbox' and numTeams < 2 then
    --    AddChatText(LOC("<LOC lobui_0241>There must be more than one player or team or the Victory Condition must be set "..
    --            "to Sandbox."))
    --    return
    --end--FACN

    if numPlayers ~= 2 then--FACN
        AddChatText(LOC("<LOC lobui_0233>There are no players assigned to player slots, can not continue"))
        return
    end

    if not EveryoneHasEstablishedConnections() then
        return
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
                for k,observer in gameInfo.Observers:pairs() do
                    lobbyComm:EjectPeer(observer.OwnerID, "KickedByHost")
                end
                gameInfo.Observers = WatchedValueArray(maxPlayerSlots)
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
	for i = 1, maxPlayerSlots do
        if gameInfo.ClosedSlots[i] then
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
		
    
        -- Eliminate the WatchedValue structures.
        gameInfo = GameInfo.Flatten(gameInfo)

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
		
        local allRatings = {}
        for k,v in gameInfo.PlayerOptions do
			if v.Human then
				allRatings[v.PlayerName] = v.PScore
            end
        end
        gameInfo.GameOptions['Ratings'] = allRatings
		--存一下humaix数据到选项里
		local allHumaixBuildMult = {}
		local allHumaixCheatMult = {}
        for k,v in gameInfo.PlayerOptions do
            if v.Human and v.BuildMult and v.CheatMult then
                allHumaixBuildMult[v.PlayerName] = v.BuildMult
				allHumaixCheatMult[v.PlayerName] = v.CheatMult
            end
        end
        gameInfo.GameOptions['HumaixBuild'] = allHumaixBuildMult
		gameInfo.GameOptions['HumaixCheat'] = allHumaixCheatMult
		
        lobbyComm:BroadcastData({ Type = 'Launch', GameInfo = gameInfo })

        -- set the mods
        gameInfo.GameMods = Mods.GetGameMods(gameInfo.GameMods)

        scenarioInfo = MapUtil.LoadScenario(gameInfo.GameOptions.ScenarioFile)
        SetWindowedLobby(false)
        lobbyComm:LaunchGame(gameInfo)
    end
	LOG('*GameInfo:',repr(gameInfo.GameOptions))
	LOG('*GameVersion:'..repr(GameVersion()))
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

local function HostRefreshButtonEnabledness()
    -- disable options when all players are marked ready
    -- Is at least one person not ready?
    local playerNotReady = GetPlayersNotReady() ~= false

    -- Launch button enabled if everyone is ready.
end

local function UpdateGame()
    LOG('>> UpdateGame')
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
            GUI.mapView:Clear()
        end
    end

    local isHost = lobbyComm:IsHost()

    local localPlayerSlot = FindSlotForID(localPlayerID)
    if localPlayerSlot then
        local playerOptions = gameInfo.PlayerOptions[localPlayerSlot]

        -- Disable some controls if the user is ready.
        local notReady = not playerOptions.Ready

    end

    local numPlayers = GetPlayerCount()

    local numAvailStartSpots = maxPlayerSlots
    if scenarioInfo then
        local armyTable = MapUtil.GetArmies(scenarioInfo)
        if armyTable then
            numAvailStartSpots = table.getn(armyTable)
        end
    end

    UpdateAvailableSlots(numAvailStartSpots)

    -- Update all slots.
    for i = 1, maxPlayerSlots do
        if gameInfo.ClosedSlots[i] then
        else
            if gameInfo.PlayerOptions[i] then
                SetSlotInfo(i, gameInfo.PlayerOptions[i])
            else
                ClearSlotInfo(i)
            end
        end
    end
    HostRefreshButtonEnabledness()
    RefreshOptionDisplayData(scenarioInfo)

    -- Update the map background to reflect the possibly-changed map.
    if Prefs.GetFromCurrentProfile('LobbyBackground') == 4 then
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
    end

    -- If the large map is shown, update it.
    RefreshLargeMap()

end
--updata ver

local function HostUpdateVersion(newPlayerID, newPlayerName)

    if lobbyComm:IsHost() then
        
		
        local newVersion = GameVersion()
		local hostOL = argv.onlinecheck
		local reason = (LOCF('There is no reason 略略略'))
            LOG('>> IsHostrun')
			
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

			LOG('>> :EjectPeer' )
            lobbyComm:EjectPeer(newPlayerID, reason)
            
        end
    end
end

-- Holds some utility functions to do with game option management.
local OptionUtils = {
    -- Set all game options to their default values.
    SetLadderOptions = function()
        local options = {}
		for index, option in teamOpts do
			if option.key == 'TeamSpawn' then
				options[option.key] = option.values[4].key
			elseif option.key == 'AutoTeams' then
				options[option.key] = option.values[4].key
			else
				options[option.key] = option.values[option.default].key
			end
        end
		
        for index, option in globalOpts do
            options[option.key] = option.values[option.default].key
        end

        for index, option in AIOpts do
            options[option.key] = option.values[option.default].key
        end

        SetGameOptions(options)
    end
}

function SetSlotClosed(slot ,closed)
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
    LOG('>> HostTryAddPlayer > requestedPlayerName='..tostring(playerData.PlayerName))
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
    GUI.slots[slot].team:Enable()
    GUI.slots[slot].color:Enable()
    GUI.slots[slot].faction:Enable()
    GUI.slots[slot].ready:Enable()
end

function DisableSlot(slot, exceptReady)
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
    local COLUMN_POSITIONS = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    local COLUMN_WIDTHS = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}


    for i= 1, maxPlayerSlots do
        -- Capture the index in the current closure so it's accessible on callbacks
        local curRow = i

        -- The background is parented on the GUI so it doesn't vanish when we hide the slot.
        local slotBackground = Bitmap(GUI, nil)

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
            if event.Type == 'MouseExit' then
                associatedMarker.indicator:Stop()
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
        local flag = Bitmap(newSlot, nil)
        newSlot.KinderCountry = flag
        flag.Width:Set(COLUMN_WIDTHS[2])
        flag.Height:Set(15)
        newSlot:AddChild(flag)
	
		-- score(新分数系统)
		local scoreText = UIUtil.CreateText(newSlot, "", 14, 'Arial')
		newSlot.scoreText = scoreText
		scoreText:SetColor('B9BFB9')
		scoreText:SetDropShadow(true)
		newSlot:AddChild(scoreText)
		scoreText.Width:Set(COLUMN_WIDTHS[3])
		newSlot.tooltiprating = Tooltip.AddControlTooltip(scoreText, 'rating')
	
		--游戏数
		local gamenumText = UIUtil.CreateText(newSlot, "", 14, 'Arial')
		newSlot.gamenumText = gamenumText
		gamenumText:SetColor('B9BFB9')
		gamenumText:SetDropShadow(true)
		newSlot:AddChild(gamenumText)
		gamenumText.Width:Set(COLUMN_WIDTHS[4])
		newSlot.tooltiprating = Tooltip.AddControlTooltip(gamenumText, 'gamenum')
		
		
        -- Name
        local nameLabel = Combo(newSlot, 14, 12, true, nil, "UI_Tab_Rollover_01", "UI_Tab_Click_01")
        newSlot.name = nameLabel
        nameLabel._text:SetFont('Arial Gras', 15)
        newSlot:AddChild(nameLabel)
        nameLabel.Width:Set(COLUMN_WIDTHS[5])
		

        -- left deal with name clicks
        nameLabel.OnEvent = defaultHandler
        nameLabel.OnClick = function(self, index, text)
        end
		
	
        -- Color
        local colorSelector = BitmapCombo(newSlot, gameColors.PlayerColors, 1, true, nil, "UI_Tab_Rollover_01", "UI_Tab_Click_01")
        newSlot.color = colorSelector

        newSlot:AddChild(colorSelector)
        colorSelector.Width:Set(COLUMN_WIDTHS[6])
        colorSelector.OnClick = function(self, index)
            if not lobbyComm:IsHost() then
                lobbyComm:SendData(hostID, { Type = 'RequestColor', Color = index, Slot = curRow } )
                SetPlayerColor(gameInfo.PlayerOptions[curRow], index)
                UpdateGame()
            else
                self:SetItem( gameInfo.PlayerOptions[curRow].PlayerColor )
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

        local factionSelector = BitmapCombo(newSlot, factionBmps, table.getn(factionBmps), false, nil, "UI_Tab_Rollover_01", "UI_Tab_Click_01")
        newSlot.faction = factionSelector
        newSlot:AddChild(factionSelector)
        factionSelector.Width:Set(COLUMN_WIDTHS[7])

        -- Team
        local teamSelector = BitmapCombo(newSlot, teamIcons, 1, false, nil, "UI_Tab_Rollover_01", "UI_Tab_Click_01")
        newSlot.team = teamSelector

        -- Ping
        local pingGroup = Group(newSlot)
        newSlot.pingGroup = pingGroup

        local pingStatus = StatusBar(pingGroup, 0, 500, false, false,
            UIUtil.SkinnableFile('/game/unit_bmp/bar-back_bmp.dds'),
            UIUtil.SkinnableFile('/game/unit_bmp/bar-01_bmp.dds'),
            true)
        newSlot.pingStatus = pingStatus
       
        -- Ready Checkbox
        local readyBox = UIUtil.CreateCheckbox(newSlot, '/CHECKBOX/')
        newSlot.ready = readyBox

        newSlot.HideControls = function()
            -- hide these to clear slot of visible data
			scoreText:Hide()
			gamenumText:Hide()
            flag:Hide()
            factionSelector:Hide()
            colorSelector:Hide()
            readyBox:Hide()
            pingGroup:Hide()
        end
        newSlot.HideControls()

        if i == 1 then
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
    UIUtil.SetCurrentSkin("ladder")
	
	local parent = UIUtil.CreateScreenGroup(GetFrame(0), "Main Menu ScreenGroup")

    local backMovie = false
    if Prefs.GetOption("mainmenu_bgmovie") then
        backMovie = CreateBackMovie(parent)
    end
	
	local scanlines = Bitmap(parent, UIUtil.UIFile('/menus/main02-1600-1200/scan-lines_bmp.dds'))
    if backMovie then
        scanlines.Depth:Set(function() return backMovie.Depth() + 1 end)
    end
    LayoutHelpers.AtLeftTopIn(scanlines, parent)
    scanlines:SetTiled(true)
    LayoutHelpers.FillParent(scanlines, parent)
    scanlines:SetAlpha(0.3)

    local darker = Bitmap(scanlines)
    LayoutHelpers.FillParent(darker, parent)
    darker:SetSolidColor('200000')
    darker:SetAlpha(0.2)

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
    -- Player Slots
    GUI.playerPanel = Group(GUI.panel, "playerPanel")
    LayoutHelpers.AtLeftTopIn(GUI.playerPanel, GUI.panel, 6, 70)
    GUI.playerPanel.Width:Set(706)
    GUI.playerPanel.Height:Set(307)

    -- Map Preview
    GUI.mapPanel = Group(GUI.panel, "mapPanel")
	UIUtil.SurroundWithBorder(GUI.mapPanel, '/scx_menu/lan-game-lobby/frame/')
    LayoutHelpers.AtCenterIn(GUI.mapPanel, GUI.panel)
    GUI.mapPanel.Width:Set(300)
    GUI.mapPanel.Height:Set(300)
    LayoutHelpers.DepthOverParent(GUI.mapPanel, GUI.panel, 2)
	
	GUI.mapOut = Bitmap(GUI.panel, UIUtil.SkinnableFile("/BACKGROUND/ladder/Hide.dds"))
    UIUtil.SurroundWithBorder(GUI.mapOut, '/scx_menu/lan-game-lobby/frame/')
    LayoutHelpers.AtCenterIn(GUI.mapOut, GUI.mapPanel)
    GUI.mapOut.Width:Set(300)
    GUI.mapOut.Height:Set(300)
    LayoutHelpers.DepthOverParent(GUI.mapOut, GUI.mapPanel, 2)
	
	
    -- Map Name Label TODO: Localise!
    GUI.MapNameLabel = makeLabel("Loading...", 40)
	LayoutHelpers.AtHorizontalCenterIn(GUI.MapNameLabel, GUI.mapPanel)
    LayoutHelpers.AtBottomIn(GUI.MapNameLabel, GUI.mapPanel, -50)
	GUI.MapNameLabel:Hide()
	
	-- 匹配状态显示
    GUI.Waiting = makeLabel("匹配中...", 30)
	LayoutHelpers.AtHorizontalCenterIn(GUI.Waiting, GUI.mapPanel)
    LayoutHelpers.AtTopIn(GUI.Waiting, GUI.mapPanel, -60)
    ---------------------------------------------------------------------------
    -- set up map panel
    ---------------------------------------------------------------------------
    GUI.mapView = ResourceMapPreview(GUI.mapPanel, 300, 3, 5)
    LayoutHelpers.AtLeftTopIn(GUI.mapView, GUI.mapPanel, -1, -1)
    LayoutHelpers.DepthOverParent(GUI.mapView, GUI.mapPanel, -1)
	GUI.mapView:Hide()

    GUI.LargeMapPreview = UIUtil.CreateButtonWithDropshadow(GUI.mapPanel, '/BUTTON/zoom/', "")
    LayoutHelpers.AtRightIn(GUI.LargeMapPreview, GUI.mapPanel, -1)
    LayoutHelpers.AtBottomIn(GUI.LargeMapPreview, GUI.mapPanel, -1)
    LayoutHelpers.DepthOverParent(GUI.LargeMapPreview, GUI.mapPanel, 2)
    Tooltip.AddButtonTooltip(GUI.LargeMapPreview, 'lob_click_LargeMapPreview')
    GUI.LargeMapPreview.OnClick = function()
        CreateBigPreview(GUI)
    end

	---------------------------------------------------------------------------
    -- set up slot display
    ---------------------------------------------------------------------------
    -- Slot lable
	----------------------- main label ------------------------
    GUI.LadderSlotbgL = Bitmap(GUI.panel, UIUtil.SkinnableFile("/SLOT/Slot_main.dds"))
    LayoutHelpers.AtLeftIn(GUI.LadderSlotbgL, GUI.panel,-50)
	LayoutHelpers.AtVerticalCenterIn(GUI.LadderSlotbgL, GUI.panel)
    GUI.LadderSlotbgL.Width:Set(330)
    GUI.LadderSlotbgL.Height:Set(90)
	
	GUI.LadderSlotbgL_Avatar = Bitmap(GUI.LadderSlotbgL, UIUtil.SkinnableFile("/Avatar/Avatar_UEF_01.dds"))
    UIUtil.SurroundWithBorder(GUI.LadderSlotbgL_Avatar, '/scx_menu/lan-game-lobby/frame/')
    LayoutHelpers.AtLeftIn(GUI.LadderSlotbgL_Avatar, GUI.LadderSlotbgL, 5)
	LayoutHelpers.AtBottomIn(GUI.LadderSlotbgL_Avatar, GUI.LadderSlotbgL, 10)
    GUI.LadderSlotbgL_Avatar.Width:Set(75)
    GUI.LadderSlotbgL_Avatar.Height:Set(75)
	GUI.LadderSlotbgL_Avatar:SetTexture(UIUtil.SkinnableFile("/Avatar/Avatar_"..FACTION_NAMES[GetLocalPlayerData().Faction].."_01.dds"))
	
	GUI.LadderSlotbgL_Faction = Bitmap(GUI.LadderSlotbgL, UIUtil.SkinnableFile("/faction_icon-lg/random_ico.dds"))
    LayoutHelpers.AtRightIn(GUI.LadderSlotbgL_Faction, GUI.LadderSlotbgL, 5)
	LayoutHelpers.AtTopIn(GUI.LadderSlotbgL_Faction, GUI.LadderSlotbgL, 0)
    GUI.LadderSlotbgL_Faction.Width:Set(58)
    GUI.LadderSlotbgL_Faction.Height:Set(58)
	GUI.LadderSlotbgL_Faction:SetTexture(UIUtil.SkinnableFile("/faction_icon-lg/"..FACTION_NAMES[GetLocalPlayerData().Faction].."_ico.dds"))
	
	GUI.LadderSlotbgL_Name = makeLabel("Loading...", 23)
	LayoutHelpers.AtLeftIn(GUI.LadderSlotbgL_Name, GUI.LadderSlotbgL, 90)
    LayoutHelpers.AtTopIn(GUI.LadderSlotbgL_Name, GUI.LadderSlotbgL, 5)
	GUI.LadderSlotbgL_Name:SetText(localPlayerName)
	
	GUI.LadderSlotbgL_Rank = makeLabel("Rank: ?", 15)
	LayoutHelpers.AtLeftIn(GUI.LadderSlotbgL_Rank, GUI.LadderSlotbgL, 90)
    LayoutHelpers.AtTopIn(GUI.LadderSlotbgL_Rank, GUI.LadderSlotbgL, 35)
	GUI.LadderSlotbgL_Rank:SetText("Rank: "..tonumber(GetLocalPlayerData().PScore))
	----------------------- sec label ------------------------
	 GUI.LadderSlotbgR = Bitmap(GUI.panel, UIUtil.SkinnableFile("/SLOT/Slot_sec.dds"))
    LayoutHelpers.AtRightIn(GUI.LadderSlotbgR, GUI.panel,-50)
	LayoutHelpers.AtVerticalCenterIn(GUI.LadderSlotbgR, GUI.panel)
    GUI.LadderSlotbgR.Width:Set(330)
    GUI.LadderSlotbgR.Height:Set(90)
	
	GUI.LadderSlotbgR_Avatar = Bitmap(GUI.LadderSlotbgR, UIUtil.SkinnableFile("/Avatar/Avatar_random_01.dds"))
    UIUtil.SurroundWithBorder(GUI.LadderSlotbgR_Avatar, '/scx_menu/lan-game-lobby/frame/')
    LayoutHelpers.AtRightIn(GUI.LadderSlotbgR_Avatar, GUI.LadderSlotbgR, 5)
	LayoutHelpers.AtBottomIn(GUI.LadderSlotbgR_Avatar, GUI.LadderSlotbgR, 10)
    GUI.LadderSlotbgR_Avatar.Width:Set(75)
    GUI.LadderSlotbgR_Avatar.Height:Set(75)
	
	GUI.LadderSlotbgR_Faction = Bitmap(GUI.LadderSlotbgR, UIUtil.SkinnableFile("/faction_icon-lg/random_ico.dds"))
    LayoutHelpers.AtLeftIn(GUI.LadderSlotbgR_Faction, GUI.LadderSlotbgR, 5)
	LayoutHelpers.AtTopIn(GUI.LadderSlotbgR_Faction, GUI.LadderSlotbgR, 0)
    GUI.LadderSlotbgR_Faction.Width:Set(58)
    GUI.LadderSlotbgR_Faction.Height:Set(58)
	
	GUI.LadderSlotbgR_Name = makeLabel("等待中...", 23)
	LayoutHelpers.AtRightIn(GUI.LadderSlotbgR_Name, GUI.LadderSlotbgR, 90)
    LayoutHelpers.AtTopIn(GUI.LadderSlotbgR_Name, GUI.LadderSlotbgR, 5)
	
	GUI.LadderSlotbgR_Rank = makeLabel("Rank: ?", 15)
	LayoutHelpers.AtRightIn(GUI.LadderSlotbgR_Rank, GUI.LadderSlotbgR, 90)
    LayoutHelpers.AtTopIn(GUI.LadderSlotbgR_Rank, GUI.LadderSlotbgR, 35)
	
	
	
	
	
    -- Exit Button
    local launchGameButton = UIUtil.CreateButtonWithDropshadow(GUI.panel, '/BUTTON/large/', "Exit")
    GUI.launchGameButton = launchGameButton
	GUI.launchGameButton.label:SetText(LOC("<LOC _Exit>"))
    LayoutHelpers.AtHorizontalCenterIn(launchGameButton, GUI)
    LayoutHelpers.AtBottomIn(launchGameButton, GUI.panel, -8)
	GUI.launchGameButton.OnClick = GUI.exitLobbyEscapeHandler
	
    -- For disgusting reasons, we pass the label factory as a parameter.
    CreateSlotsUI(makeLabel)

  
    local lastFaction = GetSanitisedLastFaction()

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
                    local connectionStatus = CalcConnectionStatus(peer,gameInfo.PlayerOptions[slot])
					
                    if ping then
                        ping = math.floor(peer.ping)
                        GUI.slots[slot].pingStatus:SetValue(ping)
						GUI.slots[slot].pingStatus:Hide()

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
    GUI.uiCreated = true
	for slot = 3, maxPlayerSlots do
		SetSlotClosed(slot, not gameInfo.ClosedSlots[slot])
	end
	OptionUtils.SetLadderOptions()
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
function CalcConnectionStatus(peer,PlayerData)
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
			
			
			GUI.Waiting:SetText("匹配成功！")
			
			GUI.mapOut:Hide()
			GUI.mapView:Show()
			GUI.MapNameLabel:Show()
			
			
			GUI.LadderSlotbgR_Name:SetText(PlayerData.PlayerName)
			GUI.LadderSlotbgR_Rank:SetText("Rank: "..PlayerData.PScore)
			GUI.LadderSlotbgR_Avatar:SetTexture(UIUtil.SkinnableFile("/Avatar/Avatar_"..FACTION_NAMES[PlayerData.Faction].."_01.dds"))
			GUI.LadderSlotbgR_Faction:SetTexture(UIUtil.SkinnableFile("/faction_icon-lg/"..FACTION_NAMES[PlayerData.Faction].."_ico.dds"))
			
			if lobbyComm:IsHost() then
				local timer = 15
				AddChatText("警告！倒计时开始后退出游戏将算为失败！")
				LOG('*FACNLADDER START')
				while timer > 0 do
					if timer <= 10 then
						lobbyComm:BroadcastData(
                            {
                                Type = 'Count',
                                timer = timer,
                                }
                        )
						GUI.Waiting:SetText("游戏将在"..timer.."秒后开始")
					end
					timer = timer - 1
					WaitSeconds(1)
				end
				TryLaunch(true)--FACN
			end
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
        CreateUI(maxPlayerSlots)
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
        elseif data.Type == 'Count' then
            GUI.Waiting:SetText("游戏将在"..data.timer.."秒后开始")
        elseif data.Type == 'PrivateChat' then
            AddChatText("<<"..data.SenderName..">> "..data.Text)
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
			elseif data.Type == 'GameVersion' then
				checkVersion[data.SenderID]=data.Vers
            end
			HostUpdateVersion(data.SenderID, data.Name) --HostUpdateVersion
        else -- Non-host only messages			
            if data.Type == 'SetAllPlayerNotReady' then
                if not IsPlayer(localPlayerID) then
                    return
                end
                local localSlot = FindSlotForID(localPlayerID)
                EnableSlot(localSlot)
                GUI.becomeObserver:Enable()
                SetPlayerOption(localSlot, 'Ready', false)
            elseif data.Type == 'Peer_Really_Disconnected' then
				LOG('>> DATA RECEIVE : Peer_Really_Disconnected (slot:'..data.Slot..')')
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
            elseif data.Type == 'SetColor' then
                SetPlayerColor(gameInfo.PlayerOptions[data.Slot], data.Color)
                SetSlotInfo(data.Slot, gameInfo.PlayerOptions[data.Slot])
            elseif data.Type == 'GameInfo' then
                -- Completely update the game state. To be used exactly once: when first connecting.
                local hostFlatInfo = data.GameInfo
                gameInfo = GameInfo.CreateGameInfo(maxPlayerSlots, hostFlatInfo)
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
                        UIUtil.SetCurrentSkin("ladder")
                    end
                 end

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

    lobbyComm.GameLaunched = function(self)
        local player = lobbyComm:GetLocalPlayerID()
		if not lobbyComm:IsHost() then
			--LOG('*Test:',repr(Prefs.GetFromCurrentProfile('options')))
		
			LOG('*GameInfo:',repr(gameInfo.GameOptions))
			LOG('*GameVersion:'..repr(GameVersion()))
			for i = 1, maxPlayerSlots do
				if gameInfo.ClosedSlots[i] then
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

        CreateUI(maxPlayerSlots)
        UpdateGame()
    end

    lobbyComm.PeerDisconnected = function(self,peerName,peerID) -- Lost connection or try connect with proxy
		LOG('>> PeerDisconnected : peerName='..peerName..' peerID='..peerID)
        
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
        elseif key == 'ScenarioFile' then
            if gameInfo.GameOptions.ScenarioFile and (gameInfo.GameOptions.ScenarioFile ~= '') then
                -- Warn about attempts to load nonexistent maps.
                if not DiskGetFileInfo(gameInfo.GameOptions.ScenarioFile) then
                    AddChatText('The selected map does not exist.')
                else
                    local scenarioInfo = MapUtil.LoadScenario(gameInfo.GameOptions.ScenarioFile)
                end
            end
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
        LrgMap:Hide()
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

--------------------------------------------------
--  CPU GUI Functions
--------------------------------------------------
function CreateCPUMetricUI()
    --This function handles creation of the CPU benchmark UI elements (statusbars, buttons, tooltips, etc)
    local StatusBar = import('/lua/maui/statusbar.lua').StatusBar
    if not singlePlayer then
        for i= 1, maxPlayerSlots do
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
    end
end

function CreateBackMovie(parent)
    local backMovie = Movie(parent)
    backMovie:Set('/movies/FMV_menu.sfd')
    LayoutHelpers.AtCenterIn(backMovie, parent)

    backMovie:Loop(true)
    backMovie:Play()

    local movRatio = backMovie.Width() / backMovie.Height()
    backMovie.Width:Set(function()
        local thisWidth = math.ceil(parent.Height() * movRatio)
        local thisHeight = parent.Height()
        if thisWidth < parent.Width() then
            thisWidth = parent.Width()
            thisHeight = math.ceil(parent.Width() / movRatio)
        end
        backMovie.Height:Set(thisHeight)
        return thisWidth
    end)
    return backMovie
end

-- Write the given list of preset profiles to persistent storage.
function SavePresetsList(list)
    Prefs.SetToCurrentProfile("LobbyPresets", list)
    SavePreferences()
end

-- Create an input dialog with the given title and listener function.
function CreateInputDialog(parent, title, listener)
    local dialog = InputDialog(parent, title, listener)
    dialog.OnInput = listener
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
        for ii = 1, maxPlayerSlots do
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