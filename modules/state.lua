local constants = require('modules.constants')
local state_defaults = require('modules.state_defaults')

local state_store_module = {}

local function state_prefix(zone)
    return zone == constants.APOLLYON and 'apollyon' or 'temenos'
end

local function state_cap_key(zone)
    return state_prefix(zone)..'_cap'
end

local function state_climb_remaining_key(zone)
    return state_prefix(zone)..'_climb_remaining'
end

local function normalize_saved_state(value)
    if value == 'opened' then
        return 'std'
    end
    return value
end

function state_store_module.new(context)
    local state = nil

    local store = {}

    local function valid_sector(zone, sector)
        if not sector or sector == 'none' then
            return false
        end
        for _, candidate in ipairs(constants.zone_sectors[zone]) do
            if candidate == sector then
                return true
            end
        end
        return false
    end

    local function load_chest_state(zone)
        local prefix = state_prefix(zone)
        local zone_tracking = {}
        local legacy_bonus = nil

        for _, sector in ipairs(constants.zone_sectors[zone]) do
            local value = normalize_saved_state(state[('%s_%s'):format(prefix, sector)])
            if value == 'bonus' then
                legacy_bonus = legacy_bonus or sector
            elseif value == 'std' then
                zone_tracking[sector] = 'std'
            end
        end

        local saved_last_bonus = state[prefix..'_last_bonus']
        context.last_bonus[zone] = valid_sector(zone, saved_last_bonus) and saved_last_bonus or nil

        if legacy_bonus then
            context.last_bonus[zone] = context.last_bonus[zone] or legacy_bonus
            zone_tracking = {}
        end

        context.tracking[zone] = zone_tracking
        return legacy_bonus ~= nil
    end

    local function save_temp_item_state(zone)
        if not state then return end
        local prefix = state_prefix(zone)
        local items = context.limbus_temp_items[zone]
        state[prefix..'_code'] = items.code and 'obtained' or 'none'
        for _, sector in ipairs(constants.zone_sectors[zone]) do
            for _, number in ipairs(constants.zone_data_numbers[zone][sector]) do
                local key = ('%s_%s_%s_data'):format(prefix, sector, number)
                state[key] = items.data[sector][number] and 'obtained' or 'none'
            end
        end
    end

    local function clear_temp_items(zone)
        context.limbus_temp_items[zone].code = false
        for _, sector in ipairs(constants.zone_sectors[zone]) do
            context.limbus_temp_items[zone].data[sector] = {}
        end
    end

    local function load_temp_item_state(zone)
        if not state then return end
        local prefix = state_prefix(zone)
        clear_temp_items(zone)
        context.limbus_temp_items[zone].code = state[prefix..'_code'] == 'obtained'
        for _, sector in ipairs(constants.zone_sectors[zone]) do
            for _, number in ipairs(constants.zone_data_numbers[zone][sector]) do
                local key = ('%s_%s_%s_data'):format(prefix, sector, number)
                context.limbus_temp_items[zone].data[sector][number] = state[key] == 'obtained'
            end
        end
    end

    local function wipe_temp_item_state(zone)
        if not state then return end
        local prefix = state_prefix(zone)
        state[prefix..'_code'] = 'none'
        for _, sector in ipairs(constants.zone_sectors[zone]) do
            for _, number in ipairs(constants.zone_data_numbers[zone][sector]) do
                state[('%s_%s_%s_data'):format(prefix, sector, number)] = 'none'
            end
        end
        clear_temp_items(zone)
    end

    function store.init_player_state()
        if state then return end
        local player = windower.ffxi.get_player()
        if not player then return end
        state = config.load('data/state_'..player.name..'.xml', state_defaults)
    end

    function store.save_state()
        if not state then return end
        local apollyon_tracking = context.tracking[constants.APOLLYON]
        local temenos_tracking = context.tracking[constants.TEMENOS]
        state.apollyon_NW = apollyon_tracking.NW or 'none'
        state.apollyon_NE = apollyon_tracking.NE or 'none'
        state.apollyon_SW = apollyon_tracking.SW or 'none'
        state.apollyon_SE = apollyon_tracking.SE or 'none'
        state.temenos_N   = temenos_tracking.N  or 'none'
        state.temenos_E   = temenos_tracking.E  or 'none'
        state.temenos_W   = temenos_tracking.W  or 'none'
        state.temenos_C   = temenos_tracking.C  or 'none'
        state.apollyon_last_bonus = context.last_bonus[constants.APOLLYON] or 'none'
        state.temenos_last_bonus = context.last_bonus[constants.TEMENOS] or 'none'
        state.apollyon_cap = context.unit_caps['Apollyon Units'] or 0
        state.temenos_cap = context.unit_caps['Temenos Units'] or 0
        state.apollyon_climb_remaining = context.climb_remaining[constants.APOLLYON] or -1
        state.temenos_climb_remaining = context.climb_remaining[constants.TEMENOS] or -1
        save_temp_item_state(constants.APOLLYON)
        save_temp_item_state(constants.TEMENOS)
        config.save(state, 'global')
    end

    function store.reset_temp_item_counter(zone)
        if not state then return end
        wipe_temp_item_state(zone)
    end

    function store.load_state()
        if not state then return end
        context.unit_caps['Apollyon Units'] = tonumber(state.apollyon_cap) or 0
        context.unit_caps['Temenos Units'] = tonumber(state.temenos_cap) or 0
        context.climb_remaining[constants.APOLLYON] = tonumber(state.apollyon_climb_remaining) or -1
        context.climb_remaining[constants.TEMENOS] = tonumber(state.temenos_climb_remaining) or -1
        local migrated_apollyon = load_chest_state(constants.APOLLYON)
        local migrated_temenos = load_chest_state(constants.TEMENOS)
        load_temp_item_state(constants.APOLLYON)
        load_temp_item_state(constants.TEMENOS)
        if migrated_apollyon or migrated_temenos then
            store.save_state()
        end
    end

    function store.set_cap(zone_id, cap)
        if not state then return end
        state[state_cap_key(zone_id)] = cap
        store.save_state()
    end

    function store.set_climb_remaining(zone_id, remaining)
        if not state then return end
        state[state_climb_remaining_key(zone_id)] = remaining
        store.save_state()
    end

    function store.unload_character_state()
        state = nil
    end

    return store
end

return state_store_module
