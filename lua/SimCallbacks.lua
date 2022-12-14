---- 
---- 
---- This module contains the Sim-side lua functions that can be invoked
---- from the user side.  These need to validate all arguments against
---- cheats and exploits.
----
--
---- We store the callbacks in a sub-table (instead of directly in the
---- module) so that we don't include any

local Callbacks = {}

function DoCallback(name, data, units)
    local fn = Callbacks[name];
    if fn then
        fn(data, units)
    else
        error('No callback named ' .. repr(name))
    end
end

function SecureUnits(units)
    local secure = {}
    if units and type(units) ~= 'table' then
        units = {units}
    end

    for _, u in units or {} do
        if not IsEntity(u) then
            u = GetEntityById(u)
        end

        if IsEntity(u) and OkayToMessWithArmy(u:GetArmy()) then
            table.insert(secure, u)
        end
    end

    return secure
end

local SimUtils = import('/lua/SimUtils.lua')
local SimPing = import('/lua/SimPing.lua')
local SimTriggers = import('/lua/scenariotriggers.lua')
local SUtils = import('/lua/ai/sorianutilities.lua')
local LetterArray = { ["Aeon"] = "ua", ["UEF"] = "ue", ["Cybran"] = "ur", ["Seraphim"] = "xs" }
Callbacks.BreakAlliance = SimUtils.BreakAlliance

Callbacks.GiveUnitsToPlayer = SimUtils.GiveUnitsToPlayer

Callbacks.GiveResourcesToPlayer = SimUtils.GiveResourcesToPlayer

Callbacks.SetResourceSharing = SimUtils.SetResourceSharing

Callbacks.RequestAlliedVictory = SimUtils.RequestAlliedVictory

Callbacks.SetOfferDraw = SimUtils.SetOfferDraw

Callbacks.SpawnPing = SimPing.SpawnPing

--Nuke Ping
Callbacks.SpawnSpecialPing = SimPing.SpawnSpecialPing

Callbacks.UpdateMarker = SimPing.UpdateMarker

Callbacks.FactionSelection = import('/lua/ScenarioFramework.lua').OnFactionSelect

Callbacks.ToggleSelfDestruct = import('/lua/selfdestruct.lua').ToggleSelfDestruct

Callbacks.MarkerOnScreen = import('/lua/simcameramarkers.lua').MarkerOnScreen

Callbacks.SimDialogueButtonPress = import('/lua/SimDialogue.lua').OnButtonPress

Callbacks.AIChat = SUtils.FinishAIChat

Callbacks.DiplomacyHandler = import('/lua/SimDiplomacy.lua').DiplomacyHandler

--For area command    --LinLin 221128 FACN
Callbacks.AreaCommandCallback = import('/lua/Area Commands/areacommands.lua').AreaCommand

Callbacks.AreaCommandRebuildCallback = import('/lua/Area Commands/areacommands.lua').AreaCommandRebuild

Callbacks.DrawRectangle = import('/lua/Area Commands/areacommands.lua').DrawRectangle

Callbacks.ClearBuildArea = import('/lua/Area Commands/areacommands.lua').ClearBuildArea



--Callbacks.GetUnitHandle = import('/lua/debugai.lua').GetHandle

function Callbacks.OnMovieFinished(name)
    ScenarioInfo.DialogueFinished[name] = true
end
Callbacks.CapMex = function(data, units)
	ForkThread(PrintCake,'Callbacks.CapMex = function(data, units)')
    local units = EntityCategoryFilterDown(categories.ENGINEER, SecureUnits(units))
    if not units[1] then return end
	ForkThread(PrintCake,'Callbacks.CapMex = function(data, units)if not units[1] then return end')
    local mex = GetEntityById(data.target)
    if not mex or not EntityCategoryContains(categories.MASSEXTRACTION * categories.STRUCTURE, mex) then return end
    if mex:GetCurrentLayer() == 'Seabed' then return end
	ForkThread(PrintCake,'if mex:GetCurrentLayer()')
    local pos = mex:GetPosition()
    local msid
    for _, u in units do
        msid = LetterArray[u:GetBlueprint().General.FactionName]..'b1106'
		ForkThread(PrintCake,'for _, u in units do')
        IssueBuildMobile({u}, Vector(pos.x, pos.y, pos.z-2), msid, {})
        IssueBuildMobile({u}, Vector(pos.x+2, pos.y, pos.z), msid, {})
        IssueBuildMobile({u}, Vector(pos.x, pos.y, pos.z+2), msid, {})
        IssueBuildMobile({u}, Vector(pos.x-2, pos.y, pos.z), msid, {})
		ForkThread(PrintCake,'IssueBuildMobile({u}, Vector(pos.x-2, pos.y, pos.z), msid, {})o')
    end
end
Callbacks.OnControlGroupAssign = function(units)
    if ScenarioInfo.tutorial then
        local function OnUnitKilled(unit)
            if ScenarioInfo.ControlGroupUnits then
                for i,v in ScenarioInfo.ControlGroupUnits do
                   if unit == v then
                        table.remove(ScenarioInfo.ControlGroupUnits, i)
                   end 
                end
            end
        end


        if not ScenarioInfo.ControlGroupUnits then
            ScenarioInfo.ControlGroupUnits = {}
        end
        
        -- add units to list
        local entities = {}
        for k,v in units do
            table.insert(entities, GetEntityById(v))
        end
        ScenarioInfo.ControlGroupUnits = table.merged(ScenarioInfo.ControlGroupUnits, entities)

        -- remove units on death
        for k,v in entities do
            SimTriggers.CreateUnitDeathTrigger(OnUnitKilled, v)
            SimTriggers.CreateUnitReclaimedTrigger(OnUnitKilled, v) --same as killing for our purposes   
        end
    end
end

Callbacks.OnControlGroupApply = function(units)
    --LOG(repr(units))
end

local SimCamera = import('/lua/SimCamera.lua')

Callbacks.OnCameraFinish = SimCamera.OnCameraFinish




local SimPlayerQuery = import('/lua/SimPlayerQuery.lua')

Callbacks.OnPlayerQuery = SimPlayerQuery.OnPlayerQuery

Callbacks.OnPlayerQueryResult = SimPlayerQuery.OnPlayerQueryResult

Callbacks.PingGroupClick = import('/lua/SimPingGroup.lua').OnClickCallback

PrintCake = function(UBBBPID)
	
	
	
end

Callbacks.AddTarget = function(data, units)
end

Callbacks.ClearTargets = function(data, units)
end

Callbacks.GiveOrders = import('/lua/spreadattack.lua').GiveOrders



Callbacks.ValidateAssist = function(data, units)
    units = SecureUnits(units)
    local target = GetEntityById(data.target)
    if units and target then
        for k, u in units do
            if IsEntity(u) and u:GetArmy() == target:GetArmy() and IsInvalidAssist(u, target) then
                IssueClearCommands({target})
                return
            end
        end
    end
end

function IsInvalidAssist(unit, target)
    if target and target:GetEntityId() == unit:GetEntityId() then
        return true
    elseif not target or not target:GetGuardedUnit() then
        return false
    else
        return IsInvalidAssist(unit, target:GetGuardedUnit())
    end
end