local constants = {}

constants.APOLLYON = 38
constants.TEMENOS  = 37

constants.zone_name = {
    [constants.APOLLYON] = 'Apollyon',
    [constants.TEMENOS]  = 'Temenos',
}

constants.zone_sectors = {
    [constants.APOLLYON] = {'NW', 'SW', 'NE', 'SE'},
    [constants.TEMENOS]  = {'N', 'W', 'E', 'C'},
}

constants.APOLLYON_DATA_NUMBERS = {
    NW = {'1', '2', '3', '4', '5'},
    SW = {'1', '2', '3', '4'},
    NE = {'1', '2', '3', '4', '5'},
    SE = {'1', '2', '3', '4'},
}

constants.TEMENOS_DATA_NUMBERS = {
    N = {'1', '2', '3', '4', '5', '6', '7'},
    W = {'1', '2', '3', '4', '5', '6', '7'},
    E = {'1', '2', '3', '4', '5', '6', '7'},
    C = {'1', '2', '3', '4'},
}

constants.zone_data_numbers = {
    [constants.APOLLYON] = constants.APOLLYON_DATA_NUMBERS,
    [constants.TEMENOS] = constants.TEMENOS_DATA_NUMBERS,
}

constants.APOLLYON_CHESTS = {
    NW = {x = -211, y =  542, z =   0},
    NE = {x =  214, y =  542, z =   0},
    SW = {x = -109, y = -429, z =   0},
    SE = {x =  112, y = -430, z =   0},
}

constants.TEMENOS_CHESTS = {
    N  = {x = -598, y =  457, z =  84},
    W  = {x = -596, y =  177, z =   4},
    E  = {x = -596, y = -102, z =  84},
    C  = {x = -281, y = -423, z = -162},
}

constants.STANDARD_AMT = 3000
constants.BONUS_AMT    = 5000
constants.CLIMB_LIMIT  = 5
constants.INVENTORY_WARNING_FREE_SLOTS = 10
constants.CHEST_DIST   = 7
constants.CHEST_GRACE  = 1
constants.REWARD_TEXT_DIST = 100
constants.TEMP_REFRESH_PAUSE_AFTER_CHEST = 12
constants.RESET_CHECK_INTERVAL = 60
constants.HUD_WIDTH    = 40
constants.CHECKED      = '[X]'
constants.UNCHECKED    = '[-]'

constants.zone_field = {
    [constants.APOLLYON] = 'Apollyon Units',
    [constants.TEMENOS]  = 'Temenos Units',
}

function constants.is_limbus_zone(zone)
    return zone == constants.APOLLYON or zone == constants.TEMENOS
end

return constants
