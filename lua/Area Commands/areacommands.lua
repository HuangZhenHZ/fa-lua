local	Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local	UIUtil = import('/lua/ui/uiutil.lua')

local	mouseStartWorldPos = false
local	mouseEndWorldPos = false
local	marker = false
local	currentCommand = false
local	commandTable = {
	{"Attack", "ffff0000", "RULEUCC_Attack"},
	{"Reclaim",	"ffffff00",	"RULEUCC_Reclaim"},
	{"Rebuild",	"ff0000ff",	"RULEUCC_Repair"},
	{"Guard",	"ff00ff00",	"RULEUCC_Guard"},
}
local	commandTableindex	=	false
local	currentRebuilds	=	{}
local	drawingThread	=	false
local	drawingPoints	=	{}
local	cancelBoxTable = false
local	rebuildEngieer={}

function Init()
	--IN_AddKeyMapTable({['X'] = {action =	'ui_lua	import("/mods/Area Commands/areacommands.lua").CommandFunction()'},})
	import('/lua/ui/game/gamemain.lua').AddBeatFunction(ShowAreas)
end

function ShowAreas()
	if Sync.rebuildEngieer then
		rebuildEngieer = Sync.rebuildEngieer	
	end
	if Sync.currentRebuilds	then
		currentRebuilds	=	Sync.currentRebuilds
	end
	if not IsKeyDown('Shift')	then
		local	WorldCamera	=	GetCamera('WorldCamera')
		for	i, area	in currentRebuilds do
			rebuildCancelBox(i,	area[3])
			SimCallback({Func	=	'DrawRectangle', Args	=	{rebuildAreas	=	true,	color	=	commandTable[3][2],	FadeTime = 0.5,	Owner	=	GetFocusArmy(),	area = area}})
			local	zoomLevel	=	WorldCamera:GetZoom()
			for	j,button in	cancelBoxTable do
				if cancelBoxTable[j] then
					if zoomLevel < 80	then
						cancelBoxTable[j].Height:Set(30-zoomLevel/4)
						cancelBoxTable[j].Width:Set(30-zoomLevel/4)
					else
						cancelBoxTable[j].Height:Set(10)
						cancelBoxTable[j].Width:Set(10)
					end

					
				end
				
			end
			for	h, button	in cancelBoxTable	do
				button:Destroy()
			end
			cancelBoxTable = false	
			
		end
							
	else
		for	h, area2 in	currentRebuilds	do
			rebuildCancelBox(h,	area2[3])
		end	
	end
end

function rebuildCancelBox(id,	position)
	if not cancelBoxTable	then
		cancelBoxTable = {}
	end
	
	if not cancelBoxTable[id]	then
		local	worldview	=	import('/lua/ui/game/worldview.lua').viewLeft
		cancelBoxTable[id] = Bitmap(worldview)
		cancelBoxTable[id]:SetSolidColor('Red')
		cancelBoxTable[id].Right:Set(100)
		cancelBoxTable[id].Top:Set(100)
		cancelBoxTable[id].Width:Set(10)
		cancelBoxTable[id].Height:Set(10)
		cancelBoxTable[id].Depth:Set(100)
		cancelBoxTable[id].OnFrame = function(self)
			local	viewPos	=	worldview:Project(position)
			local	screenPos	=	{viewPos[1]	+	worldview.Left(),	viewPos[2] + worldview.Top()}
			cancelBoxTable[id].Right:Set(screenPos[1])
			cancelBoxTable[id].Top:Set(screenPos[2])
		end
		cancelBoxTable[id].HandleEvent = function(self,	event)
			if event.Type	== 'ButtonPress' then		
				
				local	canceIndex
						
				for	i,unitEngineers	in rebuildEngieer	do
					for	j,unitEngineerID in	unitEngineers	do
						if unitEngineerID==id	then
							canceIndex=i
						end	
					end
				end
						
				local	cancelGroup=rebuildEngieer[canceIndex]
				
				
				for	k	,cancelEngineerID	in cancelGroup do
					local	newRebuild=false
					
					for	l=canceIndex+1,table.getsize(rebuildEngieer) do
						for	m	,Engineer	in rebuildEngieer[l] do
			
							if cancelEngineerID==Engineer		then
								newRebuild=true
							end
							
						end	
					end
					
					if not newRebuild	then
						SimCallback({Func	=	'ClearBuildArea',	Args = cancelEngineerID})
						cancelBoxTable[cancelEngineerID]:Destroy()
					end
					local	newRebuild=false
				end
				
				table.remove(rebuildEngieer, canceIndex)
				Sync.rebuildEngieer=rebuildEngieer
				
				return true
			end
		end
		cancelBoxTable[id]:SetNeedsFrameUpdate(true)
	end
end

function DrawRectangle(args)
	if GetFocusArmy()	!= args.Owner	then return	end
	local	startTime	=	GetGameTimeSeconds()
	if args.rebuildAreas ==	true then
		local	left = math.min(args.area[1][1], args.area[2][1])
		local	top	=	math.min(args.area[1][3],	args.area[2][3])
		local	right	=	math.max(args.area[1][1],	args.area[2][1])
		local	bottom = math.max(args.area[1][3], args.area[2][3])
		table.insert(drawingPoints,	{start = VECTOR3(left, GetTerrainHeight(left,	top),	top),	
						finish = VECTOR3(right,	GetTerrainHeight(right,	top),	top),	
						color	=	string.sub(args.color,3,8),	time = startTime})
		table.insert(drawingPoints,	{start = VECTOR3(right,	GetTerrainHeight(right,	top),	top),	
						finish = VECTOR3(right,	GetTerrainHeight(right,	bottom), bottom),	
						color	=	string.sub(args.color,3,8),	time = startTime})
		table.insert(drawingPoints,	{start = VECTOR3(right,	GetTerrainHeight(right,	bottom), bottom),	
						finish = VECTOR3(left, GetTerrainHeight(left,	bottom), bottom),	
						color	=	string.sub(args.color,3,8),	time = startTime})
		table.insert(drawingPoints,	{start = VECTOR3(left, GetTerrainHeight(left,	bottom), bottom),	
						finish = VECTOR3(left, GetTerrainHeight(left,	top),	top),	
						color	=	string.sub(args.color,3,8),	time = startTime})
	else
		local	left = math.min(args.corners[1][1],	args.corners[2][1])
		local	top	=	math.min(args.corners[1][3], args.corners[2][3])
		local	right	=	math.max(args.corners[1][1], args.corners[2][1])
		local	bottom = math.max(args.corners[1][3],	args.corners[2][3])
		table.insert(drawingPoints,	{start = VECTOR3(left, GetTerrainHeight(left,	top),	top),	
						finish = VECTOR3(right,	GetTerrainHeight(right,	top),	top),	
						color	=	string.sub(args.color,3,8),	time = startTime})
		table.insert(drawingPoints,	{start = VECTOR3(right,	GetTerrainHeight(right,	top),	top),	
						finish = VECTOR3(right,	GetTerrainHeight(right,	bottom), bottom),	
						color	=	string.sub(args.color,3,8),	time = startTime})
		table.insert(drawingPoints,	{start = VECTOR3(right,	GetTerrainHeight(right,	bottom), bottom),	
						finish = VECTOR3(left, GetTerrainHeight(left,	bottom), bottom),	
						color	=	string.sub(args.color,3,8),	time = startTime})
		table.insert(drawingPoints,	{start = VECTOR3(left, GetTerrainHeight(left,	bottom), bottom),	
						finish = VECTOR3(left, GetTerrainHeight(left,	top),	top),	
						color	=	string.sub(args.color,3,8),	time = startTime})
	end
	if not drawingThread then
		drawingThread	=	ForkThread(function()
			while	table.getsize(drawingPoints) > 0 do
				local	dirtyTable = {}
				for	i, line	in drawingPoints do
					if GetGameTimeSeconds()	-	line.time	>	args.FadeTime	then
						table.insert(dirtyTable, i)
					else
						local	alpha	=	STR_itox(math.floor(math.max((1	-	((GetGameTimeSeconds() - line.time)/args.FadeTime))*255, 20)))
						DrawLine(line.start, line.finish,	alpha..line.color)
					end
				end
				for	_, index in	dirtyTable do
					table.remove(drawingPoints,	index)

				end
				WaitSeconds(.2)
			end
			drawingThread	=	false
		end)
	end
end

function CommandFunction()
	if marker	then
		if not commandTableindex or	table.getn(commandTable) <=	commandTableindex	then
			commandTableindex	=	1
		else
			commandTableindex	=	commandTableindex	+	1
		end
		currentCommand = commandTable[commandTableindex][1]
		marker:SetSolidColor(commandTable[commandTableindex][2])
	end
end

function DragFunction()
	if GetSelectedUnits()	then
		if not marker	then
			marker = Bitmap(GetFrame(0))
			local	mouseStartScreenPos	=	GetMouseScreenPos()
			mouseStartWorldPos = GetMouseWorldPos()
			marker.Left:Set(mouseStartScreenPos[1])
			marker.Top:Set(mouseStartScreenPos[2])
			marker:DisableHitTest()
			marker:SetAlpha(0.2)
			marker:SetNeedsFrameUpdate(true)
			marker.OnFrame = function(self)
				local	currentMousePos	=	GetMouseScreenPos()
				marker.Right:Set(GetMouseScreenPos()[1])
				marker.Bottom:Set(GetMouseScreenPos()[2])
			end
		end
		CommandFunction()
	end
end

function GiveCommand()
	if marker	then
		marker:Destroy()
		marker = false
		mouseEndWorldPos = GetMouseWorldPos()
		SimCallback({Func	=	'DrawRectangle', Args	=	{corners = {mouseStartWorldPos,	mouseEndWorldPos}, color = commandTable[commandTableindex][2], FadeTime	=	4, Owner = GetFocusArmy()}})
		SimCallback({	Func = 'AreaCommandCallback',
			Args = {Start	=	mouseStartWorldPos,
				End	=	mouseEndWorldPos,
				Army = GetFocusArmy(),
				Command	=	currentCommand,
				AddToQueue = IsKeyDown('Shift'),
			},
		}, true)
		commandTableindex	=	false
		currentCommand = false
	end

end

function GiveCommandRebuild()
	if marker	then
		marker:Destroy()
		marker = false
		mouseEndWorldPos = GetMouseWorldPos()
		SimCallback({Func	=	'DrawRectangle', Args	=	{corners = {mouseStartWorldPos,	mouseEndWorldPos}, color = commandTable[commandTableindex][2], FadeTime	=	4, Owner = GetFocusArmy()}})
		SimCallback({	Func = 'AreaCommandRebuildCallback',
			Args = {Start	=	mouseStartWorldPos,
				End	=	mouseEndWorldPos,
				Army = GetFocusArmy(),
				Command	=	currentCommand,
				AddToQueue = IsKeyDown('Shift'),
			},
		}, true)
		commandTableindex	=	false
		currentCommand = false 


	end

end

--send units area	command	to attack\reclan\guard\rebuild
function AreaCommand(Data, Units)
	if Units then
		if not Data.AddToQueue then
			IssueClearCommands(Units)
		end
		local	left = math.min(Data.Start[1], Data.End[1])
		local	top	=	math.min(Data.Start[3],	Data.End[3])
		local	right	=	math.max(Data.Start[1],	Data.End[1])
		local	bottom = math.max(Data.Start[3], Data.End[3])
		local	rectangle	=	Rect(left, top,	right, bottom)
		local	ecPosition = {(rectangle.x0	+	rectangle.x1)/2, 0,	(rectangle.y0	+	rectangle.y1)/2}
	
		

		
		local	AllUnits = GetUnitsInRect(rectangle)
		if table.getsize(AllUnits)>1000	then
				AllUnits={}
		end
		
		local	Engineers	=	EntityCategoryFilterDown(categories.ENGINEER,	Units)
		local	ents={}
		if	table.getsize(Engineers)>0 then
			ents = GetEntitiesInRect(rectangle)
			if table.getsize(ents)>1000	then
				ents={}
			end
		end	

			
		local	selfCategory = false
		local	selfCategory2	=	false
		local	selfCategory3	=	false
		local	selfCategory4	=	false
		local	EnemyAirUnits	=	{}
		local	EnemyNoAirUnits	=	{}
		local	SelfAttAirUnits	=	{}
		local	SelfNoAttAirUnits	=	{}
		local	EnemyStructureUnits	=	{}
		local	SelfBoomUnits	=	{}
		
		if AllUnits	then					
			for	i, TargertUnit in	AllUnits do		
					for	j, v in	TargertUnit:GetBlueprint().Categories	do
						if v ==	'AIR'	then
							selfCategory = true
						elseif v ==	'MOBILE' then
							selfCategory2	=	true
						elseif v ==	'STRUCTURE'	then
							selfCategory3	=	true	
						end
					end
					if selfCategory	 and selfCategory2	then
							table.insert(EnemyAirUnits,	TargertUnit)
					else
							table.insert(EnemyNoAirUnits,	TargertUnit)	
					end
					
					if selfCategory3	then
							table.insert(EnemyStructureUnits,	TargertUnit)
					end
					selfCategory = false
					selfCategory2	=	false
					selfCategory3	=	false
					selfCategory4	=	false
			end
		 end
		 
		if Units then	
			for	y,SelfUnit in	Units	do
				for	j, v in	SelfUnit:GetBlueprint().Categories do
					if v ==	'AIR'	then
						selfCategory = true
					elseif v ==	'ANTIAIR'	then
						selfCategory2	=	true
					elseif v ==	'BOMBER' or	 v ==	'GROUNDATTACK' then
							selfCategory3	=	true	 
					elseif v ==	'EXPERIMENTAL' then
							selfCategory4	=	true		
					end
				end
				if selfCategory	 and selfCategory2 and not selfCategory3	and	not	selfCategory4	 then
						table.insert(SelfAttAirUnits,	SelfUnit)
				else
						table.insert(SelfNoAttAirUnits,	SelfUnit)			
				end
				if selfCategory3	then
						table.insert(SelfBoomUnits,	SelfUnit)	
				end
				
				selfCategory = false
				selfCategory2	=	false
				selfCategory3	=	false
				selfCategory4	=	false
			end
		end
		
		if EnemyNoAirUnits and SelfNoAttAirUnits then
			local	Targets	=	{}
			for	i, unit	in EnemyNoAirUnits do
				if IsEnemy(Data.Army,	unit:GetArmy())	then
					local	position = unit:GetPosition()
					if position[1] < rectangle.x1	and	position[1]	>	rectangle.x0 and position[3] < rectangle.y1	and	position[3]	>	rectangle.y0 and unit:GetBlip(Data.Army) then
						table.insert(Targets,	unit:GetBlip(Data.Army))
					end
				end
			end
		
			SpreadCommandAtt(Data, SelfNoAttAirUnits,	Targets)
	 
		end
	 
	 
		if EnemyAirUnits and SelfAttAirUnits then
			local	Targets	=	{}
			for	i, unit	in EnemyAirUnits do
				if IsEnemy(Data.Army,	unit:GetArmy())	then
					local	position = unit:GetPosition()
					if position[1] < rectangle.x1	and	position[1]	>	rectangle.x0 and position[3] < rectangle.y1	and	position[3]	>	rectangle.y0 and unit:GetBlip(Data.Army) then
						table.insert(Targets,	unit:GetBlip(Data.Army))
					end
				end
			end
		
			SpreadCommandAtt(Data, SelfAttAirUnits,	Targets)
	 
		end
		
			if ents	and	Engineers	then
				local	Targets	=	{}
				for	k,v	in ents	do
					if (v.MassReclaim	and	v.MassReclaim	>	0) or	(v.EnergyReclaim and v.EnergyReclaim > 0)	then
						local	position = v:GetPosition()
						if position[1] < rectangle.x1	and	position[1]	>	rectangle.x0 and position[3] < rectangle.y1	and	position[3]	>	rectangle.y0 then
							table.insert(Targets,	v)
						end
					end
				end
				SpreadCommandRec(Data, Engineers,	Targets)
			end
		
		
			if AllUnits	then
				local	Targets	=	{}
				for	i, unit	in AllUnits	do
					if IsAlly(Data.Army, unit:GetArmy()) then
						local	position = unit:GetPosition()
						if position[1] < rectangle.x1	and	position[1]	>	rectangle.x0 and position[3] < rectangle.y1	and	position[3]	>	rectangle.y0 then
							table.insert(Targets,	unit)
						end
					end
				end
				SpreadCommandGuard(Data, Units,	Targets)
			end
		

	end
end


function AreaCommandRebuild(Data,	Units)
	if Units then
		if not Data.AddToQueue then
			IssueClearCommands(Units)
		end
		local	left = math.min(Data.Start[1], Data.End[1])
		local	top	=	math.min(Data.Start[3],	Data.End[3])
		local	right	=	math.max(Data.Start[1],	Data.End[1])
		local	bottom = math.max(Data.Start[3], Data.End[3])
		local	rectangle	=	Rect(left, top,	right, bottom)
		local	ecPosition = {(rectangle.x0	+	rectangle.x1)/2, 0,	(rectangle.y0	+	rectangle.y1)/2}
	
		local	sortfunc = function(rec1,	rec2)
			local	dist1	=	VDist2(ecPosition[1],	ecPosition[3], rec1:GetPosition()[1],	rec1:GetPosition()[3])
			local	dist2	=	VDist2(ecPosition[1],	ecPosition[3], rec2:GetPosition()[1],	rec2:GetPosition()[3])
			return dist1 < dist2
		end
		table.sort(Units,	sortfunc)

		
			
			
			local	Engineers	=	EntityCategoryFilterDown(categories.ENGINEER,	Units)
			
			--local	Engineers=units
			
			--rebuildEngieer = Sync.rebuildEngieer
			
			local	rebuildEngieerIDs={}
			for	i, unit	in Engineers do
				table.insert(rebuildEngieerIDs,unit:GetEntityId())
				if unit.RebuildThread	then
					currentRebuilds[unit:GetEntityId()]	=	nil
					unit.OnKilled	=	unit.oldKilled
					KillThread(unit.RebuildThread)
					unit.RebuildThread = false
				end
				unit.RebuildThread = unit:ForkThread(RebuildThread,	rectangle)
				currentRebuilds[unit:GetEntityId()]	=	{Data.Start, Data.End, {right, GetTerrainHeight(right, top), top}, GetFocusArmy()}
				local	oldKilled	=	unit.OnKilled
				unit.oldKilled = unit.OnKilled
				unit.OnKilled	=	function(self, instigator, type, overkillRatio)
					currentRebuilds[self:GetEntityId()]	=	nil
					Sync.currentRebuilds = currentRebuilds
					oldKilled(self,	instigator,	type,	overkillRatio)
				end
				Sync.currentRebuilds = currentRebuilds
			end
			
			table.insert(rebuildEngieer,rebuildEngieerIDs)
			Sync.rebuildEngieer=rebuildEngieer
			
	end
end


function getUnitsCenterPosition(Units)
	local	unitsX0	=	0
	local	unitsX1	=	0
	local	unitsY0	=	0
	local	unitsY1	=	0
	for	i,unit in	Units	do
		local	position = unit:GetPosition()
		if position[1] < unitsX0 or	unitsX0	== 0 then
			unitsX0	=	position[1]
		end
		if position[1] > unitsX1 then
			unitsX1	=	position[1]
		end
		if position[3] < unitsY0 or	unitsY0	== 0 then
			unitsY0	=	position[3]
		end
		if position[3] > unitsY1 then
			unitsY1	=	position[3]
		end
	end
	return {(unitsX0 + unitsX1)/2, 0,	(unitsY0 + unitsY1)/2}
end


--Spread area	target in	all	units
SpreadCommandAtt = function(Data,	Units, Targets)
	local	ucPosition = getUnitsCenterPosition(Units)
	local	sortfunc = function(rec1,	rec2)
		local	dist1	=	VDist2(ucPosition[1],	ucPosition[3], rec1:GetPosition()[1],	rec1:GetPosition()[3])
		local	dist2	=	VDist2(ucPosition[1],	ucPosition[3], rec2:GetPosition()[1],	rec2:GetPosition()[3])
		return dist1 < dist2
	end
	table.sort(Targets,	sortfunc)
	
	local	numUnits = table.getsize(Units)
	local	numTargets = table.getsize(Targets)
	local	repeatSize = 5
	local	j	=	0
	local	attIndex=0
	for	i,unit in	Units	do	
		
		while	j	<	5	do	
			attIndex=j*numUnits+i-1
				
			attIndex=	math.mod(attIndex,numTargets)
				
			IssueAttack({unit},	Targets[attIndex+1])	
			
			j=j+1	
			
		end
		j=0
	end
end

SpreadCommandRec = function(Data,	Units, Targets)
	local	ucPosition = getUnitsCenterPosition(Units)
	

	local	numUnits = table.getsize(Units)
	local	numTargets = table.getsize(Targets)

	local	dista,distb

	for	j=2,numTargets do
		for	i=numTargets,j,-1	do
			if j==2	then
				dista	=	VDist2(ucPosition[1],	ucPosition[3], Targets[i]:GetPosition()[1],	Targets[i]:GetPosition()[3]) 
				distb	=	VDist2(ucPosition[1],	ucPosition[3], Targets[i-1]:GetPosition()[1],	Targets[i-1]:GetPosition()[3])
			else
				dista	=	VDist2(Targets[j-2]:GetPosition()[1],	Targets[j-2]:GetPosition()[3], Targets[i]:GetPosition()[1],	Targets[i]:GetPosition()[3]) 
				distb	=	VDist2(Targets[j-2]:GetPosition()[1],	Targets[j-2]:GetPosition()[3], Targets[i-1]:GetPosition()[1],	Targets[i-1]:GetPosition()[3])
			end
			if dista <distb	then
				tempTarget=Targets[i-1]
				Targets[i-1]=Targets[i]
				Targets[i]=tempTarget
			end
		end
	end

	local	modRepeat=math.mod(numTargets,numUnits)
	local	repeatSize = (numTargets-modRepeat)/numUnits
	local	attIndex=1
	
	for	i,unit in	Units	do	
		if i>modRepeat then		
			for	j=1,repeatSize do		
				IssueReclaim({unit}, Targets[attIndex])	
				attIndex=attIndex+1
			end
		else
			for	j=1,repeatSize+1 do		
				IssueReclaim({unit}, Targets[attIndex])	
				attIndex=attIndex+1
			end
		end
	end
end


SpreadCommandGuard = function(Data,	Units, Targets)
	local	ucPosition = getUnitsCenterPosition(Units)
	local	sortfunc = function(rec1,	rec2)
		local	dist1	=	VDist2(ucPosition[1],	ucPosition[3], rec1:GetPosition()[1],	rec1:GetPosition()[3])
		local	dist2	=	VDist2(ucPosition[1],	ucPosition[3], rec2:GetPosition()[1],	rec2:GetPosition()[3])
		return dist1 < dist2
	end
	table.sort(Targets,	sortfunc)
	
	local	numUnits = table.getsize(Units)
	local	numTargets = table.getsize(Targets)
	local	repeatSize = 5
	local	j	=	0
	local	attIndex=0
	for	i,unit in	Units	do	
		
		while	j	<	10 do	 
			attIndex=j*numUnits+i-1
				
			attIndex=	math.mod(attIndex,numTargets)
				
			IssueGuard({unit}, Targets[attIndex+1])	
			
			j=j+1	
			
		end
		j=0
	end
end

--continue repire	and	rebuild	Structures
RebuildThread	=	function(self, Area)
	local	watchTable = {}
	local	center = {(Area.x0+Area.x1)/2, GetTerrainHeight((Area.x0+Area.x1)/2, (Area.y0+Area.y1)/2), (Area.y0+Area.y1)/2}
	local	selfCategory = ''
	local	selfCategory2	=	''
	for	j, v in	self:GetBlueprint().Categories do
		if v ==	'ENGINEER' then
			selfCategory = v
		elseif v ==	'TECH1'	or v ==	'TECH3'	or v ==	'TECH3'	or v ==	'COMMAND'	then
			selfCategory2	=	v
		end
	end
	if selfCategory	== 'ENGINEER'	and	selfCategory2	== 'TECH1' then
		selfCategory = 'BUILTBYTIER1ENGINEER'
	elseif selfCategory	== 'ENGINEER'	and	selfCategory2	== 'TECH2' then
		selfCategory = 'BUILTBYTIER2ENGINEER'
	elseif selfCategory	== 'ENGINEER'	and	selfCategory2	== 'TECH3' then
		selfCategory = 'BUILTBYTIER3ENGINEER'
	elseif selfCategory2 ==	'COMMAND'	then
		selfCategory = 'BUILTBYCOMMANDER'
	end
	
	while	not	self:IsDead()	do
		local	updateTable	=	{}
		local	AllUnits = GetUnitsInRect(Area)
		local	AllStructures	=	{}
		if AllUnits	then
			AllStructures	=	EntityCategoryFilterDown(categories.STRUCTURE, AllUnits)
		end
		
		for	i, unit	in AllStructures do
			if IsAlly(self:GetArmy(),	unit:GetArmy())	then
				local	position = unit:GetPosition()
				if position[1] < Area.x1 and position[1] > Area.x0 and position[3] < Area.y1 and position[3] > Area.y0 then
					updateTable[unit:GetEntityId()]	=	{unit, unit:GetBlueprint().BlueprintId,	unit:GetPosition(),	unit:GetBlueprint().Categories}
				end
			end
		end
		local	size = table.getsize(watchTable)
		for	i,unitData in	watchTable do
			if not unitData[1]:IsDead()	then
				if unitData[1]:GetHealth() < unitData[1]:GetMaxHealth()	and	not	watchTable[i].repairing	then
					IssueRepair({self},	unitData[1])
					watchTable[i].repairing	=	true
				end
				if watchTable[i].repairing and unitData[1]:GetHealth() ==	unitData[1]:GetMaxHealth() then
					watchTable[i].repairing	=	false
				end
			else
				for	j, v in	unitData[4]	do
																			WaitSeconds(2)
					--if v ==	selfCategory then
						IssueBuildMobile({self}, unitData[3],	unitData[2], {})
						watchTable[i]	=	nil
					--end
				end
			end
		end
		if self:IsIdleState()	then
			if VDist3(center,	self:GetPosition())	>	10 then
				IssueMove({self},	center)
			end
		end
		WaitSeconds(2)
	 

		for	i, v in	updateTable	do
			if not watchTable[i] then
				watchTable[i]	=	v
				watchTable[i].repairing	=	false
			end
		end
	end
end

function ClearBuildArea(id)
	local	unit = GetUnitById(id)
	currentRebuilds[id]	=	nil
	unit.OnKilled	=	unit.oldKilled
	KillThread(unit.RebuildThread)
	unit.RebuildThread = false
	Sync.currentRebuilds = currentRebuilds
end
