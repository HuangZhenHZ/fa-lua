---------------------------------------
-- File: lua/modules/ui/lobby/lobby.lua
-- Author: Xinnony
-- Summary: Mods Manager GUI
---------------------------------------

local Mods = import('/lua/mods.lua')
local UIUtil = import('/lua/ui/uiutil.lua')
local Tooltip = import('/lua/ui/game/tooltip.lua')
local Group = import('/lua/maui/group.lua').Group
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local MultiLineText = import('/lua/maui/multilinetext.lua').MultiLineText
local Popup = import('/lua/ui/controls/popups/popup.lua').Popup
local RadioButton = import('/lua/ui/controls/radiobutton.lua').RadioButton
local Prefs = import('/lua/user/prefs.lua')
local GUI_OPEN = false

function UpdateClientModStatus(mod_selec)
    if GUI_OPEN then
        IsHost = false
        modstatus = mod_selec
        Refresh_Mod_List(false, true, true, IsHost, modstatus)
    end
end

function HostModStatus(availableMods)
    Mods.ClearCache() -- Force reload of mod info to pick up changes on disk
    local my_all = Mods.AllSelectableMods()
    local my_sel = Mods.GetSelectedMods()
    local r = {}

    local function everyoneHas(uid)
        for peer, modset in availableMods do
            if not modset[uid] then
                return false
            end
        end
        return true
    end

    for uid,mod in my_all do
        if mod.ui_only or everyoneHas(uid) then
            if mod.ui_only then
                r[uid] = true
            else
                r[uid] = true
            end
        else
            r[uid] = false
        end
    end
    return r
end

local modsDialog

-- Show only UI mods?
local uiOnly = true
function NEW_MODS_GUI(parent, IsHost, modstatus, availableMods)
    if IsHost then modstatus = false end

    local dialogContent = Group(parent)
    dialogContent.Width:Set(537)
    dialogContent.Height:Set(548)

    modsDialog = Popup(parent, dialogContent)

    -- Title
    local text0 = UIUtil.CreateText(dialogContent, 'MOD管理器', 17, 'Arial')
    text0:SetColor('B9BFB9')
    text0:SetDropShadow(true)
    LayoutHelpers.AtHorizontalCenterIn(text0, dialogContent, 0)
    LayoutHelpers.AtTopIn(text0, dialogContent, 10)
        
    -- SubTitle
    local text1 = UIUtil.CreateText(dialogContent, '', 12, 'Arial')
    text1:SetColor('B9BFB9')
    text1:SetDropShadow(true)
    LayoutHelpers.AtHorizontalCenterIn(text1, dialogContent, 0)
    LayoutHelpers.AtTopIn(text1, dialogContent, 26)
        
    -- Save button
    local SaveButton = UIUtil.CreateButtonWithDropshadow(dialogContent, '/BUTTON/medium/', "完成", -1)
    LayoutHelpers.AtLeftIn(SaveButton, dialogContent, -2)
    LayoutHelpers.AtBottomIn(SaveButton, dialogContent, 10)

    -- Checkbox UI mod filter
    local filterButtons = {
        { label = LOC("本地MOD") },
        { label = LOC("游戏MOD") }
    }

    local filterradio = RadioButton(dialogContent, '/RADIOBOX/', filterButtons, 2, true)
    LayoutHelpers.AtLeftIn(filterradio, dialogContent, 160)
    LayoutHelpers.AtBottomIn(filterradio, dialogContent, -20)

    -- Checkbox hide unselectable mods
    local hideUnselChkBox = UIUtil.CreateCheckbox(dialogContent, '/CHECKBOX/', '隐藏失败MOD', true)
    LayoutHelpers.AtLeftIn(hideUnselChkBox, dialogContent, 370)
    LayoutHelpers.AtBottomIn(hideUnselChkBox, dialogContent, 18)
    Tooltip.AddCheckboxTooltip(hideUnselChkBox, {text='<LOC modui_06>Hide Unselectable', body='<LOC modui_07>Hide mods which are unselectable due to compatibility issues, or because a player in the lobby does not have them'})
    hideUnselChkBox:SetCheck(true, true)

    filterradio.OnChoose = function(self, index)
        save_mod()
        swiffer()
        uiOnly = index == 1
        Refresh_Mod_List(not uiOnly, uiOnly, hideUnselChkBox:IsChecked(), IsHost, modstatus)
    end
    
    if not IsHost then
        hideUnselChkBox:Disable()
        hideUnselChkBox:SetCheck(false, true)
    end
    hideUnselChkBox.OnCheck = function(self, checked)
        if IsHost then
            save_mod()
            swiffer()
            Refresh_Mod_List(not uiOnly, uiOnly, checked, IsHost, modstatus)
        end
    end

    -- Mod list
    local scrollGroup = Group(dialogContent)
    scrollGroup.Width:Set(519)
    scrollGroup.Height:Set(450)
    LayoutHelpers.AtLeftTopIn(scrollGroup, dialogContent, 0, 47)
    UIUtil.CreateLobbyVertScrollbar(scrollGroup, 1, 48, -44)
    scrollGroup.controlList = {}
    scrollGroup.top = 1
    numElementsPerPage = 6
    
    scrollGroup.GetScrollValues = function(self, axis)
        return 1, table.getn(self.controlList), self.top, math.min(self.top + numElementsPerPage - 1, table.getn(scrollGroup.controlList))
    end
    
    scrollGroup.ScrollLines = function(self, axis, delta)
        self:ScrollSetTop(axis, self.top + math.floor(delta))
    end
    
    scrollGroup.ScrollPages = function(self, axis, delta)
        self:ScrollSetTop(axis, self.top + math.floor(delta) * numElementsPerPage)
    end
    
    scrollGroup.ScrollSetTop = function(self, axis, top)
        top = math.floor(top)
        if top == self.top then return end
        self.top = math.max(math.min(table.getn(self.controlList) - numElementsPerPage + 1 , top), 1)
        self:CalcVisible()
    end
    
    scrollGroup.CalcVisible = function(self)
        local top = self.top
        local bottom = self.top + numElementsPerPage
        for index, control in ipairs(self.controlList) do
            if index < top or index >= bottom then
                control:Hide()
            else
                control:Show()
                control.Left:Set(self.Left)
                local lIndex = index
                local lControl = control
                control.Top:Set(function() return self.Top() + ((lIndex - top) * lControl.Height()) end)
            end
        end
    end
    
    SaveButton.OnClick = function(self)
        save_mod()
        GUI_OPEN = false
        import('/lua/ui/lobby/lobby.lua').OnModsChanged(selectedMods)
        modsDialog:Close()
        return selectedMods
    end
    
    function count_mod_UI_activated()
        count_ui = 0
        for k, v in scrollGroup.controlList do
            if v.activated and v.modInfo.ui_only then
                count_ui = count_ui + 1
            end
        end
        return count_ui
    end
    
    function count_mod_SIM_activated()
        count_sim = 0
        for k, v in scrollGroup.controlList do
            if v.activated and not v.modInfo.ui_only then
                count_sim = count_sim + 1
            end
        end
        return count_sim
    end
    
    function swiffer()
        for k, v in scrollGroup.controlList do
            v:Destroy()
        end
    end
    
    function save_mod()
        selectedMods = {}
        for index, control in scrollGroup.controlList do
            if control.activated then
                selectedMods[control.modInfo.uid] = true
            end
        end
        import('/lua/mods.lua').SetSelectedMods(selectedMods)
    end

    function Refresh_Mod_List(showGameMods, showUIMods, hideUnselected, IsHost, modstatus)
        index = 0
        exclusiveMod = false
        local current_list = {}
        scrollGroup.controlList = {}
        local allmods = Mods.AllSelectableMods()
        local selmods = Mods.GetSelectedMods()
        local unselmods = Mods.GetUnSelectedMods()
        local GetUI_Activatedmods = Mods.GetUiMods() -- Active UI
        local GetUI_Unactivatedmods = Mods.GetUiMods(unselmods) -- Active + Inactive UI
        local GetSIM_Activatedmods = Mods.GetGameMods() -- Active SIM
        local GetSIM_Unactivatedmods = Mods.GetGameMods(unselmods) -- Active + Inactive SIM

        if not IsHost then
            for k, v in allmods do
                if modstatus[v.uid] then
                    table.insert(current_list, v)
                end
            end
            for k, v in GetUI_Activatedmods do
                table.insert(current_list, v)
            end
        else
            for k, v in GetSIM_Activatedmods do
                table.insert(current_list, v)
            end
            for k, v in GetUI_Activatedmods do
                table.insert(current_list, v)
            end
            if showGameMods and IsHost then
                for k, v in GetSIM_Unactivatedmods do
                    table.insert(current_list, v)
                end
            end
        end
        if showUIMods then
            for k, v in GetUI_Unactivatedmods do
                table.insert(current_list, v)
            end
        end
        
        -- Remove mods which are unselectable because of conflicts or because not all the players have them
        if hideUnselected then
            for i, v in current_list do
                if not v.selectable or availableMods[v.uid] == v.uid then
                    table.remove(current_list, i)
                    i = i - 1
                end
            end
        end
        
        table.sort(current_list, function(a,b)
            if selmods[a.uid] and selmods[b.uid] then
                return a.name < b.name
            elseif selmods[a.uid] or selmods[b.uid] then
                return selmods[a.uid] or false
            else
                return a.name < b.name
            end
        end)

        for k, v in current_list do
            table.insert(scrollGroup.controlList, CreateListElementtt(scrollGroup, v, k))
            if IsHost and selmods[v.uid] then
                scrollGroup.controlList[k].activated = true
                scrollGroup.controlList[k].bg:SetTexture(UIUtil.SkinnableFile('/MODS/enabled.dds'))
                if v.ui_only then
                    scrollGroup.controlList[k].type:SetText('本地MOD 激活')
                else
                    scrollGroup.controlList[k].type:SetText('游戏MOD 激活')
                end
            elseif not IsHost and modstatus[v.uid] and not v.ui_only then
                scrollGroup.controlList[k].activated = true
                scrollGroup.controlList[k].type:SetText('游戏MOD 激活')
                scrollGroup.controlList[k].bg:SetTexture(UIUtil.SkinnableFile('/MODS/enabled.dds'))
            elseif not IsHost and selmods[v.uid] and v.ui_only then
                scrollGroup.controlList[k].activated = true
                scrollGroup.controlList[k].type:SetText('本地MOD 激活')
                scrollGroup.controlList[k].bg:SetTexture(UIUtil.SkinnableFile('/MODS/enabled.dds'))
            end
            if scrollGroup.controlList[k].modInfo.exclusive and selmods[v.uid] then
                exclusiveMod = true
                scrollGroup.controlList[k].activated = true
                scrollGroup.controlList[k].type:SetText('专用MOD激活')
                scrollGroup.controlList[k].bg:SetTexture(UIUtil.SkinnableFile('/MODS/enabled.dds'))
            end
        end
        
        text1:SetText(count_mod_SIM_activated()..' 个游戏Mod和 '..count_mod_UI_activated()..' 个本地 Mod激活')
        
        local function UNActiveMod(the_mod)
            the_mod.activated = false
            the_mod.type:SetColor('B9BFB9')
            the_mod.bg:SetSolidColor('00000000')
            the_mod.bg0:SetSolidColor('00000000')
            if the_mod.ui then
                the_mod.type:SetText('本地MOD')
            else
                the_mod.type:SetText('游戏MOD')
            end
        end
        
        local function ActiveExclusifMod(the_exclusif_mod)
            local function FUNC_RUN()
                exclusiveMod = true
                for index, control in scrollGroup.controlList do
                    if control.activated and control != the_exclusif_mod then
                        UNActiveMod(control)
                    end
                end
                the_exclusif_mod.activated = true
                the_exclusif_mod.type:SetText('Exclusive Mod Activated')
                the_exclusif_mod.bg:SetTexture(UIUtil.SkinnableFile('/MODS/enabled.dds'))
                PlaySound(Sound({Cue = "UI_Mod_Select", Bank = "Interface",}))
                text1:SetText(count_mod_SIM_activated()..' 个游戏Mod和 '..count_mod_UI_activated()..' 个本地Mod激活')
            end
            UIUtil.QuickDialog(GUI_ModsManager, 
                "<LOC uimod_0010>The mod you have requested is marked as exclusive. If you select this mod, all other mods will be disabled. Do you wish to enable this mod?",
                "<LOC _Yes>", FUNC_RUN,
                "<LOC _No>")
        end
        
        local function ActiveMod(the_mod)
            local depends = Mods.GetDependencies(the_mod.modInfo.uid)
            local skipExit = false
            local allMods = Mods.AllMods()
            
            if depends.missing then
                local boxText = LOC("<LOC uimod_0012>The requested mod can not be enabled as it requires the following mods that you don't currently have installed:\n\n")
                for uid, v in depends.missing do
                    local name
                    if the_mod.modInfo.requiresNames and the_mod.modInfo.requiresNames[uid] then
                        name = the_mod.modInfo.requiresNames[uid]
                    else
                        name = uid
                    end
                    boxText = boxText .. name .. "\n"
                end
                UIUtil.QuickDialog(GUI_ModsManager, boxText, "<LOC _Ok>")
                skipExit = true
            
            elseif depends.requires then
                local Tname = {}
                for uid, v in depends.requires do
                    local name
                    if the_mod.modInfo.requiresNames and the_mod.modInfo.requiresNames[uid] then
                        table.insert(Tname, uid)
                        name = the_mod.modInfo.requiresNames[uid]
                    else
                        table.insert(Tname, uid)
                        name = uid
                    end
                end
                for i, c in Tname do -- Check if the Mod is listed in the GUI
                    exist = false
                    for index, control in scrollGroup.controlList do
                        if control.modInfo.uid == c then
                            exist = true
                            control.activated = true
                            control.bg:SetTexture(UIUtil.SkinnableFile('/MODS/enabled.dds'))
                            if control.ui then
                                control.type:SetText('本地MOD 激活')
                            else
                                control.type:SetText('游戏MOD 激活')
                            end
                        end
                    end
                    if not exist then -- IF The mod is not listed in the GUI, create the mod in the list
                        table.insert(scrollGroup.controlList, the_mod.pos+1, CreateListElementtt(scrollGroup, allMods[c], the_mod.pos))
                        control = scrollGroup.controlList[the_mod.pos+1]
                        control.activated = true
                        control.bg:SetTexture(UIUtil.SkinnableFile('/MODS/enabled.dds'))
                        if control.ui then
                            control.type:SetText('本地MOD 激活')
                        else
                            control.type:SetText('游戏MOD 激活')
                        end
                        EVENT_Click()
                        scrollGroup:CalcVisible()
                    end
                end
            
            elseif depends.conflicts then
                local boxText = LOC("You can't enable this because of conflicts with the following mod :\n")
                local conflict = false
                local Tname = {}
                for uid, v in depends.conflicts do
                    local name
                    if the_mod.modInfo.requiresNames and the_mod.modInfo.requiresNames[uid] then
                        table.insert(Tname, uid)
                        name = the_mod.modInfo.requiresNames[uid]
                    else
                        table.insert(Tname, uid)
                        name = uid
                    end
                end
                for i, c in Tname do -- Get the name of the conflict mod
                    if allMods[c].name then
                        boxText = boxText .. allMods[c].name .. '\n'
                    else
                        boxText = boxText .. '- '.. c .. '\n'
                    end
                end
                for index, control in scrollGroup.controlList do -- Check if the conflict mod is active or not
                    for i, c in Tname do
                        if control.modInfo.uid == c and control.activated then
                            conflict = true
                        end
                    end
                end
                --
                if conflict then
                    UIUtil.QuickDialog(GUI_ModsManager, boxText, "<LOC _Ok>")
                    skipExit = true
                end
            end
            
            if not skipExit then
                the_mod.activated = true
                the_mod.bg:SetTexture(UIUtil.SkinnableFile('/MODS/enabled.dds'))
                if the_mod.ui then
                    the_mod.type:SetText('本地MOD 激活')
                else
                    the_mod.type:SetText('游戏MOD 激活')
                end
            end
        end
        
        local function ActiveModAndRemoveExclusifMod(the_mod)
            local function FUNC_RUN()
                LOG('>> ActiveModAndRemoveExclusifMod')
                exclusiveMod = false
                for index, control in scrollGroup.controlList do
                    if control.activated and control.modInfo.exclusive then
                        UNActiveMod(control)
                    end
                end
                ActiveMod(the_mod)
                PlaySound(Sound({Cue = "UI_Mod_Select", Bank = "Interface",}))
                text1:SetText(count_mod_SIM_activated()..' 个游戏Mod和 '..count_mod_UI_activated()..' 个本地Mod激活')
            end
            UIUtil.QuickDialog(GUI_ModsManager,
                "<LOC uimod_0011>You currently have an exclusive mod selected, do you wish to deselect it?",
                "<LOC _Yes>", FUNC_RUN,
                "<LOC _No>")
        end

        function EVENT_Click()
            for i, v in scrollGroup.controlList do
                v.HandleEvent = function(self, event)
                    if event.Type == 'ButtonPress' or event.Type == 'ButtonDClick' then
                        if not IsHost and not self.ui then
                            -- You can't enable Game Mod if you not the Host
                        else
                            -- TODO: A disabled graphic for this situation.
                            if not self.modInfo.selectable then
                                self.type:SetColor('B9BFB9')
                                self.type:SetText('This mod cannot be selected')
                            elseif not availableMods[self.modInfo.uid] and not self.ui then
                                -- If other player not have the mod
                                self.type:SetColor('B9BFB9')
                                self.type:SetText('One or more players do not have this mod')
                            else
                                if self.activated then
                                    UNActiveMod(self)
                                else
                                    if self.modInfo.exclusive then
                                        ActiveExclusifMod(self)
                                    else
                                        if exclusiveMod then 
                                            ActiveModAndRemoveExclusifMod(self)
                                        else
                                            ActiveMod(self)
                                        end
                                    end
                                end
                                PlaySound(Sound({Cue = "UI_Mod_Select", Bank = "Interface",}))
                                text1:SetText(count_mod_SIM_activated()..' 个游戏Mod和 '..count_mod_UI_activated()..' 个本地Mod激活')
                            end
                        end
                    elseif event.Type == 'MouseEnter' then
                        self.bg0:SetTexture(UIUtil.SkinnableFile('/MODS/enabled.dds'))
                    elseif event.Type == 'MouseExit' then
                        self.bg0:SetSolidColor('00000000')
                    end
                end
            end
        end
        EVENT_Click()
        
        scrollGroup.top = 1
        scrollGroup:CalcVisible()
    end
    Refresh_Mod_List(true, false, true, IsHost, modstatus)

    scrollGroup.HandleEvent = function(self, event)
        if event.Type == 'WheelRotation' then
            local lines = 1
            if event.WheelRotation > 0 then
                lines = -1
            end
            self:ScrollLines(nil, lines)
        end
    end

    GUI_OPEN = true
end

function CreateListElementtt(parent, modInfo, Pos)
    local group = Group(parent)
        numElementsPerPage = 6
        group.Height:Set(function() return parent.Height() / numElementsPerPage  end)
        group.Width:Set(parent.Width)
        LayoutHelpers.AtLeftTopIn(group, parent, 0, group.Height()*(Pos-1))
    
    group.pos = Pos
    group.modInfo = modInfo
    group.activated = false
    
    group.bg = Bitmap(group)
        group.bg.Height:Set(group.Height())
        group.bg.Width:Set(group.Width())
        LayoutHelpers.AtLeftTopIn(group.bg, group, 0, 0)
    
    group.bg0 = Bitmap(group)
        group.bg0.Height:Set(group.Height())
        group.bg0.Width:Set(group.Width())
        LayoutHelpers.AtLeftTopIn(group.bg0, group, 0, 0)
    
    group.icon = Bitmap(group, modInfo.icon)
        group.icon.Height:Set(56)
        group.icon.Width:Set(56)
        LayoutHelpers.AtLeftTopIn(group.icon, group, 10, 10)
    
    group.name = UIUtil.CreateText(group, modInfo.name, 14, UIUtil.bodyFont)
        group.name:SetColor('B9BFB9')
        LayoutHelpers.AtLeftTopIn(group.name, group, 80, 10)
        group.name:SetDropShadow(true)
    
        group.desc = MultiLineText(group, UIUtil.bodyFont, 12, 'B9BFB9')
            LayoutHelpers.AtLeftTopIn(group.desc, group, 80, 30)
            group.desc.Height:Set(40)
            group.desc.Width:Set(group.Width()-86)
            group.desc:SetText(modInfo.description)
    
    group.type = UIUtil.CreateText(group, '', 10, 'Arial Narrow Bold')
        group.type:SetColor('B9BFB9')
        if modInfo.ui_only then
            group.type:SetText('本地MOD')
            group.type:SetFont('Arial Black', 11)
            group.ui = true
        else
            group.type:SetText('游戏MOD')
            group.type:SetFont('Arial Black', 11)
            group.ui = false
        end
        LayoutHelpers.AtRightTopIn(group.type, group, 12, 4)
    
    return group
end
