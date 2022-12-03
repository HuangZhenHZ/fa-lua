 --[[ ************************************************************************
 * File: lua/modules/ui/menus/main.lua
 * Authors: Chris Blackwell, Evan Pongress, and Contributors
 * Summary: create main menu screen
 *
 * Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
 ************************************************************************** ]]

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

local mapErrorDialog = false

local TOOLTIP_DELAY = 1
local menuFontColor = 'feff77' --'FFbadbdb' (default grey-blue) #feff77 (light yellow) #edd570 (gold)
local menuFontColorTitle = 'EEEEEE'
local menuFontColorAlt = 'feff77' --currently the same as menuFontColor

local initial = true
local animation_active = false
local animation_delay = 0.5

function CreateBackMovie(parent)
    local backMovie = Movie(parent)
    backMovie:Set('/movies/FMV_menu.sfd')
    LayoutHelpers.AtCenterIn(backMovie, parent)

    backMovie:Loop(true)
    backMovie:Play()

    local movRatio = backMovie.Width() / backMovie.Height()
    backMovie.Width:Set(function()
        local thisWidth = math.ceil(parent.Height() * movRatio)
        local thisHeight = parent.Height()
        if thisWidth < parent.Width() then
            thisWidth = parent.Width()
            thisHeight = math.ceil(parent.Width() / movRatio)
        end
        backMovie.Height:Set(thisHeight)
        return thisWidth
    end)
    return backMovie
end
function CreateBackImage(parent)
local background = Bitmap(parent, "/textures/ui/common/BACKGROUND/m2/m2-background-paint" .. 12 .. "_bmp.dds")
LayoutHelpers.AtCenterIn(background, parent)
LayoutHelpers.FillParentPreserveAspectRatio(background, parent)
end
function CreateUI()

    UIUtil.SetCurrentSkin('uef')
    import('/lua/ui/game/gamemain.lua').supressExitDialog = false
    local mainMenu = {}

    -- this should be shown if there are no profiles [FA]
    if not GetPreference("profile.current") then
        profileDlg = import('/lua/ui/dialogs/profile.lua').CreateDialog(function()
            CreateUI()
        end)
        return
    end

    -- to disable any button on the menu, just comment/delete the "action" key/value pair or set to nil
    local menuExtras = {
        title = '<LOC tooltipui0355>Extras',
        {
            name = '<LOC _Skirmish>',
            tooltip = 'mainmenu_skirmish',
            action = function() ButtonSkirmish() end,
        },
		{
            name = '<LOC _Campaign>',
            tooltip = 'mainmenu_campaign',
            action = function() ButtonCampaign() end,
        },
        {
            name = '<LOC _Tutorial>Tutorial',
            tooltip = 'mainmenu_tutorial',
            action = function() ButtonTutorial() end,
            color = menuFontColorAlt,
        },
        {
            name = '<LOC _Mod_Manager>',
            tooltip = 'mainmenu_mod',
            action = function() ButtonMod() end,
            color = menuFontColorAlt,
        },
        {
            name = '<LOC OPTIONS_0073>Credits',
            tooltip = 'options_credits',
            action = function() ButtonCredits() end,
        },
        {
            name = '<LOC OPTIONS_0086>EULA',
            tooltip = 'options_eula',
            action = function() ButtonEULA() end,
            color = menuFontColorAlt,
        },
        {
            name = '<LOC _Back>',
            action = function() ButtonBack() end,
            color = menuFontColorAlt,
        },
    }
    local menuTop = {
        --title = '<LOC _Main_Menu>Main Menu',
        title = '<LOC main_menu_0000>Forged Alliance',

        {
            name = '<LOC main_menu_0001>Multiplayer LAN',
            tooltip = 'mainmenu_mp',
            action = function() ButtonLAN() end,
        },
        {
            name = '<LOC _Replay>',
            tooltip = 'mainmenu_replay',
            action = function() ButtonReplay() end,
        },
        {
            name = '<LOC tooltipui0355>Extras',
            tooltip = 'mainmenu_extras',
            action = function() ButtonExtras() end,
        },
        {
            name = '<LOC _Options>',
            tooltip = 'mainmenu_options',
            action = function() ButtonOptions() end,
            color = menuFontColorAlt,
        },
        {
            name = '<LOC _Exit>',
            tooltip = 'mainmenu_exit',
            action = function() ButtonExit() end,
        }
    }

    local largestMenu = menuTop
    local mainMenuSize = table.getn(largestMenu)

    -- BACKGROUND
    local parent = UIUtil.CreateScreenGroup(GetFrame(0), "Main Menu ScreenGroup")

    local backMovie = false
    if Prefs.GetOption("mainmenu_bgmovie") then
        backMovie = CreateBackMovie(parent)
    end

    local scanlines = Bitmap(parent, UIUtil.UIFile('/menus/main02-1600-1200/scan-lines_bmp.dds'))
    if backMovie then
        scanlines.Depth:Set(function() return backMovie.Depth() + 1 end)
    end
    LayoutHelpers.AtLeftTopIn(scanlines, parent)
    scanlines:SetTiled(true)
    LayoutHelpers.FillParent(scanlines, parent)
    scanlines:SetAlpha(.3)

    local darker = Bitmap(scanlines)
    LayoutHelpers.FillParent(darker, parent)
    darker:SetSolidColor('200000')
    darker:SetAlpha(.5)
    darker:Hide()

    -- BORDER, LOGO and TEXT
    local border = Group(scanlines, "border")
    LayoutHelpers.FillParent(border, scanlines)

    -- SupCom logo resizes to current resolution
    local logo = Bitmap(border, UIUtil.UIFile('/menus/main02-1600-1200/sc-logo_bmp.dds'))
    LayoutHelpers.AtHorizontalCenterIn(logo, border)
    LayoutHelpers.AtTopIn(logo, border, 0)
    logo.Depth:Set(60)

    function SetLogoSize(noReturn)
        local nativeParentWidth = 1600
        local nativeParentHeight = 1200
        local nativeAspect = logo.BitmapWidth() / logo.BitmapHeight()

        local newWidth = parent.Width() * (logo.BitmapWidth() / nativeParentWidth)
        local newHeight = newWidth / nativeAspect

        if newHeight > parent.Height() * (logo.BitmapHeight() / nativeParentHeight) then
            newHeight = parent.Height() * (logo.BitmapHeight() / nativeParentHeight)
            newWidth = newHeight * nativeAspect
        end
        logo.Height:Set(math.floor(newHeight))
        if noReturn then
            logo.Width:Set(math.floor(newWidth))
        else
            return math.floor(newWidth)    -- return for Width:Set function
        end
    end

    SetLogoSize(true)

    logo.Width:Set(function()
        return SetLogoSize()
    end)

    -- border elements
    local border_ur = Bitmap(border, UIUtil.UIFile('/menus/main03/back_brd_ur.dds'))
    LayoutHelpers.AtRightTopIn(border_ur, border)

    local border_ul = Bitmap(border, UIUtil.UIFile('/menus/main03/back_brd_ul.dds'))
    LayoutHelpers.AtLeftTopIn(border_ul, border)

    local border_umr = Bitmap(border, UIUtil.UIFile('/menus/main03/back_brd_horz_umr.dds'))
    border_umr.Top:Set(0)
    border_umr.Left:Set(logo.Right)
    border_umr.Right:Set(border_ur.Left)

    local border_uml = Bitmap(border, UIUtil.UIFile('/menus/main03/back_brd_horz_uml.dds'))
    border_uml.Top:Set(0)
    border_uml.Left:Set(border_ul.Right)
    border_uml.Right:Set(border_umr.Left)
    border_uml.Depth:Set(function() return logo.Depth() -1 end)

    border_uml.Depth:Set(30)
    border_umr.Depth:Set(30)

    local border_lm = Bitmap(border, UIUtil.UIFile('/menus/main03/back_brd_horz_lm.dds'))
    LayoutHelpers.AtHorizontalCenterIn(border_lm, border)
    LayoutHelpers.AtBottomIn(border_lm, border)

    local border_lr = Bitmap(border, UIUtil.UIFile('/menus/main03/back_brd_lr.dds'))
    LayoutHelpers.AtBottomIn(border_lr, border)
    LayoutHelpers.AtRightIn(border_lr, border)

    local border_ll = Bitmap(border, UIUtil.UIFile('/menus/main03/back_brd_ll.dds'))
    LayoutHelpers.AtBottomIn(border_ll, border)
    LayoutHelpers.AtLeftIn(border_ll, border)

    local border_lmr = Bitmap(border, UIUtil.UIFile('/menus/main03/back_brd_horz_lmr.dds'))
    LayoutHelpers.AtBottomIn(border_lmr, border)
    border_lmr.Left:Set(border_lm.Right)
    border_lmr.Right:Set(border_lr.Left)

    local border_lml = Bitmap(border, UIUtil.UIFile('/menus/main03/back_brd_horz_lml.dds'))
    LayoutHelpers.AtBottomIn(border_lml, border)
    border_lml.Left:Set(border_ll.Right)
    border_lml.Right:Set(border_lm.Left)

    -- legal text
    local legalText = UIUtil.CreateText(border_ll, LOC(import('/lua/ui/help/eula.lua').LEGAL_TEXT), 9, UIUtil.bodyFont)
    legalText:SetColor('ffa5a5a5')
    LayoutHelpers.AtBottomIn(legalText, border, 10)
    legalText.Left:Set(border_lr.Right)
    legalText:SetDropShadow(true)
    legalText:SetNeedsFrameUpdate(true)
    legalText.OnFrame = function(self, delta)
        local newLeft = math.floor(self.Left() - (delta * 50))
        if newLeft + self.Width() < border_ll.Left() then
            newLeft = border_lr.Right()
        end
        self.Left:Set(newLeft)
    end

    -- version text
    local versionText = UIUtil.CreateText(border, "Version : " .. GetVersion(), 12)
    versionText:SetColor('677983')
    LayoutHelpers.AtRightTopIn(versionText, border, 30, 10)
    versionText.Depth:Set(60)

    -- music
    local ambientSoundHandle = PlaySound(Sound({Cue = "AMB_Menu_Loop", Bank = "AmbientTest_SC",}))

    local musicHandle = false
    function StartMusic()
        if not musicHandle then
            musicHandle = PlaySound(Sound({Cue = "Main_Menu", Bank = "Music_SC",}))
        end
    end

    function StopMusic()
        if musicHandle then
            StopSound(musicHandle)
            musicHandle = false
        end
    end

    parent.OnDestroy = function()
        if ambientSoundHandle then
            StopSound(ambientSoundHandle)
            ambientSoundHandle = false
        end
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

    mainMenuGroup.Animate = function(control, animIn, callback)
        control:SetNeedsFrameUpdate(true)
        if animIn then
            control.mod = 1
        else
            control.mod = -1
        end
        control.OnFrame = function(self, delta)
            local newTop = self.Top() + (delta * 1000 * self.mod)
            if animIn then
                if newTop > logo.Bottom() then
                    newTop = logo.Bottom()
                    self:SetNeedsFrameUpdate(false)
                    if callback then
                        callback()
                    end
                end
            else
                if 0 - (self.Top() - newTop) < logo.Bottom() then
                    newTop = logo.Bottom() - 0
                    self:SetNeedsFrameUpdate(false)
                    if callback then
                        callback()
                        animation_active = false
                    end
                end
            end
            self.Top:Set(newTop)
        end
    end

    -- TODO: don't destroy the whole menu. just destroy the buttons, then you only have to set the top once.
    function MenuBuild(menuTable, center)
        if menuTable == 'home' then
            menuTable = menuTop
        end

        local profileDlg = nil

        function GetNameOfCurrentProfile()
            local currentProfile = GetPreference("profile.current")
            local activeProfile = nil
            if currentProfile then
                local profiles = GetPreference("profile.profiles")
                if profiles[currentProfile] != nil then
                    activeProfile = profiles[currentProfile]
                else
                    SetPreference("profile.current", 0) -- if current profile is damaged, reset to 0
                end
            end
            if activeProfile then
                return activeProfile
            end
            return nil
        end


        -- title
        mainMenu.titleBack = Bitmap(mainMenuGroup, UIUtil.UIFile('/menus/main03/panel-top_bmp.dds'))
        LayoutHelpers.AtHorizontalCenterIn(mainMenu.titleBack, mainMenuGroup)
        LayoutHelpers.AtTopIn(mainMenu.titleBack, mainMenuGroup, 10)

        mainMenu.titleTxt = UIUtil.CreateText(mainMenu.titleBack, GetPreference("profile.current"), 26)
        LayoutHelpers.AtCenterIn(mainMenu.titleTxt, mainMenu.titleBack, 3)
        mainMenu.titleTxt:SetText(LOC(menuTable.title))
        mainMenu.titleTxt:SetNewColor(menuFontColorTitle)

        -- bottom cap
        mainMenu.btmCap = Bitmap(mainMenuGroup, UIUtil.UIFile('/menus/main03/panel-bottom_bmp.dds'))

        -- profile button

        mainMenu.profile = UIUtil.CreateButtonStd(mainMenu.titleBack, '/menus/main02/profile-edit', GetNameOfCurrentProfile().Name, 12)
        LayoutHelpers.CenteredBelow(mainMenu.profile, mainMenu.titleBack, -20)
        mainMenu.profile.OnRolloverEvent = function(self, event)
            if event == 'exit' then
                self.label:SetColor(UIUtil.fontColor)
            else
                self.label:SetColor('ff000000')
            end
        end

        mainMenu.profile.HandleEvent = function(self, event)
            if animation_active then
                return true
            end
            if event.Type == 'MouseEnter' then
                Tooltip.CreateMouseoverDisplay(self, "profile", 5, true)
            elseif event.Type == 'MouseExit' then
                Tooltip.DestroyMouseoverDisplay()
            end
            Button.HandleEvent(self, event)
        end

        mainMenu.profile.SetItemAlpha = function(self, alpha)
            self:SetAlpha(alpha)
            self.label:SetAlpha(alpha)
            mainMenu.titleBack:SetAlpha(alpha)
            mainMenu.titleTxt:SetAlpha(alpha)
            mainMenu.btmCap:SetAlpha(alpha)
        end

        mainMenu.profile:SetItemAlpha(0)

        mainMenu.profile.FadeIn = function(control)
            if control.clickfunc then
                control:Enable()
            end
            control:DisableHitTest(true)
            control:SetNeedsFrameUpdate(true)
            control:SetTexture(UIUtil.UIFile('/menus/main02/profile-edit_btn_up.dds'))
            control.label:SetColor(UIUtil.fontColor)
            control.time = 0
            control.wait = 0
            control.first = true
            control.OnFrame = function(self, delta)
                self.time = self.time + delta
                if self.first then
                    self.first = false
                end
                local change = (delta * 200)
                if self.time > .5 and self.time > self.wait then
                    local num = math.random(20, 70)/100
                    local waitRand = math.random(0, 3)/10
                    self.wait = self.time + waitRand
                    self:SetItemAlpha(num)
                end
                if self.time > animation_delay then
                    self:SetItemAlpha(1)
                    self:EnableHitTest()
                    self:SetNeedsFrameUpdate(false)
                end
            end
        end
        mainMenu.profile.FadeOut = function(control)
            control:DisableHitTest(true)
            control:SetNeedsFrameUpdate(true)
            Tooltip.DestroyMouseoverDisplay()
            control:SetTexture(UIUtil.UIFile('/menus/main02/profile-edit_btn_up.dds'))
            control.label:SetColor(UIUtil.fontColor)
            control.time = 0
            control.wait = 0
            control.OnFrame = function(self, delta)
                self.time = self.time + delta
                if self.time < 1 and self.time > self.wait then
                    local num = math.random(20, 80)/100
                    local waitRand = math.random(0, 3)/10
                    self.wait = self.time + waitRand
                    self:SetItemAlpha(num)
                end
                if self.time >= 1 then
                    if self:GetAlpha() > 0 then
                        self:SetItemAlpha(0)
                    end
                end
                if self.time > animation_delay then
                    self:SetNeedsFrameUpdate(false)
                end
            end
        end

        --SetNameToCurrentProfile()
        mainMenu.profile.OnClick = function(self)
            MenuHide(function()
                if not profileDlg then
                    profileDlg = import('/lua/ui/dialogs/profile.lua').CreateDialog(function()
                        --SetNameToCurrentProfile()
                        profileDlg = nil
                        MenuShow()
                    end)
                end
            end)
        end

        -- menu buttons
        local buttonHeight = nil
        for k, v in menuTable do
            if k != 'title' then
                mainMenu[k] = {}
                if v.name then
                    mainMenu[k].btn = UIUtil.CreateButtonStd(mainMenuGroup, '/menus/main03/large', v.name, 22, 0, 0, "UI_Menu_MouseDown", "UI_Opt_Affirm_Over")
                elseif v.image then
                    mainMenu[k].btn = Button(mainMenuGroup,
                        UIUtil.UIFile('/scx_menu/large-no-bracket-btn/large_btn_up.dds'),
                        UIUtil.UIFile('/scx_menu/large-no-bracket-btn/large_btn_down.dds'),
                        UIUtil.UIFile('/scx_menu/large-no-bracket-btn/large_btn_over.dds'),
                        UIUtil.UIFile('/scx_menu/large-no-bracket-btn/large_btn_dis.dds'),
                        "UI_Menu_MouseDown", "UI_Menu_Rollover")
                    mainMenu[k].btn.img = Bitmap(mainMenu[k].btn, UIUtil.UIFile(v.image))
                    LayoutHelpers.AtCenterIn(mainMenu[k].btn.img, mainMenu[k].btn)
                    mainMenu[k].btn.img:DisableHitTest()
                end
                mainMenu[k].btn:UseAlphaHitTest(false)
                buttonHeight = mainMenu[k].btn.Height()
                if v.color and mainMenu[k].btn.label then
                    mainMenu[k].btn.label:SetColor(v.color)
                else
                    mainMenu[k].btn.label:SetColor(menuFontColor)
                end
                if k == 1 then
                    LayoutHelpers.CenteredBelow(mainMenu[k].btn, mainMenu.profile)
                else
                    local lastBtn = k - 1
                    LayoutHelpers.CenteredBelow(mainMenu[k].btn, mainMenu[lastBtn].btn, 0)
                end
                if v.action then
                    mainMenu[k].btn.glow = Bitmap(mainMenu[k].btn, UIUtil.UIFile('/scx_menu/large-btn/large_btn_glow.dds'))
                    LayoutHelpers.AtCenterIn(mainMenu[k].btn.glow, mainMenu[k].btn)
                    mainMenu[k].btn.glow:SetAlpha(0)
                    mainMenu[k].btn.glow:DisableHitTest()
                    mainMenu[k].btn.rofunc = function(self, event)
                        if animation_active then
                            return true
                        end
                        if event == 'enter' then
                            EffectHelpers.FadeIn(self.glow, .25, 0, 1)
                            if self.label then
                                self.label:SetColor('black')
                            end
                        elseif event == 'down' then
                            if self.label then
                                self.label:SetColor('black')
                            end
                        else
                            EffectHelpers.FadeOut(self.glow, .4, 1, 0)
                            if self.label then
                                self.label:SetColor(menuFontColor)
                            end
                        end
                    end
                    mainMenu[k].btn.clickfunc = v.action
                    mainMenu[k].btn._enable = true
                    if v.tooltip then Tooltip.AddButtonTooltip(mainMenu[k].btn, v.tooltip, TOOLTIP_DELAY) end
                else
                    mainMenu[k].btn:Disable()
                end

                mainMenu[k].btn:Disable()
                mainMenu[k].btn:SetAlpha(0, true)
                mainMenu[k].btn.SetItemAlpha = function(control, alpha)
                    control:SetAlpha(alpha)
                    if control.label then
                        control.label:SetAlpha(alpha)
                    elseif control.img then
                        control.img:SetAlpha(alpha)
                    end
                end
                mainMenu[k].btn.FadeIn = function(control)
                    if control.clickfunc then
                        control:Enable()
                        if control.label then
                            control.label:SetColor(menuFontColor)
                        end
                    end
                    control:DisableHitTest(true)
                    control.OnRolloverEvent = function() end
                    control.OnClick = function() end
                    control:SetNeedsFrameUpdate(true)
                    if control:IsDisabled() then
                        control:SetTexture(UIUtil.UIFile('/scx_menu/large-no-bracket-btn/large_btn_dis.dds'))
                    end
                    control.time = 0
                    control.wait = 0
                    control.first = true
                    control.OnFrame = function(self, delta)
                        self.time = self.time + delta
                        if self.first then
                            self.first = false
                        end
                        if self.time > .5 and self.time > self.wait then
                            self.OnClick = self.clickfunc
                            local num = math.random(20, 70)/100
                            local waitRand = math.random(0, 3)/10
                            self.wait = self.time + waitRand
                            self:SetItemAlpha(num)
                        end
                        if self.time > animation_delay then
                            self:SetItemAlpha(1)
                            if not control:IsDisabled() then
                                self:EnableHitTest()
                                self.OnRolloverEvent = self.rofunc
                            else
                                self:SetTexture(UIUtil.UIFile('/scx_menu/large-no-bracket-btn/large_btn_dis.dds'))
                            end
                            self:SetNeedsFrameUpdate(false)
                        end
                    end
                end
                mainMenu[k].btn.FadeOut = function(control)
                    control:DisableHitTest(true)
                    control:SetNeedsFrameUpdate(true)
                    control.OnRolloverEvent = function() end
                    control.OnClick = function() end
                    control.time = 0
                    control.wait = 0
                    control.OnFrame = function(self, delta)
                        self.time = self.time + delta
                        if self.time < 1 and self.time > self.wait then
                            local num = math.random(20, 80)/100
                            local waitRand = math.random(0, 3)/10
                            self.wait = self.time + waitRand
                            self:SetItemAlpha(num)
                        end
                        if self.time >= 1 then
                            if self:GetAlpha() > 0 then
                                self:SetItemAlpha(0)
                            end
                        end
                        if self.time > animation_delay then
                            self:SetItemAlpha(0)
                            self:EnableHitTest()
                            self:SetNeedsFrameUpdate(false)
                        end
                    end
                end

            end
        end

        local numButtons = table.getn(mainMenu)
        local lastBtn = mainMenu[numButtons].btn

        -- bottom cap layout
        LayoutHelpers.CenteredBelow(mainMenu.btmCap, lastBtn, -18)

        if initial then
            ForkThread(function()
                WaitSeconds(.2)
                PlaySound(Sound({Bank = 'Interface', Cue = 'X_Main_Menu_On_Start'}))
                MenuAnimation(true)
                PlaySound(Sound({Bank = 'Interface', Cue = 'X_Main_Menu_On'}))
            end)
            initial = false
        else
            MenuAnimation(true)
        end

        -- set ESC key functionality depending on menu layer
        if menuTable == 'home' or menuTable == menuTop then
            SetEscapeHandle(ButtonExit)
        else
            SetEscapeHandle(ButtonBack)
        end

        -- set final dimensions/placement of mainMenuGroup
        mainMenuGroup.Height:Set(function() return (mainMenuSize * buttonHeight) + mainMenu.titleBack.Height() + mainMenu.btmCap.Height() end)
        mainMenuGroup.Width:Set(mainMenu.titleBack.Width)
        LayoutHelpers.AtHorizontalCenterIn(mainMenuGroup, border)

        mainMenuGroup.Top:Set(function()
            return math.floor(logo.Bottom() + (border_lm.Top() + 14 - logo.Bottom() - mainMenuGroup.Height() ) / 2 ) -- includes offset for alpha on border_lm
        end)

    end


    -- Animate the menu

    function MenuAnimation(fadeIn, callback, skipSlide)
        animation_active = true
        local function ButtonFade(menuSlide)
            ForkThread(function()
                for i, v in mainMenu do
                    if not v.btn then
                        continue
                    end
                    if fadeIn then
                        v.btn:FadeIn()
                    else
                        v.btn:FadeOut()
                    end
                end
                if fadeIn then
                    mainMenu.profile:FadeIn()
                else
                    mainMenu.profile:FadeOut()
                end
                WaitSeconds(animation_delay)
                if menuSlide then
                    mainMenuGroup:Animate(fadeIn, callback)
                elseif callback then
                    callback()
                end
                if not menuSlide then
                    animation_active = false
                end
            end)
        end
        if fadeIn then
            mainMenuGroup:Animate(fadeIn, ButtonFade)
        else
            ButtonFade(not skipSlide)
        end
    end

    function SetEscapeHandle(action)
        import('/lua/ui/uimain.lua').SetEscapeHandler(function() action() end)
    end

    function MenuHide(callback)
        MenuAnimation(false, function()
            EffectHelpers.FadeIn(darker, 1, 0, .4)
            if backMovie then
                backMovie:Stop()
            end
            logo:Hide()
            legalText:Hide()
            mainMenuGroup:Hide()
            mainMenuGroup.Depth:Set(50)        -- setting depth below topLayerGroup (100) to avoid the button glow persisting when overlays are up
            PauseSound("World", true)
            if callback then callback() end
        end)
    end

    function MenuShow()
        mainMenuGroup.Depth:Set(101)    -- and setting it back again
        mainMenuGroup:Show()
        logo:Show()
        legalText:Show()
        PauseSound("World", false)
        EffectHelpers.FadeOut(darker, 1, .4, 0)
        if Prefs.GetOption("mainmenu_bgmovie") and not backMovie then
            backMovie = CreateBackMovie(parent)
            scanlines.Depth:Set(function() return backMovie.Depth() + 1 end)
        elseif Prefs.GetOption("mainmenu_bgmovie") == false and backMovie then
            backMovie:Destroy()
            backMovie = false
        elseif backMovie then
            backMovie:Play()
        end
        MenuAnimation(true)
    end

    function MenuDestroy(callback, skipSlide)
        MenuAnimation(false, function()
            for k, v in mainMenu do
                if v.btn then
                    v.btn:Destroy()
                else
                    v:Destroy()
                end
            end
            mainMenu = {}
            if callback then callback() end
        end, skipSlide)
    end

    -- BUTTON FUNCTIONS
    function TutorialPrompt(callback)
        if Prefs.GetFromCurrentProfile('MenuTutorialPrompt') then
            callback()
        else
            Prefs.SetToCurrentProfile('MenuTutorialPrompt', true)
            qmsg = "<LOC EXITDLG_0006>This appears to be your first time playing Supreme Commander. Would you like to play the tutorial before you begin?"
            ButtonTutorial(qmsg, callback)
        end
    end

    function ButtonTutorial(qmsg, callback)
        if qmsg == nil then
            --FIXME--qmsg = "<LOC EXITDLG_0006>Are you sure you wish to launch the tutorial map?"
            qmsg = "Are you sure you wish to launch the tutorial map?"
        end
        UIUtil.QuickDialog(GetFrame(0), qmsg,
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

    function ButtonCampaign()
        TutorialPrompt(function()
            MenuAnimation(false, function()
                StopMusic()
                parent:Destroy()
                import('/lua/ui/campaign/selectcampaign.lua').CreateUI()
            end)
        end)
    end

    function ButtonMP()
        MenuDestroy(function()
            MenuBuild(menuMultiplayer)
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
            import('/lua/ui/dialogs/replay.lua').CreateDialog(topLevelGroup, true, function() MenuShow() SetEscapeHandle(ButtonBack) end)
        end)
    end

    function ButtonMod()
        MenuHide(function()
            local function OnOk(selectedmods)
                Mods.SetSelectedMods(selectedmods)
                MenuShow()
                SetEscapeHandle(ButtonBack)
            end
            import('/lua/ui/dialogs/modmanager.lua').CreateDialog(topLevelGroup, false, OnOk)
        end)
    end

    function ButtonOptions()
        MenuHide(function()
            import('/lua/ui/dialogs/options.lua').CreateDialog(topLevelGroup, function() MenuShow() SetEscapeHandle(ButtonExit) end)
        end)
    end

    function ButtonExtras()
        MenuDestroy(function()
            MenuBuild(menuExtras)
        end, true)
    end

    function ButtonCredits()
        parent:Destroy()
        import('/lua/ui/menus/credits.lua').CreateDialog(function() import('/lua/ui/menus/main.lua').CreateUI() end)
    end

    function ButtonEULA()
        MenuHide(function()
            import('/lua/ui/menus/eula.lua').CreateEULA(topLevelGroup, function() MenuShow() SetEscapeHandle(ButtonBack) end)
        end)
    end

    function ButtonBack()
        MenuDestroy(function()
            ESC_handle = nil
            MenuBuild('home', true)
        end, true)
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
