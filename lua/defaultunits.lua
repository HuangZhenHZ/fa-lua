-- ****************************************************************************
-- **
-- **  File     :  /lua/defaultunits.lua
-- **  Author(s):  John Comes, Gordon Duclos
-- **
-- **  Summary  :  Default definitions of units
-- **
-- **  Copyright � 2005 Gas Powered Games, Inc.  All rights reserved.
-- ****************************************************************************

local Unit = import('/lua/sim/Unit.lua').Unit
local Shield = import('shield.lua').Shield
local explosion = import('defaultexplosions.lua')
local Util = import('utilities.lua')
local EffectUtil = import('EffectUtilities.lua')
local EffectTemplate = import('/lua/EffectTemplates.lua')
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local EffectUtil = import('EffectUtilities.lua')
local Entity = import('/lua/sim/Entity.lua').Entity
local Buff = import('/lua/sim/Buff.lua')
local AdjacencyBuffs = import('/lua/sim/AdjacencyBuffs.lua')

local CreateBuildCubeThread = EffectUtil.CreateBuildCubeThread
local CreateAeonBuildBaseThread = EffectUtil.CreateAeonBuildBaseThread

local CreateScaledBoom = function(unit, overkill, bone)
    explosion.CreateDefaultHitExplosionAtBone(
        unit,
        bone or 0,
        explosion.CreateUnitExplosionEntity(unit, overkill).Spec.BoundingXZRadius
    )
end

-----------------------------------------------------------------
--  MISC UNITS
-----------------------------------------------------------------
DummyUnit = Class(Unit) {
    OnStopBeingBuilt = function(self,builder,layer)
        self:Destroy()
    end,
}

-----------------------------------------------------------------
--  STRUCTURE UNITS
-----------------------------------------------------------------
StructureUnit = Class(Unit) {
    LandBuiltHiddenBones = {'Floatation'},
    MinConsumptionPerSecondEnergy = 1,
    MinWeaponRequiresEnergy = 0,

    -- Stucture unit specific damage effects and smoke
    FxDamage1 = { EffectTemplate.DamageStructureSmoke01, EffectTemplate.DamageStructureSparks01 },
    FxDamage2 = { EffectTemplate.DamageStructureFireSmoke01, EffectTemplate.DamageStructureSparks01 },
    FxDamage3 = { EffectTemplate.DamageStructureFire01, EffectTemplate.DamageStructureSparks01 },

    OnCreate = function(self)
        Unit.OnCreate(self)
        self.WeaponMod = {}
        self.FxBlinkingLightsBag = {}
        if self:GetCurrentLayer() == 'Land' and self:GetBlueprint().Physics.FlattenSkirt then
            self:FlattenSkirt()
            -- Units creating structure units tell unit to create the tarmac.
            -- This left here to help with F2 unit creation and testing.
            -- self:CreateTarmac(true, true, true, false, false)
        end
    end,

	-- rotate gun to enemy when built  LinLin 2020-5-9 FAFversion:3652 --
	--[[ --FXF210224
	 RotateTowardsEnemy = function(self)
        local bp = self:GetBlueprint()
        local army = self:GetArmy()
        local brain = self:GetAIBrain()
        local pos = self:GetPosition()
        local x, y = GetMapSize()
        local threats = {{pos={x/2, 0, y/2}, dist=VDist2(pos[1], pos[3], x, y), threat=-1}}
        local cats = EntityCategoryContains(categories.ANTIAIR, self) and categories.AIR or (categories.STRUCTURE+categories.LAND+categories.NAVAL)

        local units = brain:GetUnitsAroundPoint(cats, pos, 2*(bp.AI.GuardScanRadius or 100), 'Enemy')
        for _, u in units do
            local blip = u:GetBlip(army)
            if blip then
                local on_radar = blip:IsOnRadar(army)
                local seen = blip:IsSeenEver(army)

                if on_radar or seen then
                    local epos = u:GetPosition()
                    local threat = seen and (u:GetBlueprint().Defense.SurfaceThreatLevel or 0) or 1

                    table.insert(threats, {pos=epos, threat=threat, dist=VDist2(pos[1], pos[3], epos[1], epos[3])})
                end
            end
        end

        table.sort(threats,function(a, b)
            if a.threat <= 0 and b.threat <= 0 then
                return a.threat == b.threat and a.dist < b.dist or a.threat > b.threat
            elseif a.threat <= 0 then return false
            elseif b.threat <= 0 then return true
            else return a.dist < b.dist end
        end)

        local t = threats[1]
        local rad = math.atan2(t.pos[1]-pos[1], t.pos[3]-pos[3])
        local degrees = rad * (180 / math.pi)

        if EntityCategoryContains(categories.ARTILLERY * (categories.TECH3+categories.EXPERIMENTAL), self) then
            degrees = math.floor((degrees+45) / 90) * 90
        end

        self:SetRotation(degrees)
    end,
	
	
	 OnStartBeingBuilt = function(self, builder, layer)
        if EntityCategoryContains(categories.STRUCTURE * (categories.DIRECTFIRE + categories.INDIRECTFIRE + categories.ANTINAVY) * (categories.DEFENSE + categories.ARTILLERY), self) then
            self:RotateTowardsEnemy()
        end

        Unit.OnStartBeingBuilt(self, builder, layer)
    end,	
--]]	
    OnStopBeingBuilt = function(self,builder,layer)
        Unit.OnStopBeingBuilt(self,builder,layer)
        self:PlayActiveAnimation()
    end,

    OnFailedToBeBuilt = function(self)
        Unit.OnFailedToBeBuilt(self)
        self:DestroyTarmac()
    end,

    FlattenSkirt = function(self)
        local x, y, z = unpack(self:GetPosition())
        local x0,z0,x1,z1 = self:GetSkirtRect()
        x0,z0,x1,z1 = math.floor(x0),math.floor(z0),math.ceil(x1),math.ceil(z1)
        FlattenMapRect(x0, z0, x1-x0, z1-z0, y)
    end,

    CreateTarmac = function(self, albedo, normal, glow, orientation, specTarmac, lifeTime)
        if self:GetCurrentLayer() ~= 'Land' then return end
        local tarmac
        local bp = self:GetBlueprint().Display.Tarmacs
        if not specTarmac then
            if bp and table.getn(bp) > 0 then
                local num = Random(1, table.getn(bp))
                --LOG('*DEBUG: NUM + ', repr(num))
                tarmac = bp[num]
            else
                return false
            end
        else
            tarmac = specTarmac
        end

        local army = self:GetArmy()
        local w = tarmac.Width
        local l = tarmac.Length
        local fadeout = tarmac.FadeOut

        local x, y, z = unpack(self:GetPosition())

        -- I'm disabling this for now since there are so many things wrong with it.
        -- SetTerrainTypeRect(self.tarmacRect, {TypeCode= (aiBrain:GetFactionIndex() + 189) } )
        local orient = orientation
        if not orientation then
            if tarmac.Orientations and table.getn(tarmac.Orientations) > 0 then
                orient = tarmac.Orientations[Random(1, table.getn(tarmac.Orientations))]
                orient = (0.01745 * orient)
            else
                orient = 0
            end
        end

        if not self.TarmacBag then
            self.TarmacBag = {
                Decals = {},
                Orientation = orient,
                CurrentBP = tarmac,
            }
        end

        local GetTarmac = import('/lua/tarmacs.lua').GetTarmacType

        local terrain = GetTerrainType(x, z)
        local terrainName
        if terrain then
            terrainName = terrain.Name
        end
        -- Players and AI can build buildings outside of their faction. Get the *building's* faction to determine the correct tarrain-specific tarmac
        local factionTable = {e=1, a=2, r=3, s=4}
        local faction  = factionTable[string.sub(self:GetUnitId(),2,2)]

        if albedo and tarmac.Albedo then
            local albedo2 = tarmac.Albedo2
            if albedo2 then
                albedo2 = albedo2 .. GetTarmac(faction, terrain)
            end

            local tarmacHndl = CreateDecal(self:GetPosition(), orient, tarmac.Albedo .. GetTarmac(faction, terrainName) , albedo2 or '', 'Albedo', w, l, fadeout, lifeTime or 0, army, 0)
            table.insert(self.TarmacBag.Decals, tarmacHndl)
            if tarmac.RemoveWhenDead then
                self.Trash:Add(tarmacHndl)
            end
        end
        if normal and tarmac.Normal then
            local tarmacHndl = CreateDecal(self:GetPosition(), orient, tarmac.Normal .. GetTarmac(faction, terrainName), '', 'Alpha Normals', w, l, fadeout, lifeTime or 0, army, 0)

            table.insert(self.TarmacBag.Decals, tarmacHndl)
            if tarmac.RemoveWhenDead then
                self.Trash:Add(tarmacHndl)
            end
        end
        if glow and tarmac.Glow then
            local tarmacHndl = CreateDecal(self:GetPosition(), orient, tarmac.Glow .. GetTarmac(faction, terrainName), '', 'Glow', w, l, fadeout, lifeTime or 0, army, 0)

            table.insert(self.TarmacBag.Decals, tarmacHndl)
            if tarmac.RemoveWhenDead then
                self.Trash:Add(tarmacHndl)
            end
        end
    end,

    DestroyTarmac = function(self)
        if not self.TarmacBag then return end
        for k, v in self.TarmacBag.Decals do
            v:Destroy()
        end

        self.TarmacBag.Orientation = nil
        self.TarmacBag.CurrentBP = nil
    end,

    HasTarmac = function(self)
        if not self.TarmacBag then return false end
        return (table.getn(self.TarmacBag.Decals) ~= 0)
    end,

    OnMassStorageStateChange = function(self, state)
    end,

    OnEnergyStorageStateChange = function(self, state)
    end,

    CreateBlinkingLights = function(self, color)
        self:DestroyBlinkingLights()
        local bp = self:GetBlueprint().Display.BlinkingLights
        local bpEmitters = self:GetBlueprint().Display.BlinkingLightsFx
        if bp then
            local fxbp = bpEmitters[color]
            for k, v in bp do
                if type(v) == 'table' then
                    local fx = CreateAttachedEmitter(self, v.BLBone, self:GetArmy(), fxbp)
                    fx:OffsetEmitter(v.BLOffsetX or 0, v.BLOffsetY or 0, v.BLOffsetZ or 0)
                    fx:ScaleEmitter(v.BLScale or 1)
                    table.insert(self.FxBlinkingLightsBag, fx)
                    self.Trash:Add(fx)
                end
            end
        end
    end,

    DestroyBlinkingLights = function(self)
        for k, v in self.FxBlinkingLightsBag do
            v:Destroy()
        end
        self.FxBlinkingLightsBag = {}
    end,

    CreateDestructionEffects = function( self, overKillRatio )
        -- LOG( bp.General.FactionName, ' ', bp.General.UnitType,' avg. bounding radius = ', explosion.GetAverageBoundingXZRadius( self ) )
        -- LOG( 'CurrentLayer ', self:GetCurrentLayer())

        if( explosion.GetAverageBoundingXZRadius( self ) < 1.0 ) then
            explosion.CreateScalableUnitExplosion( self, overKillRatio )
        else
            explosion.CreateTimedStuctureUnitExplosion( self )
            WaitSeconds( 0.5 )
            explosion.CreateScalableUnitExplosion( self, overKillRatio )
        end
    end,

    -- Modified to use same upgrade logic as the ui. This adds more upgrade options via General.UpgradesFromBase blueprint option
    OnStartBuild = function(self, unitBeingBuilt, order )
        Unit.OnStartBuild(self,unitBeingBuilt, order)
        self.UnitBeingBuilt = unitBeingBuilt

        --LOG("structure onstartbuild")

        local builderBp = self:GetBlueprint()
        local targetBp = unitBeingBuilt:GetBlueprint()
        local performUpgrade = false

        if targetBp.General.UpgradesFrom == builderBp.BlueprintId then
            performUpgrade = true
        elseif targetBp.General.UpgradesFrom == builderBp.General.UpgradesTo then
            performUpgrade = true
        elseif targetBp.General.UpgradesFromBase ~= "none" then
            -- try testing against the base
            if targetBp.General.UpgradesFromBase == builderBp.BlueprintId then
                performUpgrade = true
            elseif targetBp.General.UpgradesFromBase == builderBp.General.UpgradesFromBase then
                performUpgrade = true
            end
        end

        if performUpgrade and order == 'Upgrade' then
            ChangeState(self, self.UpgradingState)
        end
     end,

    IdleState = State {
        Main = function(self)
        end,
    },

    UpgradingState = State {
        Main = function(self)
            self:StopRocking()
            local bp = self:GetBlueprint().Display
            self:DestroyTarmac()
            self:PlayUnitSound('UpgradeStart')
            self:DisableDefaultToggleCaps()
            if bp.AnimationUpgrade then
                local unitBuilding = self.UnitBeingBuilt
                self.AnimatorUpgradeManip = CreateAnimator(self)
                self.Trash:Add(self.AnimatorUpgradeManip)
                local fractionOfComplete = 0
                self:StartUpgradeEffects(unitBuilding)
                self.AnimatorUpgradeManip:PlayAnim(bp.AnimationUpgrade, false):SetRate(0)

                while fractionOfComplete < 1 and not self:IsDead() do
                    fractionOfComplete = unitBuilding:GetFractionComplete()
                    self.AnimatorUpgradeManip:SetAnimationFraction(fractionOfComplete)
                    WaitTicks(1)
                end
                if not self:IsDead() then
                    self.AnimatorUpgradeManip:SetRate(1)
                end
            end
        end,

        OnStopBuild = function(self, unitBuilding)
            Unit.OnStopBuild(self, unitBuilding)
            self:EnableDefaultToggleCaps()

            if unitBuilding:GetFractionComplete() == 1 then
                NotifyUpgrade(self, unitBuilding)
                self:StopUpgradeEffects(unitBuilding)
                self:PlayUnitSound('UpgradeEnd')
                self:Destroy()
            end
        end,

        OnFailedToBuild = function(self)
            Unit.OnFailedToBuild(self)
            self:EnableDefaultToggleCaps()

            if self.AnimatorUpgradeManip then self.AnimatorUpgradeManip:Destroy() end

            if self:GetCurrentLayer() == 'Water' then
                self:StartRocking()
            end
            self:PlayUnitSound('UpgradeFailed')
            self:PlayActiveAnimation()
            self:CreateTarmac(true, true, true, self.TarmacBag.Orientation, self.TarmacBag.CurrentBP)
            ChangeState(self, self.IdleState)
        end,
    },

    StartBeingBuiltEffects = function(self, builder, layer)
        Unit.StartBeingBuiltEffects(self, builder, layer)
        local bp = self:GetBlueprint()
        local FactionName = bp.General.FactionName

        if FactionName == 'UEF' then
            self:HideBone(0, true)
            self.BeingBuiltShowBoneTriggered = false
            if bp.General.UpgradesFrom ~= builder:GetUnitId() then
                self:ForkThread( EffectUtil.CreateBuildCubeThread, builder, self.OnBeingBuiltEffectsBag )
            end
        elseif FactionName == 'Aeon' then
            if bp.General.UpgradesFrom ~= builder:GetUnitId() then
                self:ForkThread( EffectUtil.CreateAeonBuildBaseThread, builder, self.OnBeingBuiltEffectsBag )
            end
        elseif FactionName == 'Cybran' then
        elseif FactionName == 'Seraphim' then
            if bp.General.UpgradesFrom ~= builder:GetUnitId() then
                self:ForkThread( EffectUtil.CreateSeraphimBuildBaseThread, builder, self.OnBeingBuiltEffectsBag )
            end
        end
    end,

    StopBeingBuiltEffects = function(self, builder, layer)
        local FactionName = self:GetBlueprint().General.FactionName
        if FactionName == 'Aeon' then
            WaitSeconds( 2.0 )
        elseif FactionName == 'UEF' and not self.BeingBuiltShowBoneTriggered then
            self:ShowBone(0, true)
            self:HideLandBones()
        end
        Unit.StopBeingBuiltEffects(self, builder, layer)
    end,

    StartBuildingEffects = function(self, unitBeingBuilt, order)
        Unit.StartBuildingEffects(self, unitBeingBuilt, order)
    end,

    StopBuildingEffects = function(self, unitBeingBuilt)
        Unit.StopBuildingEffects(self, unitBeingBuilt)
    end,

    StartUpgradeEffects = function(self, unitBeingBuilt)
        unitBeingBuilt:HideBone(0, true)
    end,

    StopUpgradeEffects = function(self, unitBeingBuilt)
        unitBeingBuilt:ShowBone(0, true)
    end,

    PlayActiveAnimation = function(self)

    end,

    -- Adding into OnKilled the ability to destroy the tarmac but put a new one down that looks exactly like it but
    -- will time out over the time spec'd or 300 seconds.
    OnKilled = function(self, instigator, type, overkillRatio)
        Unit.OnKilled(self, instigator, type, overkillRatio)
        local orient = self.TarmacBag.Orientation
        local currentBP = self.TarmacBag.CurrentBP
        self:DestroyTarmac()
        self:CreateTarmac(true, true, true, orient, currentBP, currentBP.DeathLifetime or 300)
    end,

    ----------------------------------------------------------------------------------------------
    --  Adjacency
    ----------------------------------------------------------------------------------------------

    -- When we're adjacent, try to apply all the possible bonuses
    OnAdjacentTo = function(self, adjacentUnit, triggerUnit)    -- What is triggerUnit?
        if self:IsBeingBuilt() then return end
        if adjacentUnit:IsBeingBuilt() then return end

        -- Does the unit have any adjacency buffs to use?
        local adjBuffs = self:GetBlueprint().Adjacency
        if not adjBuffs then return end
 
        -- Apply each buff needed to you and/or adjacent unit
        for k,v in AdjacencyBuffs[adjBuffs] do
            Buff.ApplyBuff(adjacentUnit, v, self)
        end
        
        -- Keep track of adjacent units
        if not self.AdjacentUnits then
            self.AdjacentUnits = {}
        end
        table.insert(self.AdjacentUnits, adjacentUnit)
        
        self:RequestRefreshUI()
        adjacentUnit:RequestRefreshUI()
     end,

    --When we're not adjacent, try to remove all the possible bonuses
    OnNotAdjacentTo = function(self, adjacentUnit)
        if not self.AdjacentUnits then
            WARN("Precondition Failed: No AdjacentUnits registered for entity: " .. repr(self.GetEntityId))
            return
        end

        local adjBuffs = self:GetBlueprint().Adjacency
        
        if adjBuffs and AdjacencyBuffs[adjBuffs] then
            for k,v in AdjacencyBuffs[adjBuffs] do
                if Buff.HasBuff(adjacentUnit, v) then
                    Buff.RemoveBuff(adjacentUnit, v)
                end
            end
        end
        self:DestroyAdjacentEffects()
        
        -- Keep track of units losing adjacent structures
        for k,u in self.AdjacentUnits do
            if u == adjacentUnit then
                table.remove(self.AdjacentUnits, k)
                adjacentUnit:RequestRefreshUI()
            end
        end
        self:RequestRefreshUI()
    end,
    
    ------------------------------------
    --Add/Remove Adjacency Functionality
    ------------------------------------
    
    -- Applies all appropriate buffs to all adjacent units
    ApplyAdjacencyBuffs = function(self)
        local adjBuffs = self:GetBlueprint().Adjacency
        if not adjBuffs then return end
        
        -- There won't be any adjacentUnit if this is a producer just built...
        if self.AdjacentUnits then
            for k, adjacentUnit in self.AdjacentUnits do
                for k,v in AdjacencyBuffs[adjBuffs] do
                    Buff.ApplyBuff(adjacentUnit, v, self)
                    adjacentUnit:RequestRefreshUI()
                end
            end
            self:RequestRefreshUI()
        end
    end,
    
    -- Removes all appropriate buffs from all adjacent units
    RemoveAdjacencyBuffs = function(self)
        local adjBuffs = self:GetBlueprint().Adjacency
        if not adjBuffs then return end
		
        if self.AdjacentUnits then
            for k, adjacentUnit in self.AdjacentUnits do
                for key, v in AdjacencyBuffs[adjBuffs] do
                    if Buff.HasBuff(adjacentUnit, v) then
                        Buff.RemoveBuff(adjacentUnit, v, false, self)
                        adjacentUnit:RequestRefreshUI()
                    end
                end
            end
            self:RequestRefreshUI()
        end
    end,

    -------------------------------
    -- Add/Remove Adjacency Effects
    -------------------------------

    CreateAdjacentEffect = function(self, adjacentUnit)
        --Create trashbag to hold all these entities and beams
        if not self.AdjacencyBeamsBag then
            self.AdjacencyBeamsBag = {}
        end

        for k,v in self.AdjacencyBeamsBag do
            if v.Unit:GetEntityId() == adjacentUnit:GetEntityId() then
                return
            end
        end
        self:ForkThread( EffectUtil.CreateAdjacencyBeams, adjacentUnit, self.AdjacencyBeamsBag )
    end,

    DestroyAdjacentEffects = function(self, adjacentUnit)
        if not self.AdjacencyBeamsBag then return end
        
        for k, v in self.AdjacencyBeamsBag do
            if v.Unit:BeenDestroyed() or v.Unit:IsDead() then
                v.Trash:Destroy()
                self.AdjacencyBeamsBag[k] = nil
            end
        end
    end,
}

---------------------------------------------------------------
--  FACTORY  UNITS
---------------------------------------------------------------
FactoryUnit = Class(StructureUnit) {
    OnCreate = function(self)

    -- Engymod addition: If a normal factory is created, we should check for research stations
    if EntityCategoryContains(categories.FACTORY, self) then
       self:updateBuildRestrictions()
    end

        StructureUnit.OnCreate(self)
        self.BuildingUnit = false
    end,

    -- Added to add engymod logic
    OnDestroy = function(self)
        -- Figure out if we're a research station
        if EntityCategoryContains(categories.RESEARCH, self) then
        local aiBrain = self:GetAIBrain()
        local buildRestrictionVictims = aiBrain:GetListOfUnits(categories.FACTORY+categories.ENGINEER, false)

        for id, unit in buildRestrictionVictims do
            unit:updateBuildRestrictions()
        end
    end

    StructureUnit.OnDestroy(self)
    end,

    OnPaused = function(self)
        --When factory is paused take some action
        self:StopUnitAmbientSound( 'ConstructLoop' )
        StructureUnit.OnPaused(self)
    end,

    OnUnpaused = function(self)
        if self.BuildingUnit then
            self:PlayUnitAmbientSound( 'ConstructLoop' )
        end
        StructureUnit.OnUnpaused(self)
    end,

    OnStopBeingBuilt = function(self,builder,layer)
        local aiBrain = GetArmyBrain(self:GetArmy())
        aiBrain:ESRegisterUnitMassStorage(self)
        aiBrain:ESRegisterUnitEnergyStorage(self)
        local curEnergy = aiBrain:GetEconomyStoredRatio('ENERGY')
        local curMass = aiBrain:GetEconomyStoredRatio('MASS')
        if curEnergy > 0.11 and curMass > 0.11 then
            self:CreateBlinkingLights('Green')
            self.BlinkingLightsState = 'Green'
        else
            self:CreateBlinkingLights('Red')
            self.BlinkingLightsState = 'Red'
        end

        -- If we're a HQ, update build restrictions for all factories
        if EntityCategoryContains(categories.RESEARCH, self) then
            local buildRestrictionVictims = aiBrain:GetListOfUnits(categories.FACTORY + categories.ENGINEER, false)
            for id, unit in buildRestrictionVictims do
            unit:updateBuildRestrictions()
        end
    end

    StructureUnit.OnStopBeingBuilt(self,builder,layer)
    end,

    ChangeBlinkingLights = function(self, state)
        local bls = self.BlinkingLightsState
        if state == 'Yellow' then
            if bls == 'Green' then
                self:CreateBlinkingLights('Yellow')
                self.BlinkingLightsState = state
            end
        elseif state == 'Green' then
            if bls == 'Yellow' then
                self:CreateBlinkingLights('Green')
                self.BlinkingLightsState = state
            elseif bls == 'Red' then
                local aiBrain = GetArmyBrain(self:GetArmy())
                local curEnergy = aiBrain:GetEconomyStoredRatio('ENERGY')
                local curMass = aiBrain:GetEconomyStoredRatio('MASS')
                if curEnergy > 0.11 and curMass > 0.11 then
                    if self:GetNumBuildOrders(categories.ALLUNITS) == 0 then
                        self:CreateBlinkingLights('Green')
                        self.BlinkingLightsState = state
                    else
                        self:CreateBlinkingLights('Yellow')
                        self.BlinkingLightsState = 'Yellow'
                    end
                end
            end
        elseif state == 'Red' then
            self:CreateBlinkingLights('Red')
            self.BlinkingLightsState = state
        end
    end,

    OnMassStorageStateChange = function(self, newState)
        if newState == 'EconLowMassStore' then
            self:ChangeBlinkingLights('Red')
        else
            self:ChangeBlinkingLights('Green')
        end
    end,

    OnEnergyStorageStateChange = function(self, newState)
        if newState == 'EconLowEnergyStore' then
            self:ChangeBlinkingLights('Red')
        else
            self:ChangeBlinkingLights('Green')
        end
    end,

    OnStartBuild = function(self, unitBeingBuilt, order )
        self:ChangeBlinkingLights('Yellow')
        StructureUnit.OnStartBuild(self, unitBeingBuilt, order )
        self.BuildingUnit = true
        if order ~= 'Upgrade' then
            ChangeState(self, self.BuildingState)
            self.BuildingUnit = false
        end
        self.FactoryBuildFailed = false
    end,

    OnStopBuild = function(self, unitBeingBuilt, order )
        StructureUnit.OnStopBuild(self, unitBeingBuilt, order )

        if not self.FactoryBuildFailed then
            if not EntityCategoryContains(categories.AIR, unitBeingBuilt) then
                self:RollOffUnit()
            end
            self:StopBuildFx()
            self:ForkThread(self.FinishBuildThread, unitBeingBuilt, order )
        end
        self.BuildingUnit = false
    end,

    FinishBuildThread = function(self, unitBeingBuilt, order )
        self:SetBusy(true)
        self:SetBlockCommandQueue(true)
        local bp = self:GetBlueprint()
        local bpAnim = bp.Display.AnimationFinishBuildLand
        if bpAnim and EntityCategoryContains(categories.LAND, unitBeingBuilt) then
            self.RollOffAnim = CreateAnimator(self):PlayAnim(bpAnim)
            self.Trash:Add(self.RollOffAnim)
            WaitTicks(1)
            WaitFor(self.RollOffAnim)
        end
        if unitBeingBuilt and not unitBeingBuilt:IsDead() then
            unitBeingBuilt:DetachFrom(true)
        end
        self:DetachAll(bp.Display.BuildAttachBone or 0)
        self:DestroyBuildRotator()
        if order ~= 'Upgrade' then
            ChangeState(self, self.RollingOffState)
        else
            self:SetBusy(false)
            self:SetBlockCommandQueue(false)
        end
    end,

    CheckBuildRestriction = function(self, target_bp)
        if self:CanBuild(target_bp.BlueprintId) then
            return true
        else
            return false
        end
    end,

    OnFailedToBuild = function(self)
        self.FactoryBuildFailed = true
        StructureUnit.OnFailedToBuild(self)
        self:DestroyBuildRotator()
        self:StopBuildFx()
        ChangeState(self, self.IdleState)
    end,

    RollOffUnit = function(self)
        local spin, x, y, z = self:CalculateRollOffPoint()
        local units = { self.UnitBeingBuilt }
        self.MoveCommand = IssueMove(units, Vector(x, y, z))
    end,

    CalculateRollOffPoint = function(self)
        local bp = self:GetBlueprint().Physics.RollOffPoints
        local px, py, pz = unpack(self:GetPosition())
        if not bp then return 0, px, py, pz end
        local vectorObj = self:GetRallyPoint()
        local bpKey = 1
        local distance, lowest = nil
        for k, v in bp do
            distance = VDist2(vectorObj[1], vectorObj[3], v.X + px, v.Z + pz)
            if not lowest or distance < lowest then
                bpKey = k
                lowest = distance
            end
        end
        local fx, fy, fz, spin
        local bpP = bp[bpKey]
        local unitBP = self.UnitBeingBuilt:GetBlueprint().Display.ForcedBuildSpin
        if unitBP then
            spin = unitBP
        else
            spin = bpP.UnitSpin
        end
        fx = bpP.X + px
        fy = bpP.Y + py
        fz = bpP.Z + pz
        return spin, fx, fy, fz
    end,

    StartBuildFx = function(self, unitBeingBuilt)

    end,

    StopBuildFx = function(self)

    end,

    PlayFxRollOff = function(self)
    end,

    PlayFxRollOffEnd = function(self)
        if self.RollOffAnim then
            self.RollOffAnim:SetRate(-1)
            WaitFor(self.RollOffAnim)
            self.RollOffAnim:Destroy()
            self.RollOffAnim = nil
        end
    end,

    CreateBuildRotator = function(self)
        if not self.BuildBoneRotator then
            local spin = self:CalculateRollOffPoint()
            local bp = self:GetBlueprint().Display
            self.BuildBoneRotator = CreateRotator(self, bp.BuildAttachBone or 0, 'y', spin, 10000)
            self.Trash:Add(self.BuildBoneRotator)
        end
    end,

    DestroyBuildRotator = function(self)
        if self.BuildBoneRotator then
            self.BuildBoneRotator:Destroy()
            self.BuildBoneRotator = nil
        end
    end,

    RolloffBody = function(self)
        self:SetBusy(true)
        self:SetBlockCommandQueue(true)
        self:PlayFxRollOff()
        -- Wait until unit has left the factory
        while not self.UnitBeingBuilt:IsDead() and self.MoveCommand and not IsCommandDone(self.MoveCommand) do
            WaitSeconds(0.5)
        end
        self.MoveCommand = nil
        self:PlayFxRollOffEnd()
        self:SetBusy(false)
        self:SetBlockCommandQueue(false)
        ChangeState(self, self.IdleState)
    end,

    IdleState = State {

        Main = function(self)
            self:ChangeBlinkingLights('Green')
            self:SetBusy(false)
            self:SetBlockCommandQueue(false)
            self:DestroyBuildRotator()
        end,
    },

    BuildingState = State {

        Main = function(self)
            local unitBuilding = self.UnitBeingBuilt
            local bp = self:GetBlueprint()
            local bone = bp.Display.BuildAttachBone or 0
            self:DetachAll(bone)
            unitBuilding:AttachBoneTo(-2, self, bone)
            self:CreateBuildRotator()
            self:StartBuildFx(unitBuilding)
        end,
    },


    RollingOffState = State {
        Main = function(self)
            self:RolloffBody()
        end,
    },

    OnKilled = function(self, instigator, type, overkillRatio)
        StructureUnit.OnKilled(self, instigator, type, overkillRatio)
        if self.UnitBeingBuilt then
            self.UnitBeingBuilt:Destroy()
        end
    end,
}


-------------------------------------------------------------
--  AIR FACTORY UNITS
-------------------------------------------------------------
AirFactoryUnit = Class(FactoryUnit) {
}

-------------------------------------------------------------
--  AIR STAGING PLATFORMS UNITS
-------------------------------------------------------------
AirStagingPlatformUnit = Class(StructureUnit) {
    LandBuiltHiddenBones = {'Floatation'},

    OnStopBeingBuilt = function(self,builder,layer)
        StructureUnit.OnStopBeingBuilt(self,builder,layer)
        self:SetMaintenanceConsumptionActive()
    end,
}

-------------------------------------------------------------
-- ENERGY CREATION UNITS
-------------------------------------------------------------
ConcreteStructureUnit = Class(StructureUnit) {
    OnCreate = function(self)
        StructureUnit.OnCreate(self)
        self:Destroy()
    end
}

-------------------------------------------------------------
--  ENERGY CREATION UNITS
-------------------------------------------------------------
EnergyCreationUnit = Class(StructureUnit) {
    LandBuiltHiddenBones = {'Floatation'},
}

-------------------------------------------------------------
--  ENERGY STORAGE UNITS
-------------------------------------------------------------
EnergyStorageUnit = Class(StructureUnit) {
    LandBuiltHiddenBones = {'Floatation'},

    OnStopBeingBuilt = function(self,builder,layer)
        StructureUnit.OnStopBeingBuilt(self,builder,layer)
        local aiBrain = GetArmyBrain(self:GetArmy())
        aiBrain:ESRegisterUnitEnergyStorage(self)
        local curEnergy = aiBrain:GetEconomyStoredRatio('ENERGY')
        if curEnergy > 0.11 then
            self:CreateBlinkingLights('Yellow')
        else
            self:CreateBlinkingLights('Red')
        end
    end,

    OnEnergyStorageStateChange = function(self, newState)
        if newState == 'EconLowEnergyStore' then
            self:CreateBlinkingLights('Red')
        elseif newState == 'EconMidEnergyStore' then
            self:CreateBlinkingLights('Yellow')
        elseif newState == 'EconFullEnergyStore' then
            self:CreateBlinkingLights('Green')
        end
    end,

}

--------------------------------------------------------------
--  LAND FACTORY UNITS
--------------------------------------------------------------
LandFactoryUnit = Class(FactoryUnit) {}


--------------------------------------------------------------
-- MASS COLLECTION UNITS
--------------------------------------------------------------
MassCollectionUnit = Class(StructureUnit) {
    LandBuiltHiddenBones = {'Floatation'},

    OnConsumptionActive = function(self)
        StructureUnit.OnConsumptionActive(self)
        self:ApplyAdjacencyBuffs()
        self._productionActive = true
    end,

    OnConsumptionInActive = function(self)
        StructureUnit.OnConsumptionInActive(self)
        self:RemoveAdjacencyBuffs()
        self._productionActive = false
    end,
    
    OnCreate = function(self)
        StructureUnit.OnCreate(self)
        local markers = ScenarioUtils.GetMarkers()
        local unitPosition = self:GetPosition()

        for k, v in pairs(markers) do
            if(v.type == 'MASS') then
                local massPosition = v.position
                if( (massPosition[1] < unitPosition[1] + 1) and (massPosition[1] > unitPosition[1] - 1) and
                    (massPosition[2] < unitPosition[2] + 1) and (massPosition[2] > unitPosition[2] - 1) and
                    (massPosition[3] < unitPosition[3] + 1) and (massPosition[3] > unitPosition[3] - 1)) then
                    self:SetProductionPerSecondMass(self:GetProductionPerSecondMass() * (v.amount / 100))
                    break
                end
            end
        end
    end,

    OnStopBeingBuilt = function(self,builder,layer)
        StructureUnit.OnStopBeingBuilt(self,builder,layer)
        self:SetMaintenanceConsumptionActive()
    end,

    OnStartBuild = function(self, unitbuilding, order)
        StructureUnit.OnStartBuild(self, unitbuilding, order)
        self:AddCommandCap('RULEUCC_Stop')
        self.UpgradeWatcher = self:ForkThread(self.WatchUpgradeConsumption)
    end,

    OnStopBuild = function(self, unitbuilding, order)
        StructureUnit.OnStopBuild(self, unitbuilding, order)
        self:RemoveCommandCap('RULEUCC_Stop')
        if self.UpgradeWatcher then
            KillThread(self.UpgradeWatcher)
            self:SetConsumptionPerSecondMass(0)
            self:SetProductionPerSecondMass((self:GetBlueprint().Economy.ProductionPerSecondMass or 0) * (self.MassProdAdjMod or 1))
        end
    end,
    -- band-aid on lack of multiple separate resource requests per unit...
    -- if mass econ is depleted, take all the mass generated and use it for the upgrade

    --Old WatchUpgradeConsumption replaced with this on, enabling mex to not use resources when paused
    WatchUpgradeConsumption = function(self)
        local bp = self:GetBlueprint()
        local massConsumption = self:GetConsumptionPerSecondMass()

        -- Fix for weird mex behaviour when upgrading with depleted resource stock or while paused [100]
        -- Replaced Gowerly's fix with this which is very much inspired by his code. My code looks much better and
        -- seems to work a little better aswell.

        local aiBrain = self:GetAIBrain()

        local CalcEnergyFraction = function()
            local fraction = 1
            if aiBrain:GetEconomyStored( 'ENERGY' ) < self:GetConsumptionPerSecondEnergy() then
                fraction = math.min( 1, aiBrain:GetEconomyIncome('ENERGY') / aiBrain:GetEconomyRequested('ENERGY') )
            end
            return fraction
        end

        local CalcMassFraction = function()
            local fraction = 1
            if aiBrain:GetEconomyStored( 'MASS' ) < self:GetConsumptionPerSecondMass() then
                fraction = math.min( 1, aiBrain:GetEconomyIncome('MASS') / aiBrain:GetEconomyRequested('MASS') )
            end
            return fraction
        end

        while not self:IsDead() do
            local massProduction = bp.Economy.ProductionPerSecondMass * (self.MassProdAdjMod or 1)
            if self:IsPaused() then
                -- paused mex upgrade (another bug here that caused paused upgrades to continue use resources)
                self:SetConsumptionPerSecondMass( 0 )
                self:SetProductionPerSecondMass( massProduction * CalcEnergyFraction() )
            elseif aiBrain:GetEconomyStored( 'MASS' ) < 1 then
                -- mex upgrade while out of mass (this is where the engine code has a bug)
                self:SetConsumptionPerSecondMass( massConsumption )
                self:SetProductionPerSecondMass( massProduction / CalcMassFraction() )
                -- to use Gowerly's words; the above division cancels the engine bug like matter and anti-matter.
                -- the engine seems to do the exact opposite of this division.
            else
                -- mex upgrade while enough mass (don't care about energy, that works fine)
                self:SetConsumptionPerSecondMass( massConsumption )
                self:SetProductionPerSecondMass( massProduction * CalcEnergyFraction() )
            end

            WaitTicks(1)
        end
    end,

    OnPaused = function(self)
        StructureUnit.OnPaused(self)
    end,

    OnUnpaused = function(self)
        StructureUnit.OnUnpaused(self)
    end,

    OnProductionPaused = function(self)
        StructureUnit.OnProductionPaused(self)
        self:StopUnitAmbientSound( 'ActiveLoop' )
    end,

    OnProductionUnpaused = function(self)
        StructureUnit.OnProductionUnpaused(self)
        self:PlayUnitAmbientSound( 'ActiveLoop' )
    end,
}

--------------------------------------------------------------
--  MASS FABRICATION UNITS
--------------------------------------------------------------
MassFabricationUnit = Class(StructureUnit) {
    LandBuiltHiddenBones = {'Floatation'},

    OnStopBeingBuilt = function(self,builder,layer)
        StructureUnit.OnStopBeingBuilt(self,builder,layer)
        self:SetMaintenanceConsumptionActive()
        self:SetProductionActive(true)
    end,

    OnConsumptionActive = function(self)
        StructureUnit.OnConsumptionActive(self)
        self:SetMaintenanceConsumptionActive()
        self:SetProductionActive(true)
        self:ApplyAdjacencyBuffs()
        self._productionActive = true        
    end,

    OnConsumptionInActive = function(self)
        StructureUnit.OnConsumptionInActive(self)
        self:SetMaintenanceConsumptionInactive()
        self:SetProductionActive(false)
        self:RemoveAdjacencyBuffs()
        self._productionActive = false        
    end,

    OnPaused = function(self)
        StructureUnit.OnPaused(self)
    end,

    OnUnpaused = function(self)
        StructureUnit.OnUnpaused(self)
    end,

    OnProductionPaused = function(self)
        StructureUnit.OnProductionPaused(self)
        self:StopUnitAmbientSound( 'ActiveLoop' )
    end,

    OnProductionUnpaused = function(self)
        StructureUnit.OnProductionUnpaused(self)
        self:PlayUnitAmbientSound( 'ActiveLoop' )
    end,
}

--------------------------------------------------------------
--  MASS STORAGE UNITS
--------------------------------------------------------------
MassStorageUnit = Class(StructureUnit) {
    LandBuiltHiddenBones = {'Floatation'},

    OnStopBeingBuilt = function(self,builder,layer)
        StructureUnit.OnStopBeingBuilt(self,builder,layer)
        local aiBrain = GetArmyBrain(self:GetArmy())
        aiBrain:ESRegisterUnitMassStorage(self)
        local curMass = aiBrain:GetEconomyStoredRatio('MASS')
        if curMass > 0.11 then
            self:CreateBlinkingLights('Yellow')
        else
            self:CreateBlinkingLights('Red')
        end
    end,

    OnMassStorageStateChange = function(self, newState)
        if newState == 'EconLowMassStore' then
            self:CreateBlinkingLights('Red')
        elseif newState == 'EconMidMassStore' then
            self:CreateBlinkingLights('Yellow')
        elseif newState == 'EconFullMassStore' then
            self:CreateBlinkingLights('Green')
        end
    end,
}

--------------------------------------------------------------
--  RADAR UNITS
--------------------------------------------------------------
RadarUnit = Class(StructureUnit) {
    LandBuiltHiddenBones = {'Floatation'},

    OnStopBeingBuilt = function(self,builder,layer)
        StructureUnit.OnStopBeingBuilt(self,builder,layer)
        self:SetMaintenanceConsumptionActive()
    end,

    OnIntelDisabled = function(self)
        StructureUnit.OnIntelDisabled(self)
        self:DestroyIdleEffects()
        self:DestroyBlinkingLights()
        self:CreateBlinkingLights('Red')
    end,

    OnIntelEnabled = function(self)
        StructureUnit.OnIntelEnabled(self)
        self:DestroyBlinkingLights()
        self:CreateBlinkingLights('Green')
        self:CreateIdleEffects()
    end,
}


--------------------------------------------------------------
--  RADAR JAMMER UNITS
--------------------------------------------------------------
RadarJammerUnit = Class(StructureUnit) {
    LandBuiltHiddenBones = {'Floatation'},

    -- Shut down intel while upgrading
    OnStartBuild = function(self, unitbuilding, order)
        StructureUnit.OnStartBuild(self, unitbuilding, order)
        self:SetMaintenanceConsumptionInactive()
        self:DisableIntel('Jammer')
        self:DisableIntel('RadarStealthField')
    end,

    -- If we abort the upgrade, re-enable the intel
    OnStopBuild = function(self, unitBeingBuilt)
        StructureUnit.OnStopBuild(self, unitBeingBuilt)
        self:SetMaintenanceConsumptionActive()
        self:EnableIntel('Jammer')
        self:EnableIntel('RadarStealthField')
    end,

    -- If we abort the upgrade, re-enable the intel
    OnFailedToBuild = function(self)
        StructureUnit.OnStopBuild(self)
        self:SetMaintenanceConsumptionActive()
        self:EnableIntel('Jammer')
        self:EnableIntel('RadarStealthField')
    end,

    OnStopBeingBuilt = function(self,builder,layer)
        StructureUnit.OnStopBeingBuilt(self,builder,layer)
        self:SetMaintenanceConsumptionActive()
    end,

    OnIntelEnabled = function(self)
        StructureUnit.OnIntelEnabled(self)
        if self.IntelEffects and not self.IntelFxOn then
            self.IntelEffectsBag = {}
            self.CreateTerrainTypeEffects( self, self.IntelEffects, 'FXIdle',  self:GetCurrentLayer(), nil, self.IntelEffectsBag )
            self.IntelFxOn = true
        end
    end,

    OnIntelDisabled = function(self)
        StructureUnit.OnIntelDisabled(self)
        EffectUtil.CleanupEffectBag(self,'IntelEffectsBag')
        self.IntelFxOn = false
    end,
}

---------------------------------------------------------------
--  SONAR UNITS
---------------------------------------------------------------
SonarUnit = Class(StructureUnit) {
    LandBuiltHiddenBones = {'Floatation'},

    OnStopBeingBuilt = function(self,builder,layer)
        StructureUnit.OnStopBeingBuilt(self,builder,layer)
        self:SetMaintenanceConsumptionActive()
    end,

    CreateIdleEffects = function(self)
        StructureUnit.CreateIdleEffects(self)
        self.TimedSonarEffectsThread = self:ForkThread( self.TimedIdleSonarEffects )
    end,

    TimedIdleSonarEffects = function( self )
        local layer = self:GetCurrentLayer()
        local army = self:GetArmy()
        local pos = self:GetPosition()

        if self.TimedSonarTTIdleEffects then
            while not self:IsDead() do
                for kTypeGroup, vTypeGroup in self.TimedSonarTTIdleEffects do
                    local effects = self.GetTerrainTypeEffects( 'FXIdle', layer, pos, vTypeGroup.Type, nil )

                    for kb, vBone in vTypeGroup.Bones do
                        for ke, vEffect in effects do
                            emit = CreateAttachedEmitter(self,vBone,army,vEffect):ScaleEmitter(vTypeGroup.Scale or 1)
                            if vTypeGroup.Offset then
                                emit:OffsetEmitter(vTypeGroup.Offset[1] or 0, vTypeGroup.Offset[2] or 0,vTypeGroup.Offset[3] or 0)
                            end
                        end
                    end
                end
                self:PlayUnitSound('Sonar')
                WaitSeconds( 6.0 )
            end
        end
    end,

    DestroyIdleEffects = function(self)
        self.TimedSonarEffectsThread:Destroy()
        StructureUnit.DestroyIdleEffects(self)
    end,

    OnIntelDisabled = function(self)
        StructureUnit.OnIntelDisabled(self)
        self:DestroyBlinkingLights()
        self:CreateBlinkingLights('Red')
    end,

    OnIntelEnabled = function(self)
        StructureUnit.OnIntelEnabled(self)
        self:DestroyBlinkingLights()
        self:CreateBlinkingLights('Green')
    end,
}



--------------------------------------------------------------
-- SEA FACTORY UNITS
--------------------------------------------------------------
SeaFactoryUnit = Class(FactoryUnit) {
    -- Disable the default rocking behavior
    StartRocking = function(self)
    end,

    StopRocking = function(self)
    end,
}



--------------------------------------------------------------
--  SHIELD STRCUTURE UNITS
--------------------------------------------------------------
ShieldStructureUnit = Class(StructureUnit) {

    UpgradingState = State(StructureUnit.UpgradingState) {
        Main = function(self)
            StructureUnit.UpgradingState.Main(self)
        end,

        OnFailedToBuild = function(self)
            StructureUnit.UpgradingState.OnFailedToBuild(self)
        end,
    }
}

--------------------------------------------------------------
--  TRANSPORT BEACON UNITS
--------------------------------------------------------------
TransportBeaconUnit = Class(StructureUnit) {
    LandBuiltHiddenBones = {'Floatation'},
    FxTransportBeacon = {'/effects/emitters/red_beacon_light_01_emit.bp'},
    --{'/effects/emitters/red_smoke_beacon_01_emit.bp'},
    FxTransportBeaconScale = 0.5,

    -- invincibility!  (the only way to kill a transport beacon is
    -- to kill the transport unit generating it)
    OnDamage = function(self, instigator, amount, vector, damageType)
    end,

    OnCreate = function(self)
        StructureUnit.OnCreate(self)
        self:SetCapturable(false)
        self:SetReclaimable(false)
    end,
}

--------------------------------------------------------------
--  WALL STRCUTURE UNITS
--------------------------------------------------------------
WallStructureUnit = Class(StructureUnit) {
    LandBuiltHiddenBones = {'Floatation'},
}

--------------------------------------------------------------
--  QUANTUM GATE UNITS
--------------------------------------------------------------
QuantumGateUnit = Class(FactoryUnit) {
    OnKilled = function(self, instigator, type, overkillRatio)
        self:StopUnitAmbientSound( 'ActiveLoop' )
        FactoryUnit.OnKilled(self, instigator, type, overkillRatio)
    end,

}

--------------------------------------------------------------
--  MOBILE UNITS
--------------------------------------------------------------
MobileUnit = Class(Unit) {
    -- Added for engymod. After creating an enhancement, units must re-check their build restrictions
    CreateEnhancement = function(self, enh)
        Unit.CreateEnhancement(self, enh)
        self:updateBuildRestrictions()
    end,

    -- Added for engymod. When created, units must re-check their build restrictions
    OnCreate = function(self)
        Unit.OnCreate(self)
        self:updateBuildRestrictions()
    end,

    OnKilled = function(self, instigator, type, overkillRatio)
        --Add unit's threat to our influence map
        local threat = 5
        local decay = 0.1
        local currentLayer = self:GetCurrentLayer()
        if instigator then
            local unit = false
            if IsUnit(instigator) then
                unit = instigator
            elseif IsProjectile(instigator) or IsCollisionBeam(instigator) then
                unit = instigator.unit
            end

            if unit then
                local unitPos = unit:GetCachePosition()
                if EntityCategoryContains(categories.STRUCTURE, unit) then
                    decay = 0.01
                end

                if unitPos then
                    if currentLayer == 'Sub' then
                        threat = self:GetAIBrain():GetThreatAtPosition(unitPos, 0, true, 'AntiSub')
                    elseif currentLayer == 'Air' then
                        threat = self:GetAIBrain():GetThreatAtPosition(unitPos, 0, true, 'AntiAir')
                    else
                        threat = self:GetAIBrain():GetThreatAtPosition(unitPos, 0, true, 'AntiSurface')
                    end
                    threat = threat / 2
                end
            end
        end

        if currentLayer == 'Sub' then
            self:GetAIBrain():AssignThreatAtPosition(self:GetPosition(), threat, decay*10, 'AntiSub')
        elseif currentLayer == 'Air' then
            self:GetAIBrain():AssignThreatAtPosition(self:GetPosition(), threat, decay, 'AntiAir')
        elseif currentLayer == 'Water' then
            self:GetAIBrain():AssignThreatAtPosition(self:GetPosition(), threat, decay*10, 'AntiSurface')
        else
            self:GetAIBrain():AssignThreatAtPosition(self:GetPosition(), threat, decay, 'AntiSurface')
        end

        Unit.OnKilled(self, instigator, type, overkillRatio)
    end,

    StartBeingBuiltEffects = function(self, builder, layer)
        Unit.StartBeingBuiltEffects(self, builder, layer)
        local bp = self:GetBlueprint()
        local FactionName = bp.General.FactionName

        if FactionName == 'UEF' then
            EffectUtil.CreateUEFUnitBeingBuiltEffects( self, builder, self.OnBeingBuiltEffectsBag )
        end
    end,

    StopBeingBuiltEffects = function(self, builder, layer)
        Unit.StopBeingBuiltEffects(self, builder, layer)
    end,

    StartBuildingEffects = function(self, unitBeingBuilt, order)
        Unit.StartBuildingEffects(self, unitBeingBuilt, order)
    end,

    StopBuildingEffects = function(self, unitBeingBuilt)
        Unit.StopBuildingEffects(self, unitBeingBuilt)
    end,

    CreateReclaimEffects = function( self, target )
        EffectUtil.PlayReclaimEffects( self, target, self:GetBlueprint().General.BuildBones.BuildEffectBones or {0,}, self.ReclaimEffectsBag )
    end,

    CreateReclaimEndEffects = function( self, target )
        EffectUtil.PlayReclaimEndEffects( self, target )
    end,

    CreateCaptureEffects = function( self, target )
        EffectUtil.PlayCaptureEffects( self, target, self:GetBlueprint().General.BuildBones.BuildEffectBones or {0,}, self.CaptureEffectsBag )
    end,
}

--------------------------------------------------------------
--  WALKING LAND UNITS
--------------------------------------------------------------
WalkingLandUnit = Class(MobileUnit) {
    WalkingAnim = nil,
    WalkingAnimRate = 1,
    IdleAnim = false,
    IdleAnimRate = 1,
    DeathAnim = false,
    DisabledBones = {},

    OnMotionHorzEventChange = function( self, new, old )
        MobileUnit.OnMotionHorzEventChange(self, new, old)

        if ( old == 'Stopped' ) then
            if (not self.Animator) then
                self.Animator = CreateAnimator(self, true)
            end
            local bpDisplay = self:GetBlueprint().Display
            if bpDisplay.AnimationWalk then
                self.Animator:PlayAnim(bpDisplay.AnimationWalk, true)
                self.Animator:SetRate(bpDisplay.AnimationWalkRate or 1)
            end
        elseif ( new == 'Stopped' ) then
            -- only keep the animator around if we are dying and playing a death anim
            -- or if we have an idle anim
            if(self.IdleAnim and not self:IsDead()) then
                self.Animator:PlayAnim(self.IdleAnim, true)
            elseif(not self.DeathAnim or not self:IsDead()) then
                self.Animator:Destroy()
                self.Animator = false
            end
        end
    end,
}

--------------------------------------------------------------
--  SUB UNITS
--  These units typically float under the water and have wake when they move.
--------------------------------------------------------------
SubUnit = Class(MobileUnit) {
-- use default spark effect until underwater damaged states are made
    FxDamage1 = {EffectTemplate.DamageSparks01},
    FxDamage2 = {EffectTemplate.DamageSparks01},
    FxDamage3 = {EffectTemplate.DamageSparks01},

   -- DESTRUCTION PARAMS
    ShowUnitDestructionDebris = false,
    DeathThreadDestructionWaitTime = 0,
}

--------------------------------------------------------------
--  AIR UNITS
---------------------------------------------------------------
AirUnit = Class(MobileUnit) {

    -- Contrails
    ContrailEffects = {'/effects/emitters/contrail_polytrail_01_emit.bp',},
    BeamExhaustCruise = '/effects/emitters/air_move_trail_beam_03_emit.bp',
    BeamExhaustIdle = '/effects/emitters/air_idle_trail_beam_01_emit.bp',

    -- DESTRUCTION PARAMS
    ShowUnitDestructionDebris = false,
    DestructionExplosionWaitDelayMax = 0,
    DestroyNoFallRandomChance = 0.5,

    OnCreate = function(self)
        MobileUnit.OnCreate(self)
        self:AddPingPong()
    end,

    OnStopBeingBuilt = function(self,builder,layer)
        MobileUnit.OnStopBeingBuilt(self,builder,layer)
        local bp = self:GetBlueprint()
        if bp.SizeSphere then
            self:SetCollisionShape(
                'Sphere',
                bp.CollisionSphereOffsetX or 0,
                bp.CollisionSphereOffsetY or 0,
                bp.CollisionSphereOffsetZ or 0,
                bp.SizeSphere
            )
        end
    end,

    AddPingPong = function(self)
        local bp = self:GetBlueprint()
        if bp.Display.PingPongScroller then
            bp = bp.Display.PingPongScroller
            if bp.Ping1 and bp.Ping1Speed and bp.Pong1 and bp.Pong1Speed and bp.Ping2 and bp.Ping2Speed
                and bp.Pong2 and bp.Pong2Speed then
                self:AddPingPongScroller(bp.Ping1, bp.Ping1Speed, bp.Pong1, bp.Pong1Speed,
                                         bp.Ping2, bp.Ping2Speed, bp.Pong2, bp.Pong2Speed)
            end
        end
    end,

    OnMotionVertEventChange = function( self, new, old )
        MobileUnit.OnMotionVertEventChange( self, new, old )
        --LOG( 'OnMotionVertEventChange, new = ', new, ', old = ', old )
        local army = self:GetArmy()
        if (new == 'Down') then
            -- Turn off the ambient hover sound
            self:StopUnitAmbientSound( 'ActiveLoop' )
        elseif (new == 'Bottom') then
            -- While landed, planes can only see half as far
            local vis = self:GetBlueprint().Intel.VisionRadius / 2
            self:SetIntelRadius('Vision', vis)

            -- Turn off the ambient hover sound
            -- It will probably already be off, but there are some odd cases that
            -- make this a good idea to include here as well.
            self:StopUnitAmbientSound( 'ActiveLoop' )
        elseif (new == 'Up' or ( new == 'Top' and ( old == 'Down' or old == 'Bottom' ))) then
            -- Set the vision radius back to default
            local bpVision = self:GetBlueprint().Intel.VisionRadius
            if bpVision then
                self:SetIntelRadius('Vision', bpVision)
            else
                self:SetIntelRadius('Vision', 0)
            end
        end
    end,

    OnRunOutOfFuel = function(self)
        MobileUnit.OnRunOutOfFuel(self)
        -- penalize movement for running out of fuel
        self:SetSpeedMult(0.35)     -- change the speed of the unit by this mult
        self:SetAccMult(0.25)       -- change the acceleration of the unit by this mult
        self:SetTurnMult(0.25)      -- change the turn ability of the unit by this mult
    end,

    OnGotFuel = function(self)
        MobileUnit.OnGotFuel(self)
        -- revert these values to the blueprint values
        self:SetSpeedMult(1)
        self:SetAccMult(1)
        self:SetTurnMult(1)
    end,

    OnImpact = function(self, with, other)
        if self.DeathBounce then
            return
        end
        self.DeathBounce = true

        -- Damage the area we have impacted with.
        local bp = self:GetBlueprint()
        local i = 1
        local numWeapons = table.getn(bp.Weapon)

        for i, numWeapons in bp.Weapon do
            if(bp.Weapon[i].Label == 'DeathImpact') then
                DamageArea(self, self:GetPosition(), bp.Weapon[i].DamageRadius, bp.Weapon[i].Damage, bp.Weapon[i].DamageType, bp.Weapon[i].DamageFriendly)
                break
            end
        end

        if(with == 'Water') then
            self:PlayUnitSound('AirUnitWaterImpact')
            EffectUtil.CreateEffects( self, self:GetArmy(), EffectTemplate.DefaultProjectileWaterImpact )
        end
        self:ForkThread(self.DeathThread, self.OverKillRatio )
    end,

    CreateUnitAirDestructionEffects = function( self, scale )
        local army = self:GetArmy()
        local scale = explosion.GetAverageBoundingXZRadius(self)
        explosion.CreateDefaultHitExplosion( self, scale)
        if(self.ShowUnitDestructionDebris) then
            explosion.CreateDebrisProjectiles(self, scale, {self:GetUnitSizes()})
        end
    end,

    -- ON KILLED: THIS FUNCTION PLAYS WHEN THE UNIT TAKES A MORTAL HIT.  IT PLAYS ALL THE DEFAULT DEATH EFFECT
    -- IT ALSO SPAWNS THE WRECKAGE BASED UPON HOW MUCH IT WAS OVERKILLED. UNIT WILL SPIN OUT OF CONTROL TOWARDS
    -- GROUND AND WHEN IT IMPACTS IT WILL DESTROY ITSELF
    OnKilled = function(self, instigator, type, overkillRatio)
        local bp = self:GetBlueprint()
        if self:GetCurrentLayer() == 'Air' then
            self.CreateUnitAirDestructionEffects( self, 1.0 )
            self:DestroyTopSpeedEffects()
            self:DestroyBeamExhaust()
            self.OverKillRatio = overkillRatio
            self:PlayUnitSound('Killed')
            self:DoUnitCallbacks('OnKilled')
            self:OnKilledVO()
            if instigator and IsUnit(instigator) then
                instigator:OnKilledUnit(self)
            end
        else
            self.DeathBounce = 1
            MobileUnit.OnKilled(self, instigator, type, overkillRatio)
        end
    end,
}

---------------------------------------------------------------
--  LAND UNITS
---------------------------------------------------------------
LandUnit = Class(MobileUnit) {}

-- -------------------------------------------------------------
--   CONSTRUCTION UNITS
-- -------------------------------------------------------------
ConstructionUnit = Class(MobileUnit) {
    OnCreate = function(self)
        MobileUnit.OnCreate(self)

        self.EffectsBag = {}
        if self:GetBlueprint().General.BuildBones then
            self:SetupBuildBones()
        end

        if self:GetBlueprint().Display.AnimationBuild then
            self.BuildingOpenAnim = self:GetBlueprint().Display.AnimationBuild
        end

        if self.BuildingOpenAnim then
            self.BuildingOpenAnimManip = CreateAnimator(self)
            self.BuildingOpenAnimManip:SetPrecedence(1)
            self.BuildingOpenAnimManip:PlayAnim(self.BuildingOpenAnim, false):SetRate(0)
            if self.BuildArmManipulator then
                self.BuildArmManipulator:Disable()
            end
        end
        self.BuildingUnit = false
    end,

    OnPaused = function(self)
        -- When factory is paused take some action
        self:StopUnitAmbientSound( 'ConstructLoop' )
        MobileUnit.OnPaused(self)
        if self.BuildingUnit then
            MobileUnit.StopBuildingEffects(self, self:GetUnitBeingBuilt())
        end
    end,

    OnUnpaused = function(self)
        if self.BuildingUnit then
            self:PlayUnitAmbientSound( 'ConstructLoop' )
            MobileUnit.StartBuildingEffects(self, self:GetUnitBeingBuilt(), self.UnitBuildOrder)
        end
        MobileUnit.OnUnpaused(self)
    end,

    OnStartBuild = function(self, unitBeingBuilt, order )

    if unitBeingBuilt.WorkItem.Slot and unitBeingBuilt.WorkProgress == 0 then
        return
    else
        MobileUnit.OnStartBuild(self,unitBeingBuilt, order)
    end
        -- Fix up info on the unit id from the blueprint and see if it matches the 'UpgradeTo' field in the BP.
        self.UnitBeingBuilt = unitBeingBuilt
        self.UnitBuildOrder = order
        self.BuildingUnit = true
        if unitBeingBuilt:GetUnitId() == self:GetBlueprint().General.UpgradesTo and order == 'Upgrade' then
            self.Upgrading = true
            self.BuildingUnit = false
        end
    end,

    OnStopBuild = function(self, unitBeingBuilt)
        MobileUnit.OnStopBuild(self,unitBeingBuilt)
        if self.Upgrading then
            NotifyUpgrade(self,unitBeingBuilt)
            self:Destroy()
        end
        self.UnitBeingBuilt = nil
        self.UnitBuildOrder = nil

        if self.BuildingOpenAnimManip and self.BuildArmManipulator then
            self.StoppedBuilding = true
        elseif self.BuildingOpenAnimManip then
            self.BuildingOpenAnimManip:SetRate(-1)
        end
        self.BuildingUnit = false
    end,

    WaitForBuildAnimation = function(self, enable)
        if self.BuildArmManipulator then
            WaitFor(self.BuildingOpenAnimManip)
            if (enable) then
                self.BuildArmManipulator:Enable()
            end
        end
    end,

    OnPrepareArmToBuild = function(self)
        MobileUnit.OnPrepareArmToBuild(self)

        -- LOG( 'OnPrepareArmToBuild' )
        if self.BuildingOpenAnimManip then
            self.BuildingOpenAnimManip:SetRate(self:GetBlueprint().Display.AnimationBuildRate or 1)
            if self.BuildArmManipulator then
                self.StoppedBuilding = false
                ForkThread( self.WaitForBuildAnimation, self, true )
            end
        end
    end,

    OnStopBuilderTracking = function(self)
        MobileUnit.OnStopBuilderTracking(self)

        if self.StoppedBuilding then
            self.StoppedBuilding = false
            self.BuildArmManipulator:Disable()
            self.BuildingOpenAnimManip:SetRate(-(self:GetBlueprint().Display.AnimationBuildRate or 1))
        end
    end,


    CheckBuildRestriction = function(self, target_bp)
        if self:CanBuild(target_bp.BlueprintId) then
            return true
        else
            return false
        end
    end,
}


---------------------------------------------------------------
--  SEA UNITS
--  These units typically float on the water and have wake when they move.
---------------------------------------------------------------

SeaUnit = Class(MobileUnit){
    DeathThreadDestructionWaitTime = 0,
    ShowUnitDestructionDebris = false,
    PlayEndestructionEffects = false,
    CollidedBones = 0,

    OnStopBeingBuilt = function(self,builder,layer)
        MobileUnit.OnStopBeingBuilt(self,builder,layer)
        self:SetMaintenanceConsumptionActive()
    end,
}


---------------------------------------------------------------
--  HOVERING LAND UNITS   --return this entire section to HoverLandUnit = Class(MobileUnit){} if it does not work
---------------------------------------------------------------

HoverLandUnit = Class(MobileUnit) {
}


-- This entire section is for factory fixes from CBFP.  If no workie, just remove everything below this line to restore

local Game = import('/lua/game.lua')
local FactoryFixes = import('/lua/FactoryFixes.lua').FactoryFixes

-- The altered factory unit class would be ideal except that it doesn't work. The code in this file gets appended at
-- the end to the existing file from stock FA. Because the air, ground and naval factory classes are generated before
-- this script is even executed the altered factory class won't be used. I can ofcourse re-generate the factory
-- classes but that will affect already loaded mods that change this code aswell. So the best sollution to the problem
-- is to apply the bug fix that was originally meant to go in the factory unit class to each dedicated factory class.

---------------------------------------------------------------
--  FACTORY  UNITS
---------------------------------------------------------------
FactoryUnit = FactoryFixes(FactoryUnit)

---------------------------------------------------------------
--  AIR FACTORY UNITS
---------------------------------------------------------------
AirFactoryUnit = FactoryFixes(AirFactoryUnit)

---------------------------------------------------------------
--  LAND FACTORY UNITS
---------------------------------------------------------------
LandFactoryUnit = FactoryFixes(LandFactoryUnit)

---------------------------------------------------------------
--  SEA FACTORY UNITS
---------------------------------------------------------------
SeaFactoryUnit = FactoryFixes(SeaFactoryUnit)

---------------------------------------------------------------
--  SHIELD HOVER UNITS
---------------------------------------------------------------
ShieldHoverLandUnit = Class(HoverLandUnit) {
}

---------------------------------------------------------------
--  SHIELD LAND UNITS
---------------------------------------------------------------
ShieldLandUnit = Class(LandUnit) {
}

---------------------------------------------------------------
--  SHIELD SEA UNITS
---------------------------------------------------------------
ShieldSeaUnit = Class(SeaUnit) {
}
