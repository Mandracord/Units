local constants = require('modules.constants')

local state_defaults = T{}
state_defaults.created_at  = 0
state_defaults.next_reset_at = 0
state_defaults.apollyon_cap = 0
state_defaults.apollyon_climb_remaining = -1
state_defaults.apollyon_NW = 'none'
state_defaults.apollyon_NE = 'none'
state_defaults.apollyon_SW = 'none'
state_defaults.apollyon_SE = 'none'
state_defaults.apollyon_code = 'none'
state_defaults.apollyon_NW_1_data = 'none'
state_defaults.apollyon_NW_2_data = 'none'
state_defaults.apollyon_NW_3_data = 'none'
state_defaults.apollyon_NW_4_data = 'none'
state_defaults.apollyon_NW_5_data = 'none'
state_defaults.apollyon_NE_1_data = 'none'
state_defaults.apollyon_NE_2_data = 'none'
state_defaults.apollyon_NE_3_data = 'none'
state_defaults.apollyon_NE_4_data = 'none'
state_defaults.apollyon_NE_5_data = 'none'
state_defaults.apollyon_SW_1_data = 'none'
state_defaults.apollyon_SW_2_data = 'none'
state_defaults.apollyon_SW_3_data = 'none'
state_defaults.apollyon_SW_4_data = 'none'
state_defaults.apollyon_SE_1_data = 'none'
state_defaults.apollyon_SE_2_data = 'none'
state_defaults.apollyon_SE_3_data = 'none'
state_defaults.apollyon_SE_4_data = 'none'
state_defaults.temenos_N   = 'none'
state_defaults.temenos_E   = 'none'
state_defaults.temenos_W   = 'none'
state_defaults.temenos_C   = 'none'
state_defaults.temenos_cap = 0
state_defaults.temenos_climb_remaining = -1
state_defaults.temenos_code = 'none'

for _, sector in ipairs(constants.zone_sectors[constants.TEMENOS]) do
    for _, number in ipairs(constants.TEMENOS_DATA_NUMBERS[sector]) do
        state_defaults[('temenos_%s_%s_data'):format(sector, number)] = 'none'
    end
end

return state_defaults
