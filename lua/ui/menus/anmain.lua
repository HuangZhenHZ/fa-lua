--*****************************************************************************
--* File: lua/modules/ui/menus/main.lua
--* Author: Chris Blackwell, Evan Pongress
--* Summary: create main menu screen
--*
--* Copyright � 2005 Gas Powered Games, Inc.  All rights reserved.
--*****************************************************************************

local UIUtil = import('/lua/ui/uiutil.lua')
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local EffectHelpers = import('/lua/maui/effecthelpers.lua')
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local MenuCommon = import('/lua/ui/menus/menucommon.lua')
local MultiLineText = import('/lua/maui/multilinetext.lua').MultiLineText
local Button = import('/lua/maui/button.lua').Button
local Group = import('/lua/maui/group.lua').Group
local Prefs = import('/lua/user/prefs.lua')
local Tooltip = import('/lua/ui/game/tooltip.lua')
local MapUtil = import('/lua/ui/maputil.lua')
local TooltipInfo = import('/lua/ui/help/tooltips.lua')
local Movie = import('/lua/maui/movie.lua').Movie
local Mods = import('/lua/mods.lua')
local GetVersion = import('/lua/version.lua').GetVersion
local mapErrorDialog = false
local TOOLTIP_DELAY = 1
local menuFontColor = 'feff77' --'FFbadbdb' (default grey-blue) #feff77 (light yellow) #edd570 (gold)
local menuFontColorTitle = 'EEEEEE'
local menuFontColorAlt = 'feff77' --currently the same as menuFontColor

local initial = true
local animation_active = false



function CreateUI()
	local ran = math.random(1,15)
    UIUtil.SetCurrentSkin('uef')
    import('/lua/ui/game/gamemain.lua').supressExitDialog = false
    local mainMenu = {}

    -- this should be shown if there are no profiles
    if not GetPreference("profile.current") then
			import('/lua/ui/dialogs/profile.lua').CreateDialog(function()
           	CreateUI()
        end)
        return
    end

    -- BACKGROUND
    local parent = UIUtil.CreateScreenGroup(GetFrame(0), "Main Menu ScreenGroup")
	
        local background = Bitmap(parent, "/textures/ui/common/BACKGROUND/m2/m2-background-paint" .. ran .. "_bmp.dds")
	function CreateBackImage(parent)
	
		LayoutHelpers.AtCenterIn(background, parent)
		LayoutHelpers.FillParentPreserveAspectRatio(background, parent)
	end
    backImage = CreateBackImage(parent)
    local darker = Bitmap(parent)
    LayoutHelpers.FillParent(darker, parent)
    darker:SetSolidColor('200000')
    darker:SetAlpha(.5)
    darker:Hide()
	

    -- BORDER, LOGO and TEXT
    local border = Group(parent, "border")
    LayoutHelpers.FillParent(border, parent)
	
	local LoadingTips = Bitmap(border, '/textures/ui/common/BUTTON/mediumai/logo2NV2.dds')
    LayoutHelpers.AtHorizontalCenterIn(LoadingTips, border)
	LayoutHelpers.AtVerticalCenterIn(LoadingTips, border,-100)--logo2
	--LayoutHelpers.AtTopIn(LoadingTips, border,100)--logo3
	LoadingTips.Depth:Set(60)
	
	local GameverTips = Bitmap(border, '/textures/ui/common/BUTTON/mediumai/Verlogo.dds')
    LayoutHelpers.AtLeftIn(GameverTips, border)
	LayoutHelpers.AtTopIn(GameverTips, border)--logo2
	--LayoutHelpers.AtTopIn(GameverTips, border,100)--logo3
	GameverTips.Depth:Set(60)
    -- music
--local ambientSoundHandle = PlaySound(Sound({Cue = "AMB_Menu_Loop", Bank = "AmbientTest",})) 很难听

    local musicHandle = false
    function StartMusic()
        if not musicHandle then
            musicHandle = PlaySound(Sound({Cue = "Main_Menu", Bank = "Music",}))
        end
    end
    
    function StopMusic()
        if musicHandle then
            StopSound(musicHandle)
            musicHandle = false
        end
    end
    
    parent.OnDestroy = function()
--[[        if ambientSoundHandle then
            StopSound(ambientSoundHandle)
            ambientSoundHandle = false
        end--]]
        StopMusic()
    end
    
    StartMusic()
	

    -- TOP-LEVEL GROUP TO PARENT ALL DYNAMIC CONTENT
	local topLevelGroup = Group(border, "topLevelGroup")
    LayoutHelpers.FillParent(topLevelGroup, border)
    topLevelGroup.Depth:Set(100)

    -- MAIN MENU
    local mainMenuGroup = Group(topLevelGroup, "mainMenuGroup")
    mainMenuGroup.Width:Set(0)
    mainMenuGroup.Height:Set(0)
    mainMenuGroup.Left:Set(0)
    mainMenuGroup.Top:Set(0)
    mainMenuGroup.Depth:Set(101)
	LayoutHelpers.AtBottomIn(mainMenuGroup, border)
        --------------------- 23640 UI
	    local StartGameButton = UIUtil.CreateButtonWithDropshadow(mainMenuGroup, '/BUTTON/mediumai/Start/')--开始游戏
			LayoutHelpers.AtLeftIn(StartGameButton, mainMenuGroup)
			LayoutHelpers.AtBottomIn(StartGameButton, mainMenuGroup, 250)
			LayoutHelpers.AtHorizontalCenterIn(StartGameButton, border)

		local LANButton = UIUtil.CreateButtonWithDropshadow(mainMenuGroup, '/BUTTON/mediumai/LANgame/')--LAN(子)
			LayoutHelpers.AtLeftIn(LANButton, mainMenuGroup)
			LayoutHelpers.AtBottomIn(LANButton, mainMenuGroup, 250)
			LayoutHelpers.AtHorizontalCenterIn(LANButton, border)
			
		local ZYButton = UIUtil.CreateButtonWithDropshadow(mainMenuGroup, '/BUTTON/mediumai/ZY/')--战役(子)
			LayoutHelpers.AtLeftIn(ZYButton, mainMenuGroup)
			LayoutHelpers.AtBottomIn(ZYButton, mainMenuGroup, 215)
			LayoutHelpers.AtHorizontalCenterIn(ZYButton, border)

		local DLZYButton = UIUtil.CreateButtonWithDropshadow(mainMenuGroup, '/BUTTON/mediumai/ZYDL/')--独立战役(子)
			LayoutHelpers.AtLeftIn(DLZYButton, mainMenuGroup)
			LayoutHelpers.AtBottomIn(DLZYButton, mainMenuGroup, 180)
			LayoutHelpers.AtHorizontalCenterIn(DLZYButton, border)
			
		local ZYBackButton = UIUtil.CreateButtonWithDropshadow(mainMenuGroup, '/BUTTON/mediumai/BackB/')--返回(子)
			LayoutHelpers.AtLeftIn(ZYBackButton, mainMenuGroup)
			LayoutHelpers.AtBottomIn(ZYBackButton, mainMenuGroup, 145)
			LayoutHelpers.AtHorizontalCenterIn(ZYBackButton, border)
			
		local ReplaysButton = UIUtil.CreateButtonWithDropshadow(mainMenuGroup, '/BUTTON/mediumai/Replays/')--录像回放
			LayoutHelpers.AtLeftIn(ReplaysButton, mainMenuGroup)
			LayoutHelpers.AtBottomIn(ReplaysButton, mainMenuGroup, 215)
			LayoutHelpers.AtHorizontalCenterIn(ReplaysButton, border)
			
		local SettingsButton = UIUtil.CreateButtonWithDropshadow(mainMenuGroup, '/BUTTON/mediumai/Settings/')--游戏设置
			LayoutHelpers.AtLeftIn(SettingsButton, mainMenuGroup)
			LayoutHelpers.AtBottomIn(SettingsButton, mainMenuGroup, 180)
			LayoutHelpers.AtHorizontalCenterIn(SettingsButton, border)
			
		local ExitgameButton = UIUtil.CreateButtonWithDropshadow(mainMenuGroup, '/BUTTON/mediumai/Exitgame/')--退出游戏
			LayoutHelpers.AtLeftIn(ExitgameButton, mainMenuGroup)
			LayoutHelpers.AtBottomIn(ExitgameButton, mainMenuGroup, 145)
			LayoutHelpers.AtHorizontalCenterIn(ExitgameButton, border)
			
		local SElogoButton = UIUtil.CreateButtonWithDropshadow(mainMenuGroup, '/BUTTON/mediumai/SElogo/')--SElogo
			LayoutHelpers.AtBottomIn(SElogoButton, mainMenuGroup)
			LayoutHelpers.AtHorizontalCenterIn(SElogoButton, border)
			
		local ProfButton = UIUtil.CreateButtonWithDropshadow(mainMenuGroup, '/BUTTON/mediumai/Prof/')--Proflogo
			LayoutHelpers.AtTopIn(ProfButton, border)
			LayoutHelpers.AtRightIn(ProfButton, border)
			
			ZYButton:Hide()
			DLZYButton:Hide()
			ZYBackButton:Hide()
			LANButton:Hide()
		StartGameButton.OnClick = function()
			StartGameButton:Hide()
			ReplaysButton:Hide()
			SettingsButton:Hide()
			ExitgameButton:Hide()
			ZYButton:Show()
			DLZYButton:Show()
			ZYBackButton:Show()
			LANButton:Show()
		end
		LANButton.OnClick = function()
		ButtonLAN()
		end
		ZYButton.OnClick = function()
		ButtonCampaign()
		end
		DLZYButton.OnClick = function()
		ButtonSkirmish()
		end
		ZYBackButton.OnClick = function()
			ZYButton:Hide()
			DLZYButton:Hide()
			ZYBackButton:Hide()
			LANButton:Hide()
			StartGameButton:Show()
			ReplaysButton:Show()
			SettingsButton:Show()
			ExitgameButton:Show()
		end
		ReplaysButton.OnClick = function()
		ButtonReplay()
		end
		SettingsButton.OnClick = function()
		ButtonOptions()
		end
		ExitgameButton.OnClick = function()
		ButtonExit()
		end
		ProfButton.OnClick = function()
		ButtonProf()
		end
	--------------------- 23640 UI 


	function SetEscapeHandle(action)
        import('/lua/ui/uimain.lua').SetEscapeHandler(function() action() end)
    end
	
    function MenuBuild(menuTable, center)

        -- set final dimensions/placement of mainMenuGroup
        mainMenuGroup.Height:Set(1024)
        mainMenuGroup.Width:Set(768)
        LayoutHelpers.AtHorizontalCenterIn(mainMenuGroup, border)
    end


    function MenuHide(callback)
            mainMenuGroup:Hide()
			GameverTips:Hide()
			background:Hide()
            --logo:Hide()
            mainMenuGroup.Depth:Set(50)        -- setting depth below topLayerGroup (100) to avoid the button glow persisting when overlays are up
            if callback then 
			callback()
			end
        
    end
	
	function MenuShow()
        mainMenuGroup.Depth:Set(101)    -- and setting it back again
        mainMenuGroup:Show()
		GameverTips:Show()
        --logo:Show()
		background:Show()
        --legalText:Show()
			ZYButton:Hide()
			DLZYButton:Hide()
			ZYBackButton:Hide()
			LANButton:Hide()
    end
	


    -- BUTTON FUNCTIONS
    function TutorialPrompt(callback)
        if Prefs.GetFromCurrentProfile('MenuTutorialPrompt') then
            callback()
        else
            Prefs.SetToCurrentProfile('MenuTutorialPrompt', true)
            UIUtil.QuickDialog(GetFrame(0), "<LOC EXITDLG_0006>This appears to be your first time playing Supreme Commander: Forged Alliance. Would you like to play the tutorial before you begin?", 
                "<LOC _Yes>", function()
                        StopMusic()
                        parent:Destroy()
                        LaunchSinglePlayerSession(
                            import('/lua/SinglePlayerLaunch.lua').SetupCampaignSession(
                                import('/lua/ui/maputil.lua').LoadScenario('/maps/X1CA_TUT/X1CA_TUT_scenario.lua'), 
                                2, nil, nil, true
                            )
                        )
                    end,
                "<LOC _No>", callback,
                nil, nil,
                true,  {worldCover = true, enterButton = 1, escapeButton = 2})
        end
    end
    
    function ButtonCampaign()
        TutorialPrompt(function()
                StopMusic()
                parent:Destroy()
                import('/lua/ui/campaign/selectcampaign.lua').CreateUI()
        end)
    end

    function ButtonLAN()
        MenuHide(function()
            import('/lua/ui/lobby/gameselect.lua').CreateUI(topLevelGroup, function() MenuShow() SetEscapeHandle(ButtonExit) end)
        end)
    end

    function ButtonSkirmish()
        TutorialPrompt(function()
            MenuHide(function()
                local function StartLobby(scenarioFileName)
                    local playerName = Prefs.GetCurrentProfile().Name or "Unknown"
                    local lobby = import('/lua/ui/lobby/lobby.lua')
                    lobby.CreateLobby('None', 0, playerName, nil, nil, topLevelGroup, function() MenuShow() SetEscapeHandle(ButtonExit) end)
                    lobby.HostGame(playerName .. "'s Skirmish", scenarioFileName, true)
                end
                local lastScenario = Prefs.GetFromCurrentProfile('LastScenario') or UIUtil.defaultScenario
                StartLobby(lastScenario)
            end)
        end)
    end

    function ButtonReplay()
        MenuHide(function()
            import('/lua/ui/dialogs/replay.lua').CreateDialog(topLevelGroup, true, function() MenuShow() SetEscapeHandle() end)
        end)
    end

    function ButtonMod()
        MenuHide(function()
            local function OnOk(selectedmods)
                Mods.SetSelectedMods(selectedmods)
                MenuShow()
                SetEscapeHandle()
            end
            import('/lua/ui/dialogs/modmanager.lua').CreateDialog(topLevelGroup, false, OnOk)
        end)
    end

    function ButtonOptions()
        MenuHide(function()
            import('/lua/ui/dialogs/options.lua').CreateDialog(topLevelGroup, function() MenuShow() SetEscapeHandle(ButtonExit) end)    
        end)
    end


    function ButtonCredits()
        parent:Destroy()
        import('/lua/ui/menus/credits.lua').CreateDialog(function() import('/lua/ui/menus/main.lua').CreateUI() end)
    end

    function ButtonEULA()
        MenuHide(function()
            import('/lua/ui/menus/eula.lua').CreateEULA(topLevelGroup, function() MenuShow() SetEscapeHandle() end)
        end)
    end

	function ButtonProf()
			  
                import('/lua/ui/dialogs/profile.lua').CreateDialog(function()
                end)

					
	end
    local exitDlg = nil

    function ButtonExit()
        
        if not exitDlg then
            exitDlg = UIUtil.QuickDialog(GetFrame(0), "<LOC EXITDLG_0003>Are you sure you'd like to exit?", 
                        "<LOC _Yes>", function()
                            StopMusic()
                            parent:Destroy()
                            ExitApplication()
                            end,
                        "<LOC _No>", function() exitDlg = nil end,
                        nil, nil,
                        true,  {worldCover = true, enterButton = 1, escapeButton = 2})
        end                        
    end

    -- START

    MenuBuild('home', true)

    FlushEvents()
end
