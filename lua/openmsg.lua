#****************************************************************************
#**
#**  File     :  /lua/openmsg.lua
#**  Author(s): LinLin
#**
#**  Summary  : Open Message
#**
#**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local ScenarioFramework = import('/lua/ScenarioFramework.lua')
local SimUtil = import('/lua/SimUtils.lua')

OpenMessage = function()
	ForkThread(PrintOpener,'游戏参数:')
	ForkThread(PrintOpener,'游戏终结者造价:'..ScenarioInfo.Options.Terminator..'倍')
	ForkThread(PrintOpener,'人口上限:'..ScenarioInfo.Options.UnitCap)
	ForkThread(PrintOpener,'先陆T4后空T4:'..ScenarioInfo.Options.LandT4First)
	ForkThread(PrintOpener,'先反核后核弹:'..ScenarioInfo.Options.AntinukeFirst)
end
	
	
PrintOpener = function(UBBBPID)
	
		PrintText(UBBBPID, 20, '#FFB6C1', 10, 'center')
	
end