--*****************************************************************************
--* File: lua/modules/ui/lobby/lobbyOptions.lua
--* Summary: Lobby options
--*
--* Copyright � 2006 Gas Powered Games, Inc.  All rights reserved.
--*****************************************************************************

-- options that show up in the team options panel
teamOptions =
{
    {
        default = 1,
        label = "<LOC lobui_0088>Spawn",
        help = "<LOC lobui_0089>Determine what positions players spawn on the map",
        key = 'TeamSpawn',
        values = {
		    {
                text = "<LOC lobui_0092>Fixed",
                help = "<LOC lobui_0093>Spawn everyone in fixed locations (determined by slot)",
                key = 'fixed',
            },
			{
                text = "<LOC lobui_0079>Score Random",
                help = "<LOC lobui_0080>Teams will be optimallyScore Random, start locations",
                key = 'balanced',
            },
			{
                text = "<LOC lobui_0778>Score Random(Revealed)",
                help = "<LOC lobui_0779>Teams will be optimally balanced, labeled random start locations",
                key = 'balanced_reveal',
            },
            {
                text = "<LOC lobui_0090>Random - Unbalanced",
                help = "<LOC lobui_0091>Spawn everyone in random locations",
                key = 'random',
            },
            {
                text = "<LOC lobui_0776>Random (Revealed)",
                help = "<LOC lobui_0777>Spawn everyone in random locations which are labeled",
                key = 'random_reveal',
            },
			{
                text = "<LOC Smurf_01>balances smurf",
                help = "<LOC Smurf_02>Team will open the smurf mode, disable chat, and adjust by the score points assigned by the host",
                key = 'balances_smurf',
            },
			{
                text = "<LOC Smurf_03>nomal smurf",
                help = "<LOC Smurf_04>Team will open the vest mode, disable chat, and randomly assign birth points",
                key = 'nomal_smurf',
            },
        },
    },
    {
        default = 2,
        label = "<LOC lobui_0096>Team",
        help = "<LOC lobui_0097>Determines if players may switch teams while in game",
        key = 'TeamLock',
        values = {
            {
                text = "<LOC lobui_0098>Locked",
                help = "<LOC lobui_0099>Teams are locked once play begins",
                key = 'locked',
            },
            {
                text = "<LOC lobui_0100>Unlocked",
                help = "<LOC lobui_0101>Players may switch teams during play",
                key = 'unlocked',
            },
        },
    },
    {
        default = 1,
        label = "<LOC lobui_0532>Auto Teams",
        help = "<LOC lobui_0533>Auto ally the players before the game starts",
        key = 'AutoTeams',
        values = {
            {
                text = "<LOC lobui_0244>None",
                help = "<LOC lobui_0534>No automatic teams",
                key = 'none',
            },
            {
                text = "<LOC lobui_0530>Top vs Bottom",
                help = "<LOC lobui_0535>The game will be Top vs Bottom",
                key = 'tvsb',
            },
            {
                text = "<LOC lobui_0529>Left vs Right",
                help = "<LOC lobui_0536>The game will be Left vs Right",
                key = 'lvsr',
            },
            {
                text = "<LOC lobui_0571>Even Slots vs Odd Slots",
                help = "<LOC lobui_0572>The game will be Even Slots vs Odd Slots",
                key = 'pvsi',
            },
            {
                text = "<LOC lobui_0585>Manual Select",
                help = "<LOC lobui_0586>You can select the teams clicking on the icons in the map preview, it only works with random spawn",
                key = 'manual',
            },
        },
    },
}

globalOpts = {
    {
        default = 8,
        label = "<LOC lobui_0102>Unit Cap",
        help = "<LOC lobui_0103>Set the maximum number of units that can be in play",
        key = 'UnitCap',
        values = {
          {
                text = "<LOC lobui_0719>125",
                help = "<LOC lobui_0720>125 units per player may be in play",
                key = '125',
            },
            {
                text = "<LOC lobui_0170>250",
                help = "<LOC lobui_0171>250 units per player may be in play",
                key = '250',
            },
            {
                text = "<LOC lobui_0721>375",
                help = "<LOC lobui_0722>375 units per player may be in play",
                key = '375',
            },
            {
                text = "<LOC lobui_0172>500",
                help = "<LOC lobui_0173>500 units per player may be in play",
                key = '500',
            },
            {
                text = "<LOC lobui_0723>625",
                help = "<LOC lobui_0724>625 units per player may be in play",
                key = '625',
            },
            {
                text = "<LOC lobui_0174>750",
                help = "<LOC lobui_0175>750 units per player may be in play",
                key = '750',
            },
            {
                text = "<LOC lobui_0725>875",
                help = "<LOC lobui_0726>875 units per player may be in play",
                key = '875',
            },
            {
                text = "<LOC lobui_0235>1000",
                help = "<LOC lobui_0236>1000 units per player may be in play",
                key = '1000',
            },
			{
                text = "1250",
                help = "1250 units per player may be in play",
                key = '1250',
            },
			{
                text = "1500",
                help = "1500 units per player may be in play",
                key = '1500',
            },
			{
                text = "2000",
                help = "2000 units per player may be in play",
                key = '2000',
            },
			{
                text = "10000",
                help = "<LOC NEWOPTIONS_48>10000 units per player may be in play",
                key = '10000',
            },
        },
        
    },
    {
        default = 2,
        label = "<LOC NEWOPTIONS_41>Share Unit Cap at Death",
        help = "<LOC NEWOPTIONS_49>Enable this to share unitcap when a player dies",
        key = 'ShareUnitCap',
        values = {
          {
                text = "<LOC NEWOPTIONS_45>None",
                help = "<LOC NEWOPTIONS_42>Do not share unitcap",
                key = 'none',
            },
            {
                text = "<LOC NEWOPTIONS_46>Allies",
                help = "<LOC NEWOPTIONS_43>Share unitcap with allies only",
                key = 'allies',
            },
            {
                text = "<LOC NEWOPTIONS_47>All",
                help = "<LOC NEWOPTIONS_44>Share unitcap with all players",
                key = 'all',
            },
        },
    },
    {
        default = 1,
        label = "<LOC lobui_0112>Fog of War",
        help = "<LOC lobui_0113>Set up how fog of war will be visualized",
        key = 'FogOfWar',
        values = {
            {
                text = "<LOC lobui_0114>Explored",
                help = "<LOC lobui_0115>Terrain revealed, but units still need recon data",
                key = 'explored',
            },
            {
                text = "<LOC lobui_0118>None",
                help = "<LOC lobui_0119>All terrain and units visible",
                key = 'none',
            },
        },
    },
    {
        default = 1,
        label = "<LOC lobui_0120>Victory Condition",
        help = "<LOC lobui_0121>Determines how a victory can be achieved",
        key = 'Victory',
        values = {
            {
                text = "<LOC lobui_0122>Assassination",
                help = "<LOC lobui_0123>Game ends when commander is destroyed",
                key = 'demoralization',
            },
            {
                text = "<LOC lobui_0124>Supremacy",
                help = "<LOC lobui_0125>Game ends when all structures, commanders and engineers are destroyed",
                key = 'domination',
            },
            {
                text = "<LOC lobui_0126>Annihilation",
                help = "<LOC lobui_0127>Game ends when all units are destroyed",
                key = 'eradication',
            },
            {
                text = "<LOC lobui_0128>Sandbox",
                help = "<LOC lobui_0129>Game never ends",
                key = 'sandbox',
            },
        },
    },
    {
        default = 2,
        label = "<LOC lobui_0242>Timeouts",
        help = "<LOC lobui_0243>Sets the number of timeouts each player can request",
        key = 'Timeouts',
        mponly = true,
        values = {
            {
                text = "<LOC lobui_0244>None",
                help = "<LOC lobui_0245>No timeouts are allowed",
                key = '0',
            },
            {
                text = "<LOC lobui_0246>Three",
                help = "<LOC lobui_0247>Each player has three timeouts",
                key = '3',
            },
            {
                text = "<LOC lobui_0248>Infinite",
                help = "<LOC lobui_0249>There is no limit on timeouts",
                key = '-1',
            },
        },
    },
    {
        default = 1,
        label = "<LOC lobui_0258>Game Speed",
        help = "<LOC lobui_0259>Set the game speed",
        key = 'GameSpeed',
        values = {
            {
                text = "<LOC lobui_0260>Normal",
                help = "<LOC lobui_0261>Fixed at the normal game speed (+0)",
                key = 'normal',
            },
            {
                text = "<LOC lobui_0262>Fast",
                help = "<LOC lobui_0263>Fixed at a fast game speed (+4)",
                key = 'fast',
            },
            {
                text = "<LOC lobui_0264>Adjustable",
                help = "<LOC lobui_0265>Adjustable in-game",
                key = 'adjustable',
            },
        },
    },
    {
        default = 1,
        label = "<LOC lobui_0592>Allow Observers",
        help = "<LOC lobui_0593>Are observers permitted after the game has started?",
        key = 'AllowObservers',
        values = {
            {
                text = "<LOC _Yes>Yes",
                help = "<LOC lobui_0594>Observers are allowed",
                key = true,
            },
            {
                text = "<LOC _No>No",
                help = "<LOC lobui_0595>Observers are not allowed",
                key = false,
            },
        },
    },
    {
        default = 1,
        label = "<LOC lobui_0208>Cheating",
        help = "<LOC lobui_0209>Enable cheat codes",
        key = 'CheatsEnabled',
        values = {
            {
                text = "<LOC _Off>Off",
                help = "<LOC lobui_0210>Cheats disabled",
                key = 'false',
            },
            {
                text = "<LOC _On>On",
                help = "<LOC lobui_0211>Cheats enabled",
                key = 'true',
            },
        },
    },
    {
        default = 1,
        label = "<LOC lobui_0291>Civilians",
        help = "<LOC lobui_0292>Set how civilian units are used",
        key = 'CivilianAlliance',
        values = {
            {
                text = "<LOC lobui_0293>Enemy",
                help = "<LOC lobui_0294>Civilians are enemies of players",
                key = 'enemy',
            },
            {
                text = "<LOC lobui_0295>Neutral",
                help = "<LOC lobui_0296>Civilians are neutral to players",
                key = 'neutral',
            },
            {
                text = "<LOC lobui_0297>None",
                help = "<LOC lobui_0298>No Civilians on the battlefield",
                key = 'removed',
            },
        },
    },
    {
        default = 1,
		label = "显示平民单位",
        help = "开局时显示平民单位的位置",
        key = 'RevealCivilians',
        values = {
            {
                text = "<LOC _Yes>Yes",
                help = "<LOC lobui_0302>Civilian structures are revealed",
                key = 'Yes',
            },
            {
                text = "<LOC _No>No",
                help = "<LOC lobui_0303>Civilian structures are hidden",
                key = 'No',
            },
        },
    },
    {
        default = 1,										   
        label = "<LOC lobui_0310>Prebuilt Units",
        help = "<LOC lobui_0311>Set whether the game starts with prebuilt units or not",
        key = 'PrebuiltUnits',
        values = {
            {
                text = "<LOC lobui_0312>Off",
                help = "<LOC lobui_0313>No prebuilt units",
                key = 'Off',
            },
            {
                text = "<LOC lobui_0314>On",
                help = "<LOC lobui_0315>Prebuilt units set",
                key = 'On',
            },
        },
    },
    {
        default = 1,
        label = "<LOC lobui_0316>No Rush Option",
        help = "<LOC lobui_0317>Enforce No Rush rules for a certain period of time",
        key = 'NoRushOption',
        values = {
            {
                text = "<LOC lobui_0318>Off",
                help = "<LOC lobui_0319>Rules not enforced",
                key = 'Off',
            },
            {
                text = "<LOC lobui_0320>5",
                help = "<LOC lobui_0321>Rules enforced for 5 mins",
                key = '5',
            },
            {
                text = "<LOC lobui_0322>10",
                help = "<LOC lobui_0323>Rules enforced for 10 mins",
                key = '10',
            },
            {
                text = "<LOC lobui_0324>20",
                help = "<LOC lobui_0325>Rules enforced for 20 mins",
                key = '20',
            },
        },
    },
    {
        default = 1,
        label = "<LOC lobui_0545>Random Map",
        help = "<LOC lobui_0546>If enabled, the game will selected a random map just before the game launch",
        key = 'RandomMap',
        values = {
            {
                text = "<LOC lobui_0312>Off",
                help = "<LOC lobui_0556>No random map",
                key = 'Off',
            },
         {
                text = "<LOC lobui_0553>Official Maps Only",
                help = "<LOC lobui_0555>Random map set",
                key = 'Official',
            },
            {
                text = "<LOC lobui_0554>All Maps",
                help = "<LOC lobui_0555>Random map set",
                key = 'All',
            },
        },
    },
   {
        default = 1,
        label = "<LOC lobui_0727>Score",
        help = "<LOC lobui_0728>Set score on or off during the game",
        key = 'Score',
        values = {
            {
                text = "<LOC _On>On",
                help = "<LOC lobui_0729>Score is enabled",
                key = 'yes',
            },
            {
                text = "<LOC _Off>Off",
                help = "<LOC lobui_0730>Score is disabled",
                key = 'no',
            },
        },
    },
   {
        default = 2,
        label = "<LOC lobui_0740>Share Conditions",
        help = "<LOC lobui_0741>Kill all the units you shared to your allies and send back the units your allies shared with you when you die",
        key = 'Share',
        values = {
            {
                text = "<LOC lobui_0742>Full Share",
                help = "<LOC lobui_0743>You can give units to your allies and they will not be destroyed when you die",
                key = 'no',
            },
            {
                text = "<LOC lobui_0744>Share Until Death",
                help = "<LOC lobui_0745>All the units you gave to your allies will be destroyed when you die",
                key = 'yes',
            },
        },
    },
	--终结者改造价选项
	{
        default = 1,
        label = "游戏终结者造价",
        help = "修改游戏终结者的造价",
        key = 'Terminator',
        values = {
			{
                text = "100%",
                help = "造价为原数据的100%",
                key = '1.0',
            },
			{
                text = "125%",
                help = "造价为原数据的125%",
                key = '1.25',
            },
			{
                text = "150%",
                help = "造价为原数据的150%",
                key = '1.5',
            },
			{
                text = "200%",
                help = "造价为原数据的200%",
                key = '2.0',
            },
        },
    },
	{
        default = 2,
        label = "<LOC aireplace_0001>AI Replacement",
        help = "<LOC aireplace_0002>Toggle AI Replacement if a player disconnects.",
        key = 'AIReplacement',
        values = {
            {
                text = "<LOC _On>On",
                help = "<LOC aireplace_0003>If a player disconnects and the ACU is still active, an AI will be created to take control of units that belonged to the player who disconnected.",
                key = 'On',
            },
            {
                text = "<LOC _Off>Off",
                help = "<LOC aireplace_0004>A disconnected player will cause the destruction of their units based on share conditions.",
                key = 'Off',
            },
        },
    },
	{
        default = 1,
        label = "<LOC massv_0001>massv",
        help = "<LOC massv_0002>massv",
        key = 'Massv',
        values = {
            {
                text = "<LOC _Off>Off",
                help = "<LOC massv_0003>off",
                key = 'Off',
            },
            {
                text = "1",
                help = "<LOC massv_0004>on",
                key = '1',
            },
			{
                text = "2",
                help = "<LOC massv_0004>on",
                key = '2',
            },
			{
                text = "3",
                help = "<LOC massv_0004>on",
                key = '3',
            },
			{
                text = "4",
                help = "<LOC massv_0004>on",
                key = '4',
            },
			{
                text = "5",
                help = "<LOC massv_0004>on",
                key = '5',
            },
			{
                text = "6",
                help = "<LOC massv_0004>on",
                key = '6',
            },
			{
                text = "7",
                help = "<LOC massv_0004>on",
                key = '7',
            },
			{
                text = "8",
                help = "<LOC massv_0004>on",
                key = '8',
            },
			{
                text = "9",
                help = "<LOC massv_0004>on",
                key = '9',
            },
			{
                text = "10",
                help = "<LOC massv_0004>on",
                key = '10',
            },
			{
                text = "11",
                help = "<LOC massv_0004>on",
                key = '11',
            },
			{
                text = "12",
                help = "<LOC massv_0004>on",
                key = '12',
            },
						{
                text = "13",
                help = "<LOC massv_0004>on",
                key = '13',
            },
						{
                text = "14",
                help = "<LOC massv_0004>on",
                key = '14',
            },
						{
                text = "15",
                help = "<LOC massv_0004>on",
                key = '15',
            },
						{
                text = "16",
                help = "<LOC massv_0004>on",
                key = '16',
            },
        },
    },
	{
        default = 1,
        label = "<LOC LandT4Firstc_01>Land T4First",
        help = "<LOC LandT4Firstc_02>Land T4First",
        key = 'LandT4First',
        values = {
		    {
                text = "<LOC _Off>Off",
                help = "<LOC LandT4Firstc_03>Off",
                key = 'Off',
            },
            {
                text = "<LOC _On>On",
                help = "<LOC LandT4Firstc_04>On",
                key = 'On',
            },
        },
    },
	{
        default = 1,
        label = "<LOC AntinukeFirstc_01>Antinuke First",
        help = "<LOC AntinukeFirstc_02>Antinuke First",
        key = 'AntinukeFirst',
        values = {
		    {
                text = "<LOC _Off>Off",
                help = "<LOC AntinukeFirstc_03>Off",
                key = 'Off',
            },
            {
                text = "<LOC _On>On",
                help = "<LOC AntinukeFirstc_04>On",
                key = 'On',
            },
        },
    },
	{
        default = 1,
        label = "<LOC Ghostmod_01>Ghostmod",
        help = "<LOC Ghostmod_02>Ghostmod",
        key = 'Ghostmod',
        values = {
		    {
                text = "1",
                help = "<LOC Ghostmod_03>",
                key = '1',
            },
			{
                text = "2",
                help = "<LOC Ghostmod_03>",
                key = '2',
            },
			{
                text = "3",
                help = "<LOC Ghostmod_03>",
                key = '3',
            },
			{
                text = "4",
                help = "<LOC Ghostmod_03>",
                key = '4',
            },
			{
                text = "5",
                help = "<LOC Ghostmod_03>",
                key = '5',
            },
			{
                text = "6",
                help = "<LOC Ghostmod_03>",
                key = '6',
            },
			{
                text = "7",
                help = "<LOC Ghostmod_03>",
                key = '7',
            },
			{
                text = "8",
                help = "<LOC Ghostmod_03>",
                key = '8',
            },
			{
                text = "9",
                help = "<LOC Ghostmod_03>",
                key = '9',
            },
			{
                text = "10",
                help = "<LOC Ghostmod_03>",
                key = '10',
            },
			{
                text = "11",
                help = "<LOC Ghostmod_03>",
                key = '11',
            },
			{
                text = "12",
                help = "<LOC Ghostmod_03>",
                key = '12',
            },
			{
                text = "13",
                help = "<LOC Ghostmod_03>",
                key = '13',
            },
			{
                text = "14",
                help = "<LOC Ghostmod_03>",
                key = '14',
            },
			{
                text = "15",
                help = "<LOC Ghostmod_03>",
                key = '15',
            },
			{
                text = "16",
                help = "<LOC Ghostmod_03>",
                key = '16',
            },
			{
                text = "17",
                help = "<LOC Ghostmod_03>",
                key = '17',
            },
			{
                text = "18",
                help = "<LOC Ghostmod_03>",
                key = '18',
            },
			{
                text = "19",
                help = "<LOC Ghostmod_03>",
                key = '19',
            },
			{
                text = "20",
                help = "<LOC Ghostmod_03>",
                key = '20',
            },
			{
                text = "21",
                help = "<LOC Ghostmod_03>",
                key = '21',
            },
			{
                text = "22",
                help = "<LOC Ghostmod_03>",
                key = '22',
            },
			{
                text = "23",
                help = "<LOC Ghostmod_03>",
                key = '23',
            },
			{
                text = "24",
                help = "<LOC Ghostmod_03>",
                key = '24',
            },
			{
                text = "25",
                help = "<LOC Ghostmod_03>",
                key = '25',
            },
			{
                text = "26",
                help = "<LOC Ghostmod_03>",
                key = '26',
            },
			{
                text = "27",
                help = "<LOC Ghostmod_03>",
                key = '27',
            },
			{
                text = "28",
                help = "<LOC Ghostmod_03>",
                key = '28',
            },
			{
                text = "29",
                help = "<LOC Ghostmod_03>",
                key = '29',
            },
			{
                text = "30",
                help = "<LOC Ghostmod_03>",
                key = '30',
            },
			{
                text = "31",
                help = "<LOC Ghostmod_03>",
                key = '31',
            },
			{
                text = "32",
                help = "<LOC Ghostmod_03>",
                key = '32',
            },
			{
                text = "33",
                help = "<LOC Ghostmod_03>",
                key = '33',
            },
			{
                text = "34",
                help = "<LOC Ghostmod_03>",
                key = '34',
            },
			{
                text = "35",
                help = "<LOC Ghostmod_03>",
                key = '35',
            },
			{
                text = "36",
                help = "<LOC Ghostmod_03>",
                key = '36',
            },
			{
                text = "37",
                help = "<LOC Ghostmod_03>",
                key = '37',
            },
			{
                text = "38",
                help = "<LOC Ghostmod_03>",
                key = '38',
            },
			{
                text = "39",
                help = "<LOC Ghostmod_03>",
                key = '39',
            },
			{
                text = "40",
                help = "<LOC Ghostmod_03>",
                key = '40',
            },
			{
                text = "45",
                help = "<LOC Ghostmod_03>",
                key = '45',
            },
			{
                text = "50",
                help = "<LOC Ghostmod_03>",
                key = '50',
            },
			{
                text = "<LOC Ghostmod_04>999",
                help = "<LOC Ghostmod_04>",
                key = '999',
            },
        },
    },
	{
        default = 1,
        label = "<LOC customize_mod1>customizemod",
        help = "<LOC customize_mod2>customizemod",
        key = 'customizemod',
        values = {
		    {
                text = "1",
                help = "<LOC customize_mod2>",
                key = '1',
            },
			{
                text = "2",
                help = "<LOC customize_mod2>",
                key = '2',
            },
			{
                text = "3",
                help = "<LOC customize_mod2>",
                key = '3',
            },
			{
                text = "4",
                help = "<LOC customize_mod2>",
                key = '4',
            },
			{
                text = "5",
                help = "<LOC customize_mod2>",
                key = '5',
            },
			{
                text = "6",
                help = "<LOC customize_mod2>",
                key = '6',
            },
			{
                text = "7",
                help = "<LOC customize_mod2>",
                key = '7',
            },
			{
                text = "8",
                help = "<LOC customize_mod2>",
                key = '8',
            },
			{
                text = "9",
                help = "<LOC customize_mod2>",
                key = '9',
            },
			{
                text = "10",
                help = "<LOC customize_mod2>",
                key = '10',
            },
        },
    },
}

AIOpts = {
	{   default = 1,
        label = "<LOC AdpAI_text_01>自适应AIX",
        help = "<LOC AIHPMult_03>设置自适应AIX难度.",
        key = 'AdpAI',
        values = {
            {
                text = "<LOC _NO>Off",
                help = "<LOC AdpAI_help_01>关闭自适应AIX",
                key = 'off',
            },
            {
                text = "简单",
                help = "<LOC AdpAI_help_02>简单难度自适应AIX，每10分钟获得加成。",
                key = '10',
            },
            {
                text = "标准",
                help = "<LOC AdpAI_help_03>标准难度自适应AIX，每8分钟获得加成。",
                key = '8',
            },
            {
                text = "困难",
                help = "<LOC AdpAI_help_04>困难难度自适应AIX，每5分钟获得加成。",
                key = '5',
            },
            {
                text = "疯狂",
                help = "<LOC AdpAI_help_05>疯狂难度自适应AIX，每3分钟获得加成。",
                key = '3',
            },
            {
                text = "地狱",
                help = "<LOC AdpAI_help_06>地狱难度自适应AIX，每1分钟获得加成。",
                key = '1',
            },
        },
   },
   {
        default = 4,
        label = "<LOC NEWOPTIONS_22>AIx Cheat Multiplier",
        help = "<LOC NEWOPTIONS_23>Set the cheat multiplier for the cheating AIs.",
        key = 'CheatMult',
        values = {
            {
                text = "1.0",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 1.0",
                key = '1.0',
            },
            {
                text = "1.1",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 1.1",
                key = '1.1',
            },
            {
                text = "1.2",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 1.2",
                key = '1.2',
            },
            {
                text = "1.3",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 1.3",
                key = '1.3',
            },
            {
                text = "1.4",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 1.4",
                key = '1.4',
            },
            {
                text = "1.5",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 1.5",
                key = '1.5',
            },
            {
                text = "1.6",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 1.6",
                key = '1.6',
            },
            {
                text = "1.7",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 1.7",
                key = '1.7',
            },
            {
                text = "1.8",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 1.8",
                key = '1.8',
            },
            {
                text = "1.9",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 1.9",
                key = '1.9',
            },
            {
                text = "2.0",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 2.0",
                key = '2.0',
            },
            {
                text = "2.1",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 2.1",
                key = '2.1',
            },
            {
                text = "2.2",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 2.2",
                key = '2.2',
            },
            {
                text = "2.3",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 2.3",
                key = '2.3',
            },
            {
                text = "2.4",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 2.4",
                key = '2.4',
            },
            {
                text = "2.5",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 2.5",
                key = '2.5',
            },
            {
                text = "2.6",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 2.6",
                key = '2.6',
            },
            {
                text = "2.7",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 2.7",
                key = '2.7',
            },
            {
                text = "2.8",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 2.8",
                key = '2.8',
            },
            {
                text = "2.9",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 2.9",
                key = '2.9',
            },
            {
                text = "3.0",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 3.0",
                key = '3.0',
            },
            {
                text = "3.1",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 3.1",
                key = '3.1',
            },
            {
                text = "3.2",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 3.2",
                key = '3.2',
            },
            {
                text = "3.3",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 3.3",
                key = '3.3',
            },
            {
                text = "3.4",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 3.4",
                key = '3.4',
            },
            {
                text = "3.5",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 3.5",
                key = '3.5',
            },
            {
                text = "3.6",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 3.6",
                key = '3.6',
            },
            {
                text = "3.7",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 3.7",
                key = '3.7',
            },
            {
                text = "3.8",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 3.8",
                key = '3.8',
            },
            {
                text = "3.9",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 3.9",
                key = '3.9',
            },
            {
                text = "4.0",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 4.0",
                key = '4.0',
            },
            {
                text = "4.1",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 4.1",
                key = '4.1',
            },
            {
                text = "4.2",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 4.2",
                key = '4.2',
            },
            {
                text = "4.3",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 4.3",
                key = '4.3',
            },
            {
                text = "4.4",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 4.4",
                key = '4.4',
            },
            {
                text = "4.5",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 4.5",
                key = '4.5',
            },
            {
                text = "4.6",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 4.6",
                key = '4.6',
            },
            {
                text = "4.7",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 4.7",
                key = '4.7',
            },
            {
                text = "4.8",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 4.8",
                key = '4.8',
            },
            {
                text = "4.9",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 4.9",
                key = '4.9',
            },
            {
                text = "5.0",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 5.0",
                key = '5.0',
            },
            {
                text = "5.1",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 5.1",
                key = '5.1',
            },
            {
                text = "5.2",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 5.2",
                key = '5.2',
            },
            {
                text = "5.3",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 5.3",
                key = '5.3',
            },
            {
                text = "5.4",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 5.4",
                key = '5.4',
            },
            {
                text = "5.5",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 5.5",
                key = '5.5',
            },
            {
                text = "5.6",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 5.6",
                key = '5.6',
            },
            {
                text = "5.7",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 5.7",
                key = '5.7',
            },
            {
                text = "5.8",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 5.8",
                key = '5.8',
            },
            {
                text = "5.9",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 5.9",
                key = '5.9',
            },
            {
                text = "6.0",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 6.0",
                key = '6.0',
            },
			{
                text = "20.0",
                help = "<LOC NEWOPTIONS_23>Cheat multiplier of 20.0",
                key = '20.0',
            },
			{
                text = "50.0",
                help = "<LOC NEWOPTIONS_48>Cheat multiplier of 50.0",
                key = '50.0',
            },
			{
                text = "1000.0",
                help = "<LOC NEWOPTIONS_48>Cheat multiplier of 1000.0",
                key = '1000.0',
            },
        },
   },
   {   default = 4,
        label = "<LOC NEWOPTIONS_24>AIx Build Multiplier",
        help = "<LOC NEWOPTIONS_25>Set the build rate multiplier for the cheating AIs.",
        key = 'BuildMult',
        values = {
            {
                text = "1.0",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 1.0",
                key = '1.0',
            },
            {
                text = "1.1",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 1.1",
                key = '1.1',
            },
            {
                text = "1.2",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 1.2",
                key = '1.2',
            },
            {
                text = "1.3",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 1.3",
                key = '1.3',
            },
            {
                text = "1.4",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 1.4",
                key = '1.4',
            },
            {
                text = "1.5",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 1.5",
                key = '1.5',
            },
            {
                text = "1.6",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 1.6",
                key = '1.6',
            },
            {
                text = "1.7",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 1.7",
                key = '1.7',
            },
            {
                text = "1.8",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 1.8",
                key = '1.8',
            },
            {
                text = "1.9",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 1.9",
                key = '1.9',
            },
            {
                text = "2.0",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 2.0",
                key = '2.0',
            },
            {
                text = "2.1",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 2.1",
                key = '2.1',
            },
            {
                text = "2.2",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 2.2",
                key = '2.2',
            },
            {
                text = "2.3",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 2.3",
                key = '2.3',
            },
            {
                text = "2.4",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 2.4",
                key = '2.4',
            },
            {
                text = "2.5",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 2.5",
                key = '2.5',
            },
            {
                text = "2.6",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 2.6",
                key = '2.6',
            },
            {
                text = "2.7",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 2.7",
                key = '2.7',
            },
            {
                text = "2.8",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 2.8",
                key = '2.8',
            },
            {
                text = "2.9",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 2.9",
                key = '2.9',
            },
            {
                text = "3.0",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 3.0",
                key = '3.0',
            },
            {
                text = "3.1",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 3.1",
                key = '3.1',
            },
            {
                text = "3.2",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 3.2",
                key = '3.2',
            },
            {
                text = "3.3",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 3.3",
                key = '3.3',
            },
            {
                text = "3.4",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 3.4",
                key = '3.4',
            },
            {
                text = "3.5",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 3.5",
                key = '3.5',
            },
            {
                text = "3.6",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 3.6",
                key = '3.6',
            },
            {
                text = "3.7",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 3.7",
                key = '3.7',
            },
            {
                text = "3.8",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 3.8",
                key = '3.8',
            },
            {
                text = "3.9",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 3.9",
                key = '3.9',
            },
            {
                text = "4.0",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 4.0",
                key = '4.0',
            },
            {
                text = "4.1",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 4.1",
                key = '4.1',
            },
            {
                text = "4.2",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 4.2",
                key = '4.2',
            },
            {
                text = "4.3",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 4.3",
                key = '4.3',
            },
            {
                text = "4.4",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 4.4",
                key = '4.4',
            },
            {
                text = "4.5",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 4.5",
                key = '4.5',
            },
            {
                text = "4.6",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 4.6",
                key = '4.6',
            },
            {
                text = "4.7",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 4.7",
                key = '4.7',
            },
            {
                text = "4.8",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 4.8",
                key = '4.8',
            },
            {
                text = "4.9",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 4.9",
                key = '4.9',
            },
            {
                text = "5.0",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 5.0",
                key = '5.0',
            },
            {
                text = "5.1",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 5.1",
                key = '5.1',
            },
            {
                text = "5.2",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 5.2",
                key = '5.2',
            },
            {
                text = "5.3",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 5.3",
                key = '5.3',
            },
            {
                text = "5.4",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 5.4",
                key = '5.4',
            },
            {
                text = "5.5",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 5.5",
                key = '5.5',
            },
            {
                text = "5.6",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 5.6",
                key = '5.6',
            },
            {
                text = "5.7",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 5.7",
                key = '5.7',
            },
            {
                text = "5.8",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 5.8",
                key = '5.8',
            },
            {
                text = "5.9",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 5.9",
                key = '5.9',
            },
            {
                text = "6.0",
                help = "<LOC NEWOPTIONS_25>Cheat multiplier of 6.0",
                key = '6.0',
            },
			{
                text = "20.0",
                help = "<LOC NEWOPTIONS_48>Cheat multiplier of 20.0",
                key = '20.0',
            },
			{
                text = "50.0",
                help = "<LOC NEWOPTIONS_48>Cheat multiplier of 50.0",
                key = '50.0',
            },
			{
                text = "1000.0",
                help = "<LOC NEWOPTIONS_48>Cheat multiplier of 1000.0",
                key = '1000.0',
            },
        },
   },
   {   default = 1,
        label = "<LOC AIHPMult_01>AIx HP Mult",
        help = "<LOC AIHPMult_03>Set the AIx HP for the cheating AIs.",
        key = 'AIMultHP',
        values = {
            {
                text = "<LOC _NO>Off",
                help = "<LOC AIHPMult_02>AI HP mult off",
                key = 'off',
            },
            {
                text = "1.5",
                help = "<LOC AIHPMult_03>Set AI HP mult",
                key = '1.5',
            },
            {
                text = "2",
                help = "<LOC AIHPMult_03>Set AI HP mult",
                key = '2',
            },
            {
                text = "3",
                help = "<LOC AIHPMult_03>Set AI HP mult",
                key = '3',
            },
            {
                text = "4",
                help = "<LOC AIHPMult_03>Set AI HP mult",
                key = '4',
            },
            {
                text = "5",
                help = "<LOC AIHPMult_03>Set AI HP mult",
                key = '5',
            },
            {
                text = "10",
                help = "<LOC AIHPMult_03>Set AI HP mult",
                key = '10',
            },
            {
                text = "100",
                help = "<LOC AIHPMult_03>Set AI HP mult",
                key = '100',
            },
        },
   },
   {   default = 10,
        label = "<LOC NEWOPTIONS_26>AI TML Randomization",
        help = "<LOC NEWOPTIONS_27>Sets the randomization for the AI\'s TMLs making them miss more. Higher means less accurate.",
        key = 'TMLRandom',
        values = {
            {
                text = "0%",
                help = "<LOC NEWOPTIONS_27>No Randomization",
                key = '0',
            },
            {
                text = "2.5%",
                help = "<LOC NEWOPTIONS_27>2.5% Randomization",
                key = '2.5',
            },
            {
                text = "5%",
                help = "<LOC NEWOPTIONS_27>5% Randomization",
                key = '5',
            },
            {
                text = "7.5%",
                help = "<LOC NEWOPTIONS_27>7.5% Randomization",
                key = '7.5',
            },
            {
                text = "10%",
                help = "<LOC NEWOPTIONS_27>10% Randomization",
                key = '10',
            },
            {
                text = "12.5%",
                help = "<LOC NEWOPTIONS_27>12.5% Randomization",
                key = '12.5',
            },
            {
                text = "15%",
                help = "<LOC NEWOPTIONS_27>15% Randomization",
                key = '15',
            },
            {
                text = "17.5%",
                help = "<LOC NEWOPTIONS_27>17.5% Randomization",
                key = '17.5',
            },
            {
                text = "20%",
                help = "<LOC NEWOPTIONS_27>20% Randomization",
                key = '20',
            },
			{
                text = "50%",
                help = "<LOC NEWOPTIONS_27>50% Randomization",
                key = '50',
            },
			{
                text = "90%",
                help = "<LOC NEWOPTIONS_27>90% Randomization",
                key = '90',
            },
        },
   },
   {   default = 10,
        label = "<LOC NEWOPTIONS_28>AI Land Expansion Limit",
        help = "<LOC NEWOPTIONS_29>Set the limit for the number of land expansions that each AI can have (will still be modified by the number of AIs).",
        key = 'LandExpansionsAllowed',
        values = {
            {
                text = "<LOC NEWOPTIONS_35>None",
                help = "<LOC NEWOPTIONS_29>No Land Expansions Allowed",
                key = '0',
            },
            {
                text = "1",
                help = "<LOC NEWOPTIONS_29>1 Land Expansion Allowed",
                key = '1',
            },
         {
                text = "2",
                help = "<LOC NEWOPTIONS_29>2 Land Expansions Allowed",
                key = '2',
            },
            {
                text = "3",
                help = "<LOC NEWOPTIONS_29>3 Land Expansions Allowed",
                key = '3',
            },
            {
                text = "4",
                help = "<LOC NEWOPTIONS_29>4 Land Expansions Allowed",
                key = '4',
            },
            {
                text = "5",
                help = "<LOC NEWOPTIONS_29>5 Land Expansions Allowed",
                key = '5',
            },
            {
                text = "6",
                help = "<LOC NEWOPTIONS_29>6 Land Expansions Allowed",
                key = '6',
            },
            {
                text = "7",
                help = "<LOC NEWOPTIONS_29>7 Land Expansions Allowed",
                key = '7',
            },
            {
                text = "8",
                help = "<LOC NEWOPTIONS_29>8 Land Expansions Allowed",
                key = '8',
            },
            {
                text = "<LOC NEWOPTIONS_38>Unlimited",
                help = "<LOC NEWOPTIONS_29>Unlimited Land Expansions Allowed",
                key = '99999',
            },
        },
   },
   {   default = 10,
        label = "<LOC NEWOPTIONS_30>AI Naval Expansion Limit",
        help = "<LOC NEWOPTIONS_31>Set the limit for the number of naval expansions that each AI can have.",
        key = 'NavalExpansionsAllowed',
        values = {
            {
                text = "None",
                help = "<LOC NEWOPTIONS_35>No Naval Expansions Allowed",
                key = '0',
            },
            {
                text = "1",
                help = "<LOC NEWOPTIONS_31>1 Naval Expansion Allowed",
                key = '1',
            },
         {
                text = "2",
                help = "<LOC NEWOPTIONS_31>2 Naval Expansions Allowed",
                key = '2',
            },
            {
                text = "3",
                help = "<LOC NEWOPTIONS_31>3 Naval Expansions Allowed",
                key = '3',
            },
            {
                text = "4",
                help = "<LOC NEWOPTIONS_31>4 Naval Expansions Allowed",
                key = '4',
            },
            {
                text = "5",
                help = "<LOC NEWOPTIONS_31>5 Naval Expansions Allowed",
                key = '5',
            },
            {
                text = "6",
                help = "<LOC NEWOPTIONS_31>6 Naval Expansions Allowed",
                key = '6',
            },
            {
                text = "7",
                help = "<LOC NEWOPTIONS_31>7 Naval Expansions Allowed",
                key = '7',
            },
            {
                text = "8",
                help = "<LOC NEWOPTIONS_31>8 Naval Expansions Allowed",
                key = '8',
            },
            {
                text = "<LOC NEWOPTIONS_38>Unlimited",
                help = "<LOC NEWOPTIONS_31>Unlimited Naval Expansions Allowed",
                key = '99999',
            },
        },
   },
   {   default = 2,
        label = "<LOC NEWOPTIONS_32>AIx Omni Setting",
        help = "<LOC NEWOPTIONS_33>Set the build rate multiplier for the cheating AIs.",
        key = 'OmniCheat',
        values = {
            {
                text = "<LOC _YES>On",
                help = "<LOC NEWOPTIONS_33>Full map omni on",
                key = 'on',
            },
            {
                text = "<LOC _NO>Off",
                help = "<LOC NEWOPTIONS_36>Full map omni off",
                key = 'off',
            },
        },
   },
}
