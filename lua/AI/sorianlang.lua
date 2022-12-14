#****************************************************************************
#**
#**  File     :  /lua/AI/sorianlang.lua
#**  Author(s): Michael Robbins aka Sorian
#**
#**  Summary  : Language File for the Sorian AIs
#**
#****************************************************************************

AINames = {
	#Czar
    uaa0310 = {
        'Donut of Doom',
		'Chariot of Fire',
		'Champion of the Sky',
        'Aera Cura',
        'Acca Larentia',
        'Averna',
        'Bellona',
        'Carna',
        'Consus',
        'Dea Tacita',
        'Discordia',
        'Fama',
        'Fornax',
        'Furrina',
        'Hippona',
        'Invidia',
        'Juturna',
        'Levana',
        'Lucina',
        'Mellona',
        'Nerio',
        'Orbona',
        'Pax',
        'Rumina',
        'Rusina',
        'Salus',
        'Stata Mater',
        'Statina',
        'Tempestes',
        'Vacuna',
        'Veritas',
        'Vica Pota',
        'Viriplaca',
        'Volumna',
        'Voluptas', 
    },
	#Colossus
    ual0401 = {
        'Golem',
        'Cyclops',
		'Missionary',
		'Wrath',
        'Anakim',
        'Argus',
        'Atlas',
        'Bestla',
        'Arges',
        'Brontes',
        'Telemus',
        'Fir Bolg',
        'Balor',
        'Bres',
        'Tethra',
        'Pantagruel',
        'Athos',
        'Echion',
        'Goliath',
        'Gorm',
        'Jentilak',
        'Angrboda',
    },
	#Tempest
    uas0401 = {
        'Sea Cleanser',
		'Purifier',
        'Divine Hammer',
		'Divine Thunder',
		'Divine Intervention',
       	'Divine Punishment',
		'Truth',
		'Peace',
       	'Glory',
		'Devotion',
		'Faith',
       	'Purity',
    },
	#Soul Ripper
    ura0401 = {
        'Beast',
        'Ogre',
        'Orc',
        'Goblin',
        'Troll',
        'Warg',
        'Hobgoblin',
        'Gremlin',
        'Imp',
        'Meffit',
    },
	#Scathis
    url0401 = {
        'Base Pounder',
        'Aconite',
        'Adonis',
        'Bloodflower',
		'Doom Blossom',
        'Foxglove',
        'Henbane',
        'Larkspur',
        'Oleander',
        'Hemlock',
        'Toloache',
    },
	#Monkeylord
    url0402 = {
        'Gorilla King',
		'Berserker',
		'Flayer',
		'Shelob',
		'Your End',
        'Black Widow',
        'Black Katipo',
        'Red Widow',
        'Orb Weaver',
        'Spiny',
        'Funnel Web',
        'Recluse',
        'Huntsman',
        'Lynx',
        'Tarantula',
        'Wolf',
        'Six Eyes',
        'Bolas', 
    },
	#Megalith
    xrl0403 = {
        'Fiddler',
		'Soldier',
		'Hermit',
		'Spider',
		'Opilio',
		'Tanner',
    },
	#Fatboy
	uel0401 = {
        'Fort Knox',
		'Bertha',
		'Victory',
		'Firepower',
        'Centurion',
        'Conqueror',
        'Chieftain',
        'Challenger',
        'Scorpion',
        'Samaritan',
        'Samson',
        'Stormer',
        'Saracen',
        'Spartan',
        'Saxon',
        'Abrams',
        'Sheridan',
        'Paladin',
        'Bradley',
        'Stryker',
    },
	#Novax Satellite
	xea0002 = {
        'Skynet',
		'Death from Above',
		'Eye in the Sky',
		'Orbital Defense',
		'UEF Defense Net',
		'Solar Bean',
    },
	#Atlantis
	ues0401 = {
        'Sword of the Ocean',
		'Great White',
		'Kraken',
		'Deep One',
    },
	#Mavor
    ueb2401 = {
        'Longshot',
		'Pride of the UEF',
        'Ballista',
        'Catapult',
        'Helepolis',
        'Mangonel',
        'Petrary',
        'Trebuchet',
        'Warwolf',
        'Onager',
        'Bad Neighbor',
		'Gods Slingshot',
    },
	#Ahwassa
	xsa0402 = {
        'Chariot of Doom',
		'Wrath',
		'Vengeance',
		'Revenge',
		'Anger',
		'Fury',
		'Avenger',
    },
	#Ythotha
	xsl0401 = {
        'Bolthorn',
        'Grid',
        'Hrod',
        'Hymir',
        'Loki',
        'Ymir',
        'Kapre',
        'Talos',
        'Oni',
        'Crius',
        'Hyperion',
        'Ophion',
        'Tethys',
        'Dione',
        'Thermis',
    },
}

AIChatText = {
	nukechat = { 
		'???????????????[target]??????', 
		'??? [target]????????????', 
		'????????????????????????[target]', 
		'???[target]???????????????????????????',
		'?????????????????????[target]??????',
	},
	targetchat = { 
		'???????????????[target]', 
		'???????????????[target]', 
		'??????[target]', 
		'???????????????[target]',
		'??????????????????[target]???',
	},
	tcrespond = {
		'???????????????????????? [target].',
		'??????????????????[target].',
		'????????????????????? [target].',
		'?????????????????? [target].',
		'OK??? ???[target] ????????????',
	},
	tcerrorally = {
		'[target]????????????',
		'????????? [target] ????????????',
		'[target] ??????????????????????????????',
		'?????? [target] ????????????????????????????????????????????????',
		'?????? [target] ????????????????????????????????????????????????????????????',
	},
	nuketaunt = {
		'????????????????????????',
		'???????????????????????????',
		'??????????????????????????????',
		'???????????????????????????',
		'?????????????????????????????????????????????',
		'??????????????????????????????????????????~ >_<',
		'????????????????????????',
		'????????????????????????',
		'????????????????????????',
	},
	t4taunt = {
		'??????????????????',
		'T4???????????????????????????',
		'???????????????????????????????????????',
		'???????????????????????????',
		'??????????????????t4???????????????hx???',
		'????????????',
		'?????????',
	},
	ilost = {
		'??????????????????????????????',
		'????????????',
		'?????????????????????????????????????????????',
		'???????????????????????????????????????????????????.',
		'?????????????????????????????????????????????',
		'????????????????????????????????????????????????????????????',
		'????????????????????????????????????????????????',
		'????????????????????????',
		'????????????????????????????????????????????????',
		'??????????????????????????????????????????????????????',
		'????????????????????????????????????????????????',
		'????????????????????????????????????????????????????????????',
		'????????????????????????????????????????????????',
		'?????????????????????????????????????????????',
		'????????????????????????????????????????????????',
		'?????????????????????',
		'???????????????????????????',
		'????????????????????????????????????????????????',
		'?????????????????????????????????????????????',
		'?????????????????????????????????????????????',
		'?????????????????????????????????',
		'???????????????????????????????????????',
		'???????????????????????????????????????',
		'?????????????????????',
		'???????????????',
		'???????????????????????????',
		'???????????????????????????',
		'????????????????????????',
		'?????????????????????????????????????????????',
		'?????????????????????????????????????????????',
		'??????????????????????????????',
		'?????????????????????????????????????????????',
		'??????????????????????????????',
		'???????????????????????????????????????',
		'???????????????????????????????????????',
		'??????????????????????????????????????????',
		'?????????????????????????????????????????????',
		'????????????????????????????????????',
		'?????????????????????',
		'?????????????????????????????????????????????',
		'?????????????????????????????????????????????',
		'???????????????',
		},
	badmap = {
		'????????????????????????????????????????????????????????????',
		'?????????????????????????????????????????????????????????',
		'?????????????????????????????????????????????????????????',
		'???????????????????????????????????????',
		'?????????????????????????????????????????????????????????????????????~',
		'???????????????????????????',
		'????????????',
		'????????????????????????????????????????????????????????????????????????',
		'???????????????????????????????????????',
		'???????????????????????????????????????????????????????????????',
		'??????????????????????????????????????????',
		'??????????????????????????????????????????????????????',
		'??????????????????????????????',
		'???????????????????????????',
		'????????????????????????????????????????????????',
		'????????????????????????????????????????????????',
		'??????????????????????????????',
		'???????????????????????????',
		'???????????????????????????',
		'?????????????????????',
		'???????????????????????????????????????????????????????????????????????????',
		'????????????????????????????????????',
		'?????????????????????????????????',
		'???????????????????????????????????????',
		'???????????????',
		'????????????????????????????????????????????????',
		'????????????????????????????????????????????????',
		'???????????????????????????',
		'?????????????????????????????????????????????',
		'?????????????????????????????????????????????????????????????????????',
		'?????????????????????????????????????????????',
		'??????????????????????????????',
		'????????????????????????????????????????????????????????????????????????',
		'????????????????????????????????????????????????',
		'?????????????????????????????????????????????',
		'?????????????????????????????????????????????',
		'?????????????????????????????????????????????????????????????????????????????????',
		'??????????????????????????????',
		'??????????????????????????????',
		'????????????????????????????????????????????????',
		'???????????????????????????',
		'???????????????????????????',
		'????????????????????????',
		'?????????????????????????????????????????????????????????????????????????????????',
		'???????????????????????????????????????????????????????????????',
		'?????????????????????????????????????????????',
		'????????????',
		'???TM??????????????????',
		'?????????????????????????????????????????????????????????????????????j8????????????????????????',
		'????????????',
		'?????????????????????????????????????????????',
		'???????????????????????????...',
		'????????????????????????????????????????????????????????????',
		'???????????????',
		'???????????????????????????????????????????????????',
		'?????????????????????',
		'???????????????????????????????????????????????????????????????????????????????????????????????????',
		'??????AI????????????????????????',
		'emmmmmmm',
		'2333333',
		'????????????KKKK??????????????????????????????',
		'????????????????????????',
	},
	focuschat = {
		'Currently focusing on [extra].',
	},
	giveengineer = {
		'????????????',
		'???????????????????????????????????????',
		'?????????????????????',
		'?????????????????????????????????????????????',
		'???',
		'??????????????????',
		'?????????????????????',
	},
	genericchat = {
		'?????????',
		'?????????',
		'ok',
		'?????????',
		'????????????????????????',
		'???',
		'??????',
		'???????????????',
	},
	takingcontrol = {
        '[AI??????]: ?????????????????????',
        '[AI??????]: ??????????????????????????????',
        '[AI??????]: ????????????????????????????????????????????????????????????',
    }
}