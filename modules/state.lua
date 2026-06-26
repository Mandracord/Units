local constants = require('modules.constants')
local state_defaults = require('modules.state_defaults')

local state_store_module = {}

local function next_reset_after(t)
    local d = os.date('!*t', t)
    local days_until_sunday = (8 - d.wday) % 7
    local sunday_1500 = t
        - (d.hour * 3600 + d.min * 60 + d.sec)
        + days_until_sunday * 86400
        + 15 * 3600

    if sunday_1500 <= t then
        sunday_1500 = sunday_1500 + 7 * 86400
    end
    return sunday_1500
end

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
    local reset_schedule_token = 0

    local store = {}

    local function ensure_next_reset_at()
        if not state then return nil end
        local next_reset = tonumber(state.next_reset_at)
        if next_reset and next_reset > 0 then
            return next_reset
        end

        local created = tonumber(state.created_at)
        if created and created > 0 then
            next_reset = next_reset_after(created)
        else
            next_reset = next_reset_after(os.time())
        end

        state.next_reset_at = next_reset
        config.save(state, 'global')
        return next_reset
    end

    local function state_is_expired()
        local next_reset = ensure_next_reset_at()
        return next_reset and os.time() >= next_reset
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
        if not tonumber(state.created_at) or tonumber(state.created_at) <= 0 then
            state.created_at = os.time()
        end
        ensure_next_reset_at()
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
        state.apollyon_cap = context.unit_caps['Apollyon Units'] or 0
        state.temenos_cap = context.unit_caps['Temenos Units'] or 0
        state.apollyon_climb_remaining = context.climb_remaining[constants.APOLLYON] or -1
        state.temenos_climb_remaining = context.climb_remaining[constants.TEMENOS] or -1
        save_temp_item_state(constants.APOLLYON)
        save_temp_item_state(constants.TEMENOS)
        config.save(state, 'global')
    end

    function store.reset_weekly_tracking_state()
        if not state then return end
        state.created_at  = os.time()
        state.next_reset_at = next_reset_after(os.time())
        state.apollyon_NW = 'none'
        state.apollyon_NE = 'none'
        state.apollyon_SW = 'none'
        state.apollyon_SE = 'none'
        state.temenos_N   = 'none'
        state.temenos_E   = 'none'
        state.temenos_W   = 'none'
        state.temenos_C   = 'none'
        state.apollyon_climb_remaining = -1
        state.temenos_climb_remaining = -1
        context.climb_remaining[constants.APOLLYON] = -1
        context.climb_remaining[constants.TEMENOS] = -1
        context.tracking[constants.APOLLYON] = {}
        context.tracking[constants.TEMENOS]  = {}
        wipe_temp_item_state(constants.APOLLYON)
        wipe_temp_item_state(constants.TEMENOS)
        config.save(state, 'global')
    end

    function store.reset_temp_item_counter(zone)
        if not state then return end
        wipe_temp_item_state(zone)
    end

    function store.load_state()
        if not state then return end
        ensure_next_reset_at()
        context.unit_caps['Apollyon Units'] = tonumber(state.apollyon_cap) or 0
        context.unit_caps['Temenos Units'] = tonumber(state.temenos_cap) or 0
        context.climb_remaining[constants.APOLLYON] = tonumber(state.apollyon_climb_remaining) or -1
        context.climb_remaining[constants.TEMENOS] = tonumber(state.temenos_climb_remaining) or -1
        if state_is_expired() then
            windower.add_to_chat(167, 'Units: Weekly reset detected - chest tracking cleared.')
            store.reset_weekly_tracking_state()
            return
        end

        context.tracking[constants.APOLLYON] = {
            NW = normalize_saved_state(state.apollyon_NW) ~= 'none' and normalize_saved_state(state.apollyon_NW) or nil,
            NE = normalize_saved_state(state.apollyon_NE) ~= 'none' and normalize_saved_state(state.apollyon_NE) or nil,
            SW = normalize_saved_state(state.apollyon_SW) ~= 'none' and normalize_saved_state(state.apollyon_SW) or nil,
            SE = normalize_saved_state(state.apollyon_SE) ~= 'none' and normalize_saved_state(state.apollyon_SE) or nil,
        }
        context.tracking[constants.TEMENOS] = {
            N = normalize_saved_state(state.temenos_N) ~= 'none' and normalize_saved_state(state.temenos_N) or nil,
            E = normalize_saved_state(state.temenos_E) ~= 'none' and normalize_saved_state(state.temenos_E) or nil,
            W = normalize_saved_state(state.temenos_W) ~= 'none' and normalize_saved_state(state.temenos_W) or nil,
            C = normalize_saved_state(state.temenos_C) ~= 'none' and normalize_saved_state(state.temenos_C) or nil,
        }
        load_temp_item_state(constants.APOLLYON)
        load_temp_item_state(constants.TEMENOS)
    end

    function store.schedule_weekly_reset_check()
        if not state then return end
        reset_schedule_token = reset_schedule_token + 1
        local token = reset_schedule_token

        coroutine.schedule(function()
            if token ~= reset_schedule_token then
                return
            end

            if state and state_is_expired() then
                windower.add_to_chat(167, 'Units: Weekly reset detected - chest tracking cleared.')
                store.reset_weekly_tracking_state()
                context.update_text_box()
            end

            store.schedule_weekly_reset_check()
        end, constants.RESET_CHECK_INTERVAL)
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
        reset_schedule_token = reset_schedule_token + 1
    end

    return store
end

return state_store_module
