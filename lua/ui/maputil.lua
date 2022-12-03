--*****************************************************************************
--* File: lua/modules/ui/maputil.lua
--* Author: Chris Blackwell
--* Summary: Functions for loading maps and map info
--*
--* Copyright © 2006 Gas Powered Games, Inc.  All rights reserved.
--*****************************************************************************

-- load a scenario based on a scenario file name
function LoadScenario(scenName)
    -- TODO - expose FILE_IsAbsolute and if it's not, add the path and the _scenario.lua

    if not DiskGetFileInfo(scenName) then
        return nil
    end

    local env = {}
    doscript('/lua/dataInit.lua', env)
    doscript(scenName, env)

    if not env.ScenarioInfo then
        return nil
    end

    -- Backward compatibility
    if env.version == 1 then
        local temp = env
        env = {
            ScenarioInfo = temp,
        }
    end

    local optionsFileName = string.sub(scenName, 1, string.len(scenName) - string.len("scenario.lua")) .. "options.lua"
    if DiskGetFileInfo(optionsFileName) then
        local optionsEnv = {}
        doscript(optionsFileName, optionsEnv)
        if optionsEnv.options ~= nil then
        env.ScenarioInfo.options = optionsEnv.options
        end
    end

    env.ScenarioInfo.file = scenName -- stuff the file name in so we have that
    return env.ScenarioInfo
end

-- the default scenario enumerator sort method
local function DefaultScenarioSorter(compa, compb)
    return string.upper(compa) < string.upper(compb)
end

-- given a scenario, determines if it can be played in skirmish mode
function IsScenarioPlayable(scenario)
    if not scenario.Configurations.standard.teams[1].armies then
        return false
    end

    return true
end

-- EnumerateScenarios returns an array of scenario names
--  nameFilter can be passed in to narrow the enumaration, for example
--      EnumerateScenarios("SCMP*") will find all maps that start with SCMP
--      if nameFilter is nil, all maps will be returned
--  sortFunc is a function which, given two scenario names, will return true for the file name to come first
--      if no sortFunc is defined the default sorter will be used
function EnumerateSkirmishScenarios(nameFilter, sortFunc)
    nameFilter = nameFilter or '*'
    sortFunc = sortFunc or DefaultScenarioSorter

    -- retrieve the map file names
    local scenFiles = DiskFindFiles('/maps', nameFilter .. '_scenario.lua')

    -- load each map in to a table and store in our data structure
    local scenarios = {}
    for index, fileName in scenFiles do
        local scen = LoadScenario(fileName)
        if IsScenarioPlayable(scen) and scen.type == "skirmish" then
            table.insert(scenarios, scen)
        end
    end

    -- sort based on name
    table.sort(scenarios, function(a, b) return sortFunc(a.name, b.name) end)

    return scenarios
end

-- given a scenario table, loads the save file and puts all the start positions in a table
-- I've made this function so it works with the old data format and the new
-- Returning an empty table means scenario data was ill formed
function GetStartPositions(scenario)
    local saveData = {}
    doscript('/lua/dataInit.lua', saveData)
    doscript(scenario.save, saveData)

    local armyPositions = {}

    -- try new data first
    if scenario.Configurations.standard and scenario.Configurations.standard.teams then
        -- find the "FFA" team
        for index, teamConfig in scenario.Configurations.standard.teams do
            if teamConfig.name and (teamConfig.name == 'FFA') then
                for armyIndex, armyName in teamConfig.armies do
                    armyPositions[armyName] = {}
                end
                break
            end
        end
        if table.getsize(armyPositions) == 0 then
            WARN("Unable to find FFA configuration in " .. scenario.file)
        end
    end

    -- try old data if nothing added to army positions
    if table.getsize(armyPositions) == 0 then
        -- figure out all the armies in this map
        -- make sure old data is there
        if scenario.Games then
            for index, game in scenario.Games do
                for k, army in game do
                    armyPositions[army] = {}
                end
            end
        end
    end

    -- if we found armies, then get the positions
    if table.getsize(armyPositions) > 0 then
        for army, position in armyPositions do
            if saveData.Scenario.MasterChain['_MASTERCHAIN_'].Markers[army] then
                pos = saveData.Scenario.MasterChain['_MASTERCHAIN_'].Markers[army].position
                -- x and z value are of interest so ignore y (index 2)
                position[1] = pos[1]
                position[2] = pos[3]
            else
                WARN("No initial position marker for army " .. army .. " found in " .. scenario.save)
                position[1] = 0
                position[2] = 0
            end
        end
    else
        WARN("No start positions defined in " .. scenario.file)
    end

    return armyPositions
end

-- enumerates and returns to key name for all the armies for this map
function GetArmies(scenario)
    local retArmies = nil

    if scenario.Configurations.standard and scenario.Configurations.standard.teams then
        -- find the "FFA" team
        for index, teamConfig in scenario.Configurations.standard.teams do
            if teamConfig.name and (teamConfig.name == 'FFA') then
                retArmies = teamConfig.armies
            end
            break
        end
    end

    if (retArmies == nil) or (table.getn(retArmies) == 0) then
        WARN("No starting armies defined in " .. scenario.file)
    end

    return retArmies
end
function GetExtraArmies(scenario)
    if scenario.Configurations.standard and scenario.Configurations.standard.teams then
        local teams = scenario.Configurations.standard.teams
        if teams.ExtraArmies then
            local armies = STR_GetTokens(teams.ExtraArmies,' ')
            return armies
        end
    end
end

--- Validate options provided by the scenario file.
-- This function prints warnings about any defects and attempts to correct them with sane defaults.
function ValidateScenarioOptions(scenarioOptions)
    -- Most maps just don't have any options.
    if not scenarioOptions then
        return true
    end

    local failed = false
    for k, optData in scenarioOptions do
        -- Verify that all options have a sane default.
        if optData.default <= 0 or optData.default > table.getn(optData.values) then
            WARN("Invalid default option value " .. tostring(optData.default))
            WARN("Remember: option defaults are 1-based indices into the `values' table, not values themselves")
            WARN("Offending option table:")
            table.print(optData)
            optData.default = 1
            failed = true
        end
    end

    return failed
end
