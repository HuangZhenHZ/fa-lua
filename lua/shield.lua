--****************************************************************************
--**
--**  File     :  /lua/shield.lua
--**  Author(s):  John Comes, Gordon Duclos
--**
--**  Summary  : Shield lua module
--**
--**  Copyright � 2005 Gas Powered Games, Inc.  All rights reserved.
--****************************************************************************

local Entity = import('/lua/sim/Entity.lua').Entity
local Overspill = import('/lua/overspill.lua')
local EffectTemplate = import('/lua/EffectTemplates.lua')
local Util = import('utilities.lua')

Shield = Class(moho.shield_methods,Entity) {

    ShieldVerticalOffset = -1,

    __init = function(self,spec)
        _c_CreateShield(self,spec)
    end,

    OnCreate = function(self,spec)
        self.Trash = TrashBag()
        self.Owner = spec.Owner
        self.MeshBp = spec.Mesh
        self.MeshZBp = spec.MeshZ
        self.ImpactMeshBp = spec.ImpactMesh
        self._IsUp = false
        if spec.ImpactEffects != '' then
            self.ImpactEffects = EffectTemplate[spec.ImpactEffects]
        else
            self.ImpactEffects = {}
        end

        self:SetSize(spec.Size)
        self:SetMaxHealth(spec.ShieldMaxHealth)
        self:SetHealth(self,spec.ShieldMaxHealth)
        self:SetType('Bubble')
        self:SetSpillOverDmgMod(spec.SpillOverDamageMod or 0.15)

        -- Show our 'lifebar'
        self:UpdateShieldRatio(1.0)

        self:SetRechargeTime(spec.ShieldRechargeTime or 5, spec.ShieldEnergyDrainRechargeTime or 5)
        self:SetVerticalOffset(spec.ShieldVerticalOffset)

        self:SetVizToFocusPlayer('Always')
        self:SetVizToEnemies('Intel')
        self:SetVizToAllies('Always')
        self:SetVizToNeutrals('Intel')

        self:AttachBoneTo(-1,spec.Owner,-1)

        self:SetShieldRegenRate(spec.ShieldRegenRate)
        self:SetShieldRegenStartTime(spec.ShieldRegenStartTime)

        self.OffHealth = -1

        self.PassOverkillDamage = spec.PassOverkillDamage

        ChangeState(self, self.OnState)
    end,

    SetRechargeTime = function(self, rechargeTime, energyRechargeTime)
        self.ShieldRechargeTime = rechargeTime
        self.ShieldEnergyDrainRechargeTime = energyRechargeTime
    end,

    SetVerticalOffset = function(self, offset)
        self.ShieldVerticalOffset = offset
    end,

    SetSize = function(self, size)
        self.Size = size
    end,

    SetShieldRegenRate = function(self, rate)
        self.RegenRate = rate
    end,

    SetShieldRegenStartTime = function(self, time)
        self.RegenStartTime = time
    end,

    SetType = function(self, type)
        self.ShieldType = type
    end,

    SetSpillOverDmgMod = function(self, dmgMod)
        self.SpillOverDmgMod = math.max(dmgMod, 0)
    end,

    UpdateShieldRatio = function(self, value)        
        if value >= 0 then
            self.Owner:SetShieldRatio(value)
        else
            self.Owner:SetShieldRatio(self:GetHealth() / self:GetMaxHealth())
        end
    end,

    GetCachePosition = function(self)
        return self:GetPosition()
    end,

    -- Note, this is called by native code to calculate spillover damage. The
    -- damage logic will subtract this value from any damage it does to units
    -- under the shield. The default is to always absorb as much as possible
    -- but the reason this function exists is to allow flexible implementations
    -- like shields that only absorb partial damage (like armor).
    OnGetDamageAbsorption = function(self,instigator,amount,type)
        --LOG('absorb: ', math.min( self:GetHealth(), amount ))

        -- Like armor damage, first multiply by armor reduction, then apply handicap
        -- See SimDamage.cpp (DealDamage function) for how this should work
        amount = amount * (self.Owner:GetArmorMult(type))
        amount = amount * ( 1.0 - ArmyGetHandicap(self:GetArmy()) )
        return math.min( self:GetHealth(), amount )
    end,

    OnCollisionCheckWeapon = function(self, firingWeapon)
        local weaponBP = firingWeapon:GetBlueprint()
        local collide = weaponBP.CollideFriendly
        if collide == false then
            if not ( IsEnemy(self:GetArmy(),firingWeapon.unit:GetArmy()) ) then
                return false
            end
        end
        --Check DNC list
        if weaponBP.DoNotCollideList then
            for k, v in pairs(weaponBP.DoNotCollideList) do
                if EntityCategoryContains(ParseEntityCategory(v), self) then
                    return false
                end
            end
        end  

        return true
    end,

    GetOverkill = function(self,instigator,amount,type)
        --LOG('absorb: ', math.min( self:GetHealth(), amount ))

        -- Like armor damage, first multiply by armor reduction, then apply handicap
        -- See SimDamage.cpp (DealDamage function) for how this should work
        amount = amount * (self.Owner:GetArmorMult(type))
        amount = amount * ( 1.0 - ArmyGetHandicap(self:GetArmy()) )
        local finalVal =  amount - self:GetHealth()
        if finalVal < 0 then
            finalVal = 0
        end
        return finalVal
    end,    

    OnDamage = function(self, instigator, amount, vector, dmgType)
        self:ApplyDamage(instigator, amount, vector, dmgType, true)
    end,

    ApplyDamage = function(self, instigator, amount, vector, dmgType, doOverspill)
        if self.Owner != instigator then

            local absorbed = self:OnGetDamageAbsorption(instigator, amount, dmgType)

            if self.PassOverkillDamage then
                local overkill = self:GetOverkill(instigator,amount,dmgType)    
                if self.Owner and IsUnit(self.Owner) and overkill > 0 then
                    self.Owner:DoTakeDamage(instigator, overkill, vector, dmgType)
                end
            end

            self:AdjustHealth(instigator, -absorbed)
            self:UpdateShieldRatio(-1)
            ForkThread(self.CreateImpactEffect, self, vector)
            if self.RegenThread then
                KillThread(self.RegenThread)
                self.RegenThread = nil
            end
            if self:GetHealth() <= 0 then
                ChangeState(self, self.DamageRechargeState)
            elseif self.OffHealth < 0 then
                if self.RegenRate > 0 then
                    self.RegenThread = ForkThread(self.RegenStartThread, self)
                    self.Owner.Trash:Add(self.RegenThread)
                end
            else
                self:UpdateShieldRatio(0)
            end		
        end	
        -- Only do overspill on events where we have an instigator. 
        -- "Force" damage events from stratbombs are one example
        -- where we don't.
        if doOverspill and IsEntity(instigator) then
            Overspill.DoOverspill(self, instigator, amount, dmgType, self.SpillOverDmgMod)
        end
    end,

    RegenStartThread = function(self)
        WaitSeconds(self.RegenStartTime)
        while self:GetHealth() < self:GetMaxHealth() do

            self:AdjustHealth(self.Owner, self.RegenRate)

            self:UpdateShieldRatio(-1)

            WaitSeconds(1)
        end
    end,

    CreateImpactEffect = function(self, vector)
        local army = self:GetArmy()
        local OffsetLength = Util.GetVectorLength(vector)
        local ImpactMesh = Entity { Owner = self.Owner }
        Warp( ImpactMesh, self:GetPosition())        

        if self.ImpactMeshBp != '' then
            ImpactMesh:SetMesh(self.ImpactMeshBp)
            ImpactMesh:SetDrawScale(self.Size)
            ImpactMesh:SetOrientation(OrientFromDir(Vector(-vector.x,-vector.y,-vector.z)),true)
        end

        for k, v in self.ImpactEffects do
            CreateEmitterAtBone( ImpactMesh, -1, army, v ):OffsetEmitter(0,0,OffsetLength)
        end

        WaitSeconds(5)
        ImpactMesh:Destroy()
    end,

    OnDestroy = function(self)
        self:SetMesh('')
        if self.MeshZ != nil then
            self.MeshZ:Destroy()
            self.MeshZ = nil
        end
        self:UpdateShieldRatio(0)
        ChangeState(self, self.DeadState)
    end,

    -- Return true to process this collision, false to ignore it.
    OnCollisionCheck = function(self,other)
        if other:GetArmy() == -1 then
            return false
        end

        -- allow strategic nuke missile to penetrate shields
        if EntityCategoryContains( categories.STRATEGIC, other ) and
            EntityCategoryContains( categories.MISSILE, other ) then
            return false
        end

        if other:GetBlueprint().Physics.CollideFriendlyShield then
            return true
        end

        return IsEnemy(self:GetArmy(),other:GetArmy())
    end,

    TurnOn = function(self)
        ChangeState(self, self.OnState)
    end,

    TurnOff = function(self)
        ChangeState(self, self.OffState)
    end,

    IsOn = function(self)
        return false
    end,

    IsUp = function(self)
        return (self:IsOn() and self._IsUp)
    end,

    RemoveShield = function(self)
        self._IsUp = false

        self:SetCollisionShape('None')

        self:SetMesh('')
        if self.MeshZ != nil then
            self.MeshZ:Destroy()
            self.MeshZ = nil
        end
    end,

    CreateShieldMesh = function(self)
        self:SetCollisionShape( 'Sphere', 0, 0, 0, self.Size/2)

        self:SetMesh(self.MeshBp)
        self:SetParentOffset(Vector(0,self.ShieldVerticalOffset,0))
        self:SetDrawScale(self.Size)

        if self.MeshZ == nil then
            self.MeshZ = Entity { Owner = self.Owner }
            self.MeshZ:SetMesh(self.MeshZBp)
            Warp( self.MeshZ, self.Owner:GetPosition() )
            self.MeshZ:SetDrawScale(self.Size)
            self.MeshZ:AttachBoneTo(-1,self.Owner,-1)
            self.MeshZ:SetParentOffset(Vector(0,self.ShieldVerticalOffset,0))

            self.MeshZ:SetVizToFocusPlayer('Always')
            self.MeshZ:SetVizToEnemies('Intel')
            self.MeshZ:SetVizToAllies('Always')
            self.MeshZ:SetVizToNeutrals('Intel')
        end

        self._IsUp = true
    end,

    -- Basically run a timer, but with visual bar movement
    ChargingUp = function(self, curProgress, time)
        local owner = self.Owner
        local position = owner:GetPosition()
        local shieldbp = self.Owner:GetBlueprint().Defense.Shield
        local shieldRadius = shieldbp.ShieldSize
        local aiBrain = owner:GetAIBrain()
        local otherShields = aiBrain:GetUnitsAroundPoint(( categories.SHIELD * categories.DEFENSE), position, shieldRadius, 'Ally' )
        local rechargeTime = time + ((table.getn(otherShields) - 1) * .2 * time)
        if rechargeTime > (time * 3) then
            rechargeTime = time
        else
        end
        while curProgress < rechargeTime do
            local fraction = self.Owner:GetResourceConsumed()
            curProgress = curProgress + ( fraction / 10 )
            curProgress = math.min( curProgress, rechargeTime )

            local workProgress = curProgress / rechargeTime

            self:UpdateShieldRatio( workProgress )
            WaitTicks(1)
        end    
    end,

    OnState = State {
        Main = function(self)

            -- If the shield was turned off; use the recharge time before turning back on
            if self.OffHealth >= 0 then
                self.Owner:SetMaintenanceConsumptionActive()
                self:ChargingUp(0, self.ShieldEnergyDrainRechargeTime)

                -- If the shield has less than full health, allow the shield to begin regening
                if self:GetHealth() < self:GetMaxHealth() and self.RegenRate > 0 then
                    self.RegenThread = ForkThread(self.RegenStartThread, self)
                    self.Owner.Trash:Add(self.RegenThread)
                end
            end

            -- We are no longer turned off
            self.OffHealth = -1
            
            self:UpdateShieldRatio(-1)
			self.Owner:OnShieldEnabled()
            self:CreateShieldMesh()
            
            --Code for Personal Bubbles, currently only the Harbinger
            local OwnerBp = self.Owner:GetBlueprint()
            local OwnerShield = OwnerBp.Defense.Shield
            if OwnerShield.PersonalBubble and OwnerShield.PersonalBubble == true then
                self.Owner:SetCollisionShape('Sphere', 0, OwnerBp.SizeY * 0.5, 0, OwnerShield.ShieldSize * 0.5)
                --Manually disable the bubble shield's collision sphere after its creation so it acts like the new personal shields
                self:SetCollisionShape('None')
            end
            
            self.Owner:PlayUnitSound('ShieldOn')
            self.Owner:SetMaintenanceConsumptionActive()
            
            --Then we can make any units inside a transport with a Shield invulnerable here
            self:ProtectTransportedUnits()

            local aiBrain = self.Owner:GetAIBrain()

            WaitSeconds(1.0)
            local fraction = self.Owner:GetResourceConsumed()
            local on = true
            local test = false

            -- Test in here if we have run out of power; if the fraction is ever not 1 we don't have full power
            while on do
                WaitTicks(1)

                self:UpdateShieldRatio(-1)

                fraction = self.Owner:GetResourceConsumed()
                if fraction != 1 and aiBrain:GetEconomyStored('ENERGY') <= 0 then
                    if test then
                        on = false
                    else
                        test = true
                    end
                else
                    on = true
                    test = false
                end
            end

            -- Record the amount of health on the shield here so when the unit tries to turn its shield
            -- back on and off it has the amount of health from before.
            --self.OffHealth = self:GetHealth()
            ChangeState(self, self.EnergyDrainRechargeState)
        end,

        IsOn = function(self)
            return true
        end,
    },

    -- When manually turned off
    OffState = State {
        Main = function(self)

            -- No regen during off state
            if self.RegenThread then
                KillThread(self.RegenThread)
                self.RegenThread = nil
            end

            -- Set the offhealth - this is used basically to let the unit know the unit was manually turned off
            self.OffHealth = self:GetHealth()

            -- Get rid of the shield bar
            self:UpdateShieldRatio(0)
            self:RemoveShield()
            
            --Code for Personal Bubbles, currently only the Harbinger
            local OwnerBp = self.Owner:GetBlueprint()
            local OwnerShield = OwnerBp.Defense.Shield
            if OwnerShield.PersonalBubble and OwnerShield.PersonalBubble == true then
                self.Owner:SetCollisionShape('Box', 0, OwnerBp.SizeY * 0.5, 0, OwnerBp.SizeX * 0.5, OwnerBp.SizeY * 0.5, OwnerBp.SizeZ * 0.5)
            end
            
            self.Owner:PlayUnitSound('ShieldOff')
            self.Owner:SetMaintenanceConsumptionInactive()

            --Apply vulnerabilities
            self:RevokeTransportProtection()
			self.Owner:OnShieldDisabled()

            WaitSeconds(1)
        end,

        IsOn = function(self)
            return false
        end,
    },

    -- This state happens when the shield has been depleted due to damage
    DamageRechargeState = State {
        Main = function(self)
            self:RemoveShield()

            --Code for Personal Bubbles, currently only the Harbinger
            local OwnerBp = self.Owner:GetBlueprint()
            local OwnerShield = OwnerBp.Defense.Shield
            if OwnerShield.PersonalBubble and OwnerShield.PersonalBubble == true then
                self.Owner:SetCollisionShape('Box', 0, OwnerBp.SizeY * 0.5, 0, OwnerBp.SizeX * 0.5, OwnerBp.SizeY * 0.5, OwnerBp.SizeZ * 0.5)
            end
            self.Owner:PlayUnitSound('ShieldOff')            

            --Apply vulnerabilities
            self:RevokeTransportProtection()
            
            -- We must make the unit charge up before getting its shield back
            self:ChargingUp(0, self.ShieldRechargeTime)

            -- Fully charged, get full health
            self:SetHealth(self, self:GetMaxHealth())

            ChangeState(self, self.OnState)
        end,

        IsOn = function(self)
            return false
        end,
    },

    -- This state happens only when the army has run out of power
    EnergyDrainRechargeState = State {
        Main = function(self)
            self:RemoveShield()
            --Code for Personal Bubbles, currently only the Harbinger
            local OwnerBp = self.Owner:GetBlueprint()
            local OwnerShield = OwnerBp.Defense.Shield
            if OwnerShield.PersonalBubble and OwnerShield.PersonalBubble == true then
                self.Owner:SetCollisionShape('Box', 0, OwnerBp.SizeY * 0.5, 0, OwnerBp.SizeX * 0.5, OwnerBp.SizeY * 0.5, OwnerBp.SizeZ * 0.5)
            end
            self.Owner:PlayUnitSound('ShieldOff')
            
            --Apply vulnerabilities
            self:RevokeTransportProtection()
            
            self:ChargingUp(0, self.ShieldEnergyDrainRechargeTime)

            -- If the unit is attached to a transport, make sure the shield goes to the off state
            -- so the shield isn't turned on while on a transport
            if not self.Owner:IsUnitState('Attached') then
                ChangeState(self, self.OnState)
            else
                ChangeState(self, self.OffState)
            end
        end,

        IsOn = function(self)
            return false
        end,
    },

    ProtectTransportedUnits = function(self)
        if EntityCategoryContains(categories.TRANSPORTATION, self.Owner) then
            self.Owner:SetCanTakeDamage(false)        
            local Cargo = self.Owner:GetCargo()
            for _, v in Cargo do
                v:SetCanTakeDamage(false)
            end
            self.Owner:IsTransportProtected(true)            
        end
    end,
    
    RevokeTransportProtection = function(self)
        if EntityCategoryContains(categories.TRANSPORTATION, self.Owner) then    
            self.Owner:SetCanTakeDamage(true)        
            local Cargo = self.Owner:GetCargo()
            for _, v in Cargo do
                v:SetCanTakeDamage(true)
            end
            self.Owner:IsTransportProtected(false)            
        end
    end,    
    
    DeadState = State {
        Main = function(self)
        end,

        IsOn = function(self)
            return false
        end,
    },
}

UnitShield = Class(Shield){

    OnCreate = function(self,spec)
        self.Trash = TrashBag()
        self.Owner = spec.Owner
        self.ImpactEffects = EffectTemplate[spec.ImpactEffects]        
        self.CollisionSizeX = spec.CollisionSizeX or 1
        self.CollisionSizeY = spec.CollisionSizeY or 1
        self.CollisionSizeZ = spec.CollisionSizeZ or 1
        self.CollisionCenterX = spec.CollisionCenterX or 0
        self.CollisionCenterY = spec.CollisionCenterY or 0
        self.CollisionCenterZ = spec.CollisionCenterZ or 0
        self.OwnerShieldMesh = spec.OwnerShieldMesh or ''

        self:SetSize(spec.Size)
        self:SetType('Personal')

        self:SetMaxHealth(spec.ShieldMaxHealth)
        self:SetHealth(self,spec.ShieldMaxHealth)

        -- Show our 'lifebar'
        self:UpdateShieldRatio(1.0)

        self:SetRechargeTime(spec.ShieldRechargeTime or 5, spec.ShieldEnergyDrainRechargeTime or 5)
        self:SetVerticalOffset(spec.ShieldVerticalOffset)

        self:SetVizToFocusPlayer('Always')
        self:SetVizToEnemies('Intel')
        self:SetVizToAllies('Always')
        self:SetVizToNeutrals('Always')

        self:AttachBoneTo(-1,spec.Owner,-1)

        self:SetShieldRegenRate(spec.ShieldRegenRate)
        self:SetShieldRegenStartTime(spec.ShieldRegenStartTime)

        self.PassOverkillDamage = spec.PassOverkillDamage

        ChangeState(self, self.OnState)
    end,

    CreateImpactEffect = function(self, vector)
        local army = self:GetArmy()
        local OffsetLength = Util.GetVectorLength(vector)
        local ImpactEnt = Entity { Owner = self.Owner }

        Warp( ImpactEnt, self:GetPosition())
        ImpactEnt:SetOrientation(OrientFromDir(Vector(-vector.x,-vector.y,-vector.z)),true)

        for k, v in self.ImpactEffects do
            CreateEmitterAtBone( ImpactEnt, -1, army, v ):OffsetEmitter(0,0,OffsetLength)
        end
        WaitSeconds(1)

        ImpactEnt:Destroy()
    end,

    CreateShieldMesh = function(self)
        -- Personal shields (unit shields) don't handle collisions anymore.
        -- This is done in the Unit's OnDamage function instead.
        self:SetCollisionShape('None')
        self.Owner:SetMesh(self.OwnerShieldMesh,true)
    end,

    RemoveShield = function(self)
        self:SetCollisionShape('None')
        self.Owner:SetMesh(self.Owner:GetBlueprint().Display.MeshBlueprint, true)
    end,

    OnDestroy = function(self)
        if not self.Owner.MyShield or self.Owner.MyShield:GetEntityId() == self:GetEntityId() then
            self.Owner:SetMesh(self.Owner:GetBlueprint().Display.MeshBlueprint, true)
        end
        self:UpdateShieldRatio(0)
        ChangeState(self, self.DeadState)
    end,

}

AntiArtilleryShield = Class(Shield) {

    OnCreate = function(self, spec)
        Shield.OnCreate(self, spec)
        self:SetType('AntiArtillery')
    end,

    OnCollisionCheckWeapon = function(self, firingWeapon)
        local bp = firingWeapon:GetBlueprint()
        if bp.CollideFriendly == false then
            if self:GetArmy() == firingWeapon.unit:GetArmy() then
                return false
            end
        end
        -- Check DNC list
        if bp.DoNotCollideList then
            for k, v in pairs(bp.DoNotCollideList) do
                if EntityCategoryContains(ParseEntityCategory(v), self) then
                    return false
                end
            end
        end          
        if bp.ArtilleryShieldBlocks then
            return true
        end
        return false
    end,

    -- Return true to process this collision, false to ignore it.
    OnCollisionCheck = function(self,other)
        if other:GetArmy() == -1 then
            return false
        end

        if other:GetBlueprint().Physics.CollideFriendlyShield and other.DamageData.ArtilleryShieldBlocks then
            return true
        end

        if other.DamageData.ArtilleryShieldBlocks and IsEnemy(self:GetArmy(),other:GetArmy()) then
            return true
        end

        return false
    end,
}
