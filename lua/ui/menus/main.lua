local Prefs = import('/lua/user/prefs.lua')
local options = Prefs.GetFromCurrentProfile('options')
local anmain = import('/lua/ui/menus/anmain.lua')
local scmain = import('/lua/ui/menus/scmain.lua')
local famain = import('/lua/ui/menus/famain.lua')
local main

function CreateUI()
	if options.gui_main_style == 2 then
		main = anmain
	elseif options.gui_main_style == 1 then
		main = scmain
	elseif options.gui_main_style == 0 then
		main = famain
	else
		main = famain
	end
	main.CreateUI()
	if HasCommandLineArg ("/host") or HasCommandLineArg ("/address") then
		main.ButtonLAN()
	--else
	--	main.CreateUI()
	end
end