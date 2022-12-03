#****************************************************************************
#**  File     :  /lua/aircraftcarrier.lua
#**  Author(s): XH-LinLin
#**	 Version  : Beta 1.1
#**  Summary  : aircraftcarrier autoproduct upgrade
#**  Copyright © 2005 Gas Powered Games, Inc. ,China FA upgrade group , All rights reserved.
#****************************************************************************
#--------------------------------------------------------------------------
# AircraftCarrier Autobuild
#--------------------------------------------------------------------------
local Entity = import('/lua/sim/Entity.lua').Entity
local util = import('/lua/utilities.lua')
local DefaultUnitsFile = import('/lua/defaultunits.lua')
local AirUnit = DefaultUnitsFile.AirUnit
local Unit = DefaultUnitsFile.SeaUnit
local RadarJammerUnit = DefaultUnitsFile.RadarJammerUnit
local EffectUtil = import('/lua/EffectUtilities.lua')
local PlayEffectsAtBones = EffectUtil.CreateBoneTableRangedScaleEffects
local WeaponFile = import('/lua/sim/DefaultWeapons.lua')
#--------------------------------------------------------------------------
# Normal AircraftCarrier
#--------------------------------------------------------------------------
AircraftCarrier = Class(Unit) {
    OnStopBeingBuilt = function(self, builder, layer)
        Unit.OnStopBeingBuilt(self, builder, layer)
        ChangeState( self, self.FinishedBeingBuilt )
    end,
    
	
    PodTransfer = function(self, pod, podData)
        # Set the pod as active, set new parent and creator for the pod, store the pod handle
        if not self.PodData[pod.PodName].Active then
            if not self.PodData then
                self.PodData = {}
            end
            self.PodData[pod.PodName] = table.deepcopy( podData )
            self.PodData[pod.PodName].PodHandle = pod
            pod:SetParent(self, pod.PodName)
        end
    end,
    
   
    
    OnDestroy = function(self)
        Unit.OnDestroy(self)
        -- kill all the pods and set them inactive
        if self.PodData then
            for k,v in self.PodData do
                if v.Active and not v.PodHandle:IsDead() then
                    v.PodHandle:Kill()
                end
            end
        end
    end,
    
    OnStartBuild = function(self, unitBeingBuilt, order )
        Unit.OnStartBuild(self,unitBeingBuilt,order)
        local unitid = self:GetBlueprint().General.UpgradesTo
        if unitBeingBuilt:GetUnitId() == unitid and order == 'Upgrade' then
            self.NowUpgrading = true
            ChangeState( self, self.UpgradingState )
        end
    end,
    
	--pause control function
	SetPause = function(self) 
		self.pause = true
	end,
	
	SetUnPause = function(self) 
		self.pause = false
	end,
    
    SetPodConsumptionRebuildRate = function(self, podData)
        local bp = self:GetBlueprint()
		local buildRate = bp.Economy.BuildRate
        --# Get build rate of tower
        local energy_rate = ( podData.BuildCostEnergy / podData.BuildTime ) * buildRate
        local mass_rate = ( podData.BuildCostMass / podData.BuildTime ) * buildRate
        
        -- Set Consumption
		self:SetConsumptionPerSecondEnergy(energy_rate)
		self:SetConsumptionPerSecondMass(mass_rate)
		self:SetConsumptionActive(true)
    end,
    
    CreatePod = function(self, podName)
        local location = self:GetPosition( self.PodData[podName].PodAttachpoint )
        self.PodData[podName].PodHandle = CreateUnitHPR(self.PodData[podName].PodUnitID, self:GetArmy(), location[1], location[2], location[3], 0, 0, 10)	
		self:AddUnitToStorage(self.PodData[podName].PodHandle)
        self.PodData[podName].Active = true
    end,
    
    OnTransportAttach = function(self, bone, attachee)
        attachee:SetDoNotTarget(true)
        Unit.OnTransportAttach(self, bone, attachee)
    end,
    
    OnTransportDetach = function(self, bone, attachee)
        attachee:SetDoNotTarget(false)
        Unit.OnTransportDetach(self, bone, attachee)
    end,
    
    FinishedBeingBuilt = State {
        Main = function(self)
            # Wait one tick to make sure this wasn't captured and we don't create an extra pod
            WaitSeconds(0.1)
            self.TowerCaptured = nil
            local bp = self:GetBlueprint()
            for k,v in bp.Economy.AircraftPods do
                if not self.PodData[v.PodName].Active then
                    if not self.PodData then
                        self.PodData = {}
                    end
                    self.PodData[v.PodName] = table.deepcopy( v )
                end
            end

            ChangeState( self, self.MaintainPodsState )
        end,
    },

    MaintainPodsState = State {
        Main = function(self)
		self.MaintainState = true							
				if self.Rebuilding then
					self:SetPodConsumptionRebuildRate( self.PodData[ self.Rebuilding ] )
					ChangeState( self, self.RebuildingPodState )
				end
				local bp = self:GetBlueprint()
				while true and not self.Rebuilding do
					for k,v in bp.Economy.AircraftPods do

						# Cost of new pod				 
						local podBP = self:GetAIBrain():GetUnitBlueprint( v.PodUnitID )
						self.PodData[v.PodName].EnergyRemain = podBP.Economy.BuildCostEnergy
						self.PodData[v.PodName].MassRemain = podBP.Economy.BuildCostMass

						self.PodData[v.PodName].BuildCostEnergy = podBP.Economy.BuildCostEnergy
						self.PodData[v.PodName].BuildCostMass = podBP.Economy.BuildCostMass
							
						self.PodData[v.PodName].BuildTime = podBP.Economy.BuildTime
						
						# Enable consumption for the rebuilding									   
						self:SetPodConsumptionRebuildRate(self.PodData[v.PodName])
                       
						# Change to RebuildingPodState
						self.Rebuilding = v.PodName
						self:SetWorkProgress(0.01)
						ChangeState( self, self.RebuildingPodState )
					end
					WaitSeconds(1)
				end
        end,
							   	
    },
    
    RebuildingPodState = State {
        Main = function(self)
            local rebuildFinished = false
            local podData = self.PodData[ self.Rebuilding ]
            repeat
                WaitTicks(1)
                # While the pod being built isn't finished
                # Update mass and energy given to new pod - update build bar
				if not self.pause and self:TransportHasAvailableStorage() then
					self:SetPodConsumptionRebuildRate( self.PodData[ self.Rebuilding ] )
					local fraction = self:GetResourceConsumed()
					local energy = self:GetConsumptionPerSecondEnergy() * fraction * 0.1
					local mass = self:GetConsumptionPerSecondMass() * fraction * 0.1
                
					self.PodData[ self.Rebuilding ].EnergyRemain = self.PodData[ self.Rebuilding ].EnergyRemain - energy
					self.PodData[ self.Rebuilding ].MassRemain = self.PodData[ self.Rebuilding ].MassRemain - mass
                
					self:SetWorkProgress( ( self.PodData[ self.Rebuilding ].BuildCostMass - self.PodData[ self.Rebuilding ].MassRemain ) / self.PodData[ self.Rebuilding ].BuildCostMass )
				
					if ( self.PodData[ self.Rebuilding ].EnergyRemain <= 0 ) and ( self.PodData[ self.Rebuilding ].MassRemain <= 0 ) then
                    rebuildFinished = true
					end
				else	
					self:SetConsumptionPerSecondEnergy(0)
					self:SetConsumptionPerSecondMass(0)
				end
            until rebuildFinished
            
            # create pod, deactivate consumption, clear building
            self:CreatePod( self.Rebuilding )
            self.Rebuilding = false
            self:SetWorkProgress(0)
            self:SetConsumptionPerSecondEnergy(0)
            self:SetConsumptionPerSecondMass(0)
            self:SetConsumptionActive(false)
            
            ChangeState( self, self.MaintainPodsState )
        end,
		
	
	},
    
    
#--------------------------------------------------------------------------
# CZAR
#--------------------------------------------------------------------------   

    
}
CZAR = Class(AirUnit) {
    OnStopBeingBuilt = function(self, builder, layer)
        Unit.OnStopBeingBuilt(self, builder, layer)
        ChangeState( self, self.FinishedBeingBuilt )
    end,
    
	
    PodTransfer = function(self, pod, podData)
        # Set the pod as active, set new parent and creator for the pod, store the pod handle
        if not self.PodData[pod.PodName].Active then
            if not self.PodData then
                self.PodData = {}
            end
            self.PodData[pod.PodName] = table.deepcopy( podData )
            self.PodData[pod.PodName].PodHandle = pod
            pod:SetParent(self, pod.PodName)
        end
    end,
    
   
    
    OnDestroy = function(self)
        Unit.OnDestroy(self)
        -- kill all the pods and set them inactive
        if self.PodData then
            for k,v in self.PodData do
                if v.Active and not v.PodHandle:IsDead() then
                    v.PodHandle:Kill()
                end
            end
        end
    end,
    
    OnStartBuild = function(self, unitBeingBuilt, order )
        Unit.OnStartBuild(self,unitBeingBuilt,order)
        local unitid = self:GetBlueprint().General.UpgradesTo
        if unitBeingBuilt:GetUnitId() == unitid and order == 'Upgrade' then
            self.NowUpgrading = true
            ChangeState( self, self.UpgradingState )
        end
    end,
    
	--pause control function
	SetPause = function(self) 
		self.pause = true
	end,
	
	SetUnPause = function(self) 
		self.pause = false
	end,
    
    SetPodConsumptionRebuildRate = function(self, podData)
        local bp = self:GetBlueprint()
		local buildRate = bp.Economy.BuildRate
        --# Get build rate of tower
        local energy_rate = ( podData.BuildCostEnergy / podData.BuildTime ) * buildRate
        local mass_rate = ( podData.BuildCostMass / podData.BuildTime ) * buildRate
        
        -- Set Consumption
		self:SetConsumptionPerSecondEnergy(energy_rate)
		self:SetConsumptionPerSecondMass(mass_rate)
		self:SetConsumptionActive(true)
    end,
    
    CreatePod = function(self, podName)
        local location = self:GetPosition( self.PodData[podName].PodAttachpoint )
        self.PodData[podName].PodHandle = CreateUnitHPR(self.PodData[podName].PodUnitID, self:GetArmy(), location[1], location[2], location[3], 0, 0, 10)	
		self:AddUnitToStorage(self.PodData[podName].PodHandle)
        self.PodData[podName].Active = true
    end,
    
    OnTransportAttach = function(self, bone, attachee)
        attachee:SetDoNotTarget(true)
        Unit.OnTransportAttach(self, bone, attachee)
    end,
    
    OnTransportDetach = function(self, bone, attachee)
        attachee:SetDoNotTarget(false)
        Unit.OnTransportDetach(self, bone, attachee)
    end,
    
    FinishedBeingBuilt = State {
        Main = function(self)
            # Wait one tick to make sure this wasn't captured and we don't create an extra pod
            WaitSeconds(0.1)
            self.TowerCaptured = nil
            local bp = self:GetBlueprint()
            for k,v in bp.Economy.AircraftPods do
                if not self.PodData[v.PodName].Active then
                    if not self.PodData then
                        self.PodData = {}
                    end
                    self.PodData[v.PodName] = table.deepcopy( v )
                end
            end

            ChangeState( self, self.MaintainPodsState )
        end,
    },

    MaintainPodsState = State {
        Main = function(self)
		self.MaintainState = true							
				if self.Rebuilding then
					self:SetPodConsumptionRebuildRate( self.PodData[ self.Rebuilding ] )
					ChangeState( self, self.RebuildingPodState )
				end
				local bp = self:GetBlueprint()
				while true and not self.Rebuilding do
					for k,v in bp.Economy.AircraftPods do

						# Cost of new pod				 
						local podBP = self:GetAIBrain():GetUnitBlueprint( v.PodUnitID )
						self.PodData[v.PodName].EnergyRemain = podBP.Economy.BuildCostEnergy
						self.PodData[v.PodName].MassRemain = podBP.Economy.BuildCostMass

						self.PodData[v.PodName].BuildCostEnergy = podBP.Economy.BuildCostEnergy
						self.PodData[v.PodName].BuildCostMass = podBP.Economy.BuildCostMass
							
						self.PodData[v.PodName].BuildTime = podBP.Economy.BuildTime
						
						# Enable consumption for the rebuilding									   
						self:SetPodConsumptionRebuildRate(self.PodData[v.PodName])
                       
						# Change to RebuildingPodState
						self.Rebuilding = v.PodName
						self:SetWorkProgress(0.01)
						ChangeState( self, self.RebuildingPodState )
					end
					WaitSeconds(1)
				end
        end,
							   	
    },
    
    RebuildingPodState = State {
        Main = function(self)
            local rebuildFinished = false
            local podData = self.PodData[ self.Rebuilding ]
            repeat
                WaitTicks(1)
                # While the pod being built isn't finished
                # Update mass and energy given to new pod - update build bar
				if not self.pause and self:TransportHasAvailableStorage() then
					self:SetPodConsumptionRebuildRate( self.PodData[ self.Rebuilding ] )
					local fraction = self:GetResourceConsumed()
					local energy = self:GetConsumptionPerSecondEnergy() * fraction * 0.1
					local mass = self:GetConsumptionPerSecondMass() * fraction * 0.1
                
					self.PodData[ self.Rebuilding ].EnergyRemain = self.PodData[ self.Rebuilding ].EnergyRemain - energy
					self.PodData[ self.Rebuilding ].MassRemain = self.PodData[ self.Rebuilding ].MassRemain - mass
                
					self:SetWorkProgress( ( self.PodData[ self.Rebuilding ].BuildCostMass - self.PodData[ self.Rebuilding ].MassRemain ) / self.PodData[ self.Rebuilding ].BuildCostMass )
				
					if ( self.PodData[ self.Rebuilding ].EnergyRemain <= 0 ) and ( self.PodData[ self.Rebuilding ].MassRemain <= 0 ) then
                    rebuildFinished = true
					end
				else	
					self:SetConsumptionPerSecondEnergy(0)
					self:SetConsumptionPerSecondMass(0)
				end
            until rebuildFinished
            
            # create pod, deactivate consumption, clear building
            self:CreatePod( self.Rebuilding )
            self.Rebuilding = false
            self:SetWorkProgress(0)
            self:SetConsumptionPerSecondEnergy(0)
            self:SetConsumptionPerSecondMass(0)
            self:SetConsumptionActive(false)
            
            ChangeState( self, self.MaintainPodsState )
        end,
		
	
	},
    
}