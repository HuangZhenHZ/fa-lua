# Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
#
# This is the sim-specific top-level lua initialization file. It is run at initialization time
# to set up all lua state for the sim.
#
# Initialization order within the sim:
#
#   1. __blueprints is filled in from preloaded data
#
#   2. simInit.lua [this file] runs. It sets up infrastructure necessary to make Lua classes work etc.
#
#   if starting a new session:
#
#     3a. ScenarioInfo is setup with info about the scenario
#
#     4a. SetupSession() is called
#
#     5a. Armies, brains, recon databases, and other underlying game facilities are created
#
#     6a. BeginSession() is called, which loads the actual scenario data and starts the game
#
#   otherwise (loading a old session):
#
#     3b. The saved lua state is deserialized
#

#===================================================================================
# Do global init and set up common global functions
#===================================================================================
doscript '/lua/globalInit.lua'

LOG('Active mods in sim: ', repr(__active_mods))

WaitTicks = coroutine.yield

function WaitSeconds(n)
    local ticks = math.max(1, n * 10)
    WaitTicks(ticks)
end

#===================================================================================
# Set up the sync table and some globals for use by scenario functions
#===================================================================================
doscript '/lua/SimSync.lua'
#===================================================================================
# This is held here because the Sync table is cleared between SetupSession() and BeginSession()
#===================================================================================
local syncStartPositions = false  



function ShuffleStartPositions(syncNewPositions)--Í¬²½Î»ÖÃ
    local markers = ScenarioInfo.Env.Scenario.MasterChain._MASTERCHAIN_.Markers
    local positionGroups = ScenarioInfo.Options.RandomPositionGroups
    local positions = {}
    if not positionGroups then
        return
    end

    for _, group in positionGroups do
        for _, num in group do
            local name = 'ARMY_' .. num
            local marker = markers[name]
            if marker and marker.position then
                positions[num] = {pos = marker.position, name = name}
            end
        end

        local shuffledGroup = table.shuffle(group)
        for i = 1, table.getn(group) do
            local pos = positions[shuffledGroup[i]].pos
            local name = positions[group[i]].name
            if pos and markers[name] then
                markers[name].position = pos

                if syncNewPositions then
                    syncStartPositions[name] = pos
                end
            end
        end
    end
end
#===================================================================================
#SetupSession will be called by the engine after ScenarioInfo is set
#but before any armies are created.
#===================================================================================

function SetupSession()


    # LOG('SetupSession: ', repr(ScenarioInfo))

    ArmyBrains = {}

    #===================================================================================
    # ScenarioInfo is a table filled in by the engine with fields from the _scenario.lua
    # file we're using for this game. We use it to store additional global information
    # needed by our scenario.
    #===================================================================================
    ScenarioInfo.PlatoonHandles = {}
    ScenarioInfo.UnitGroups = {}
    ScenarioInfo.UnitNames = {}
    
    ScenarioInfo.VarTable = {}
    ScenarioInfo.OSPlatoonCounter = {}
    ScenarioInfo.BuilderTable = { Air = {}, Land = {}, Sea = {}, Gate = {} }
    ScenarioInfo.BuilderTable.AddedPlans = {}
    ScenarioInfo.MapData = { PathingTable = { Amphibious = {}, Water = {}, Land = {}, }, IslandData = {} }


    #===================================================================================
    # ScenarioInfo.Env is the environment that the save file and scenario script file
    # are loaded into.
    #
    # We set it up here with some default functions that can be accessed from the
    # scenario script.
    #===================================================================================
    ScenarioInfo.Env = import('/lua/scenarioEnvironment.lua')


    #===========================================================================
    # Load the scenario save and script files
    #
    # The save file creates a table named "Scenario" in ScenarioInfo.Env,
    # containing most of the save data. We'll copy it up to a top-level global.
    #===========================================================================
    LOG('Loading save file: ',ScenarioInfo.save)
    doscript('/lua/dataInit.lua')
    doscript(ScenarioInfo.save, ScenarioInfo.Env)

    Scenario = ScenarioInfo.Env.Scenario
	
	local spawn = ScenarioInfo.Options.TeamSpawn
    if spawn and table.find({'random_reveal', 'balanced_reveal', 'balanced_flex_reveal'}, spawn) then
        -- Shuffles positions like normal but syncs the new positions to the UI
        syncStartPositions = {}
        ShuffleStartPositions(true)
    elseif spawn and table.find({'random', 'balanced', 'balanced_flex', 'balances_smurf', 'nomal_smurf'}, spawn) then
        -- Prevents players from knowing start positions at start
        ShuffleStartPositions(false)
    end
	
    LOG('Loading script file: ',ScenarioInfo.script)
    doscript(ScenarioInfo.script, ScenarioInfo.Env)

    ResetSyncTable()

end


#===================================================================================
# Army Brains
#
# OnCreateArmyBrain() is called by then engine as the brains are created, and we
# use it to store off various useful bits of info.
#
# The global variable "ArmyBrains" contains an array of AI brains, one for each army.
#===================================================================================
function OnCreateArmyBrain(index, brain, name, nickname)
    #LOG(string.format("OnCreateArmyBrain %d %s %s",index,name,nickname))
    ArmyBrains[index] = brain
    ArmyBrains[index].Name = name
    ArmyBrains[index].Nickname = nickname
    ScenarioInfo.PlatoonHandles[index] = {}
    ScenarioInfo.UnitGroups[index] = {}
    ScenarioInfo.UnitNames[index] = {}

    InitializeArmyAI(name)
    #brain:InitializePlatoonBuildManager()
    #ScenarioUtils.LoadArmyPBMBuilders(name)
    #LOG('*SCENARIO DEBUG: ON POP, ARMY BRAINS = ', repr(ArmyBrains))
end

function InitializePrebuiltUnits(name)
    ArmyInitializePrebuiltUnits(name)
end

#===================================================================================
# BeginSession will be called by the engine after the armies are created (but without
# any units yet) and we're ready to start the game. It's responsible for setting up
# the initial units and any other gameplay state we need.
#===================================================================================
function BeginSession()

    local focusarmy = GetFocusArmy()
    if focusarmy>=0 and ArmyBrains[focusarmy] then
        LocGlobals.PlayerName = ArmyBrains[focusarmy].Nickname
    end

    # Pass ScenarioInfo into OnPopulate() and OnStart() for backwards compatibility
    ScenarioInfo.Env.OnPopulate(ScenarioInfo)
    ScenarioInfo.Env.OnStart(ScenarioInfo)

    # Look for teams
    local teams = {}
    for name,army in ScenarioInfo.ArmySetup do
        if army.Team > 1 then
            if not teams[army.Team] then
                teams[army.Team] = {}
            end
			
			--log output
			if   string.lower(ArmyBrains[army.ArmyIndex].BrainType) == 'human'  then
				LOG("*PlayInfo:{")
				LOG("	PlayerName:\""..ArmyBrains[army.ArmyIndex].Nickname.."\"")
				LOG("	PlayerArmy:"..army.ArmyIndex)
				LOG("	PlayerTeam:"..army.Team)
				LOG("}")
			else
				LOG("*AIGAME")
			end
            table.insert(teams[army.Team],army.ArmyIndex)
        end
    end

    if ScenarioInfo.Options.TeamLock == 'locked' then
        # Specify that the teams are locked.  Parts of the diplomacy dialog will
        # be disabled.
        ScenarioInfo.TeamGame = true
        Sync.LockTeams = true
    end

    # if build restrictions chosen, set them up
    local buildRestrictions = nil
    if ScenarioInfo.Options.RestrictedCategories then
        local restrictedUnits = import('/lua/ui/lobby/restrictedUnitsData.lua').restrictedUnits
        for index, restriction in ScenarioInfo.Options.RestrictedCategories do
		LOG('1 - '..restriction..' ['..index..']')
            local restrictedCategories = nil
            if restrictedUnits[restriction].categories then
				for index, cat in restrictedUnits[restriction].categories do
					LOG('2 - '..cat..' ['..index..']')
					if restrictedCategories == nil then
						restrictedCategories = categories[cat]
					else
						restrictedCategories = restrictedCategories + categories[cat]
					end
					LOG('2 - <<<')
				end
				LOG('1 - <<<')
				if buildRestrictions == nil then
					buildRestrictions = restrictedCategories
				else
					buildRestrictions = buildRestrictions + restrictedCategories
				end
				LOG('0 - <<<')
			end
        end
    end

    if buildRestrictions then
        local tblArmies = ListArmies()
        for index, name in tblArmies do
            AddBuildRestriction(index, buildRestrictions)
        end
    end

    # Set up the teams we found
    for team,armyIndices in teams do
        for k,index in armyIndices do
            for k2,index2 in armyIndices do
                SetAlliance(index,index2,"Ally")
            end
            ArmyBrains[index].RequestingAlliedVictory = true
        end
    end
    
    # Create any effect markers on map
    local markers = import('/lua/sim/ScenarioUtilities.lua').GetMarkers()
    local Entity = import('/lua/sim/Entity.lua').Entity
    local EffectTemplate = import ('/lua/EffectTemplates.lua')
    if markers then
        for k, v in markers do
            if v.type == 'Effect' then
                local EffectMarkerEntity = Entity()
                Warp( EffectMarkerEntity, v.position )   
                EffectMarkerEntity:SetOrientation(OrientFromDir(v.orientation), true)   
                for k, v in EffectTemplate [v.EffectTemplate] do        
					CreateEmitterAtBone(EffectMarkerEntity,-2,-1,v):ScaleEmitter(v.scale or 1):OffsetEmitter(v.offset.x or 0, v.offset.y or 0, v.offset.z or 0)
				end
            end
        end
    end

		
	
#for off-map prevention
    OnStartOffMapPreventionThread()
	

	if syncStartPositions then --Í¬²½Î»ÖÃ¸øUI
        Sync.StartPositions = syncStartPositions
    end
	if ScenarioInfo.type ~= 'campaign' then
		if ScenarioInfo.Options.LandT4First ~= 'Off' then --??T4??T4
	    RestrictionKongT4()
		end
		if ScenarioInfo.Options.AntinukeFirst ~= 'Off' then --??????
	    RestrictionT3Nuke()
		end
	--???????
	--??:???????bp,???????,??????
	TerminatorSelect(ScenarioInfo.Options.Terminator)
	
	import('/lua/openmsg.lua').OpenMessage()
	end
end
#===================================================================================
--ÉèÖÃ×Ô¶¯ai
#===================================================================================
--[[
	if   string.lower(AIBrain.BrainType) ~= 'human'  then
		if self:GetAIBrain().CheatEnabled then
			ScenarioFramework.CreateTimerTrigger(AUTOAI1Reminder1, 60)
		end
	end
	--]]
------------------------
###for off-map prevention
function OnStartOffMapPreventionThread()
	OffMappingPreventThread = ForkThread( import('/lua/ScenarioFramework.lua').AntiOffMapMainThread)
	ScenarioInfo.OffMapPreventionThreadAllowed = true
	#WARN('success')
end


#===================================================================================
--Terminator
#===================================================================================
function TerminatorSelect(TerNum)
    local tblArmies = ListArmies()
    for index, name in tblArmies do
		--1.5
		if TerNum == '1.5' then
			--1.0 ban
			import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.ORGTERMINATOR)
			--1.25 ban
			import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.ATYPETER)
			--2.0 ban
			import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.DOUBLECOST)
		--1.25
		elseif TerNum == '1.25' then
			--1.0 ban
			import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.ORGTERMINATOR)
			--1.5 ban
			import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.OPFCOST)
			--2.0 ban
			import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.DOUBLECOST)
		--2.0
		elseif TerNum == '2.0' then
			--1.0 ban
			import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.ORGTERMINATOR)
			--1.25 ban
			import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.ATYPETER)
			--1.5 ban
			import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.OPFCOST)
		--1.0
		else
			--1.5 ban
			import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.OPFCOST)
			--1.25 ban
			import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.ATYPETER)
			--2.0 ban
			import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.DOUBLECOST)
		end
    end
	#WARN('success')
end
-------



#===================================================================================
--ÏÈÂ½T4ÔÙ¿ÕT4
#===================================================================================
function RestrictionKongT4()

    local tblArmies = ListArmies()
    for index, name in tblArmies do
	import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.uaa0310)
	import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.ura0401)
	import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.xsa0402)
    ScenarioRestrictionKongT4(index)
    end
	#WARN('success')
end
function ScenarioRestrictionKongT4(humplayer)
local Objectives = import('/lua/ScenarioFramework.lua').Objectives
ScenarioInfo.RAT4 = Objectives.ArmyStatCompare(
        'secondary',                      
        'incomplete',                   
        'Restriction Air T4',     
        'Land T4 First',      
        'build',                        
        {                               
            Army = humplayer,
            StatName = 'Units_Active',
            CompareOp = '>=',
            Value = 1,
            Category = categories.ual0401 + categories.uel0401 + categories.url0401 + categories.url0402 + categories.xrl0403 + categories.xsl0401,
            ShowProgress = true,
        }
   )
    ScenarioInfo.RAT4:AddResultCallback(
        function()
            RemoveBuildRestriction(humplayer, categories.uaa0310)
			RemoveBuildRestriction(humplayer, categories.ura0401)
			RemoveBuildRestriction(humplayer, categories.xsa0402)
        end
   )
end
-------
#===================================================================================
--ÏÈ·´ºËÔÙºËµ¯
#===================================================================================
function RestrictionT3Nuke()

    local tblArmies = ListArmies()
    for index, name in tblArmies do
	import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.uab2305)
	import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.ueb2305)
	import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.urb2305)
	import('/lua/ScenarioFramework.lua').AddRestriction(index, categories.xsb2305)
    ScenarioRestrictionT3Nuke(index)
    end
	#WARN('success')
end
function ScenarioRestrictionT3Nuke(humplayer)
local Objectives = import('/lua/ScenarioFramework.lua').Objectives
ScenarioInfo.RAT3Nuke = Objectives.ArmyStatCompare(
        'secondary',                      
        'incomplete',                   
        'Restriction T3Nuke',     
        'Antinuke First',      
        'build',                        
        {                               
            Army = humplayer,
            StatName = 'Units_Active',
            CompareOp = '>=',
            Value = 1,
            Category = categories.uab4302 + categories.ueb4302 + categories.urb4302 + categories.xsb4302,
            ShowProgress = true,
        }
   )
    ScenarioInfo.RAT3Nuke:AddResultCallback(
        function()
            RemoveBuildRestriction(humplayer, categories.uab2305)
			RemoveBuildRestriction(humplayer, categories.ueb2305)
			RemoveBuildRestriction(humplayer, categories.urb2305)
			RemoveBuildRestriction(humplayer, categories.xsb2305)
        end
   )
end
-------

#===================================================================================
# OnPostLoad called after loading a saved game
#===================================================================================
function OnPostLoad()
end

#===========================================================================
# Set up list of files to prefetch
#===========================================================================
Prefetcher = CreatePrefetchSet()

function DefaultPrefetchSet()
    local set = { models = {}, anims = {}, d3d_textures = {} }

#    for k,file in DiskFindFiles('/units/*.scm') do
#        table.insert(set.models,file)
#    end

#    for k,file in DiskFindFiles('/units/*.sca') do
#        table.insert(set.anims,file)
#    end

#    for k,file in DiskFindFiles('/units/*.dds') do
#        table.insert(set.d3d_textures,file)
#    end

    return set
end

Prefetcher:Update(DefaultPrefetchSet())