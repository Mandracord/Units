local default_settings = require('modules.settings')
local constants = require('modules.constants')
local parsers = require('modules.parsers')
local reward_packets = require('modules.reward_packets')
local hud = require('modules.hud')
local sectors_module = require('modules.sectors')
local state_store_module = require('modules.state')
local inventory = require('modules.inventory')

local APOLLYON = constants.APOLLYON
local TEMENOS = constants.TEMENOS
local zone_name = constants.zone_name
local zone_sectors = constants.zone_sectors
local zone_data_numbers = constants.zone_data_numbers
local BONUS_AMT = constants.BONUS_AMT
local CHEST_GRACE = constants.CHEST_GRACE
local REWARD_TEXT_DIST = constants.REWARD_TEXT_DIST
local zone_field = constants.zone_field
local is_limbus_zone = constants.is_limbus_zone
local parse_units_gain = parsers.units_gain
local zone_id_from_name = parsers.zone_id_from_name
local parse_units_total = parsers.units_total
local parse_climb_remaining = parsers.climb_remaining
local parse_obtained_item = parsers.obtained_item
local parse_temporary_item = parsers.temporary_item
local parse_limbus_temp_item = parsers.limbus_temp_item
local normalize_chat_lines = parsers.normalize_chat_lines
local ignore_self = parsers.ignore_self
local exact_chest_reward_text_amount = reward_packets.exact_chest_reward_text_amount
local packet_reward_amount = reward_packets.packet_reward_amount

-----------------------------------------------------------
-- Initialize
-----------------------------------------------------------

local counter = 0
local refresh_rate = 2
local refresh_delay = 1

local settings = config.load(default_settings)
local text_box = texts.new(settings)
text_box:visible(false)

local player_name = nil
local hud_hidden = false
local current_units = {
    ['Apollyon Units'] = 0,
    ['Temenos Units'] = 0
}
local unit_caps = {
    ['Apollyon Units'] = 0,
    ['Temenos Units'] = 0
}
local climb_remaining = {
    [APOLLYON] = -1,
    [TEMENOS] = -1,
}
local display_initialized = false
local unit_fields = L {'Apollyon Units', 'Temenos Units'}
local requests = {
    [0x118] = packets.new('outgoing', 0x115)
}
local reward_packet_ids = {
    [0x027] = true,
    [0x029] = true,
    [0x032] = true,
    [0x033] = true,
    [0x034] = true,
    [0x05C] = true,
}

local tracking = {
    [APOLLYON] = {},
    [TEMENOS]  = {},
}
local limbus_temp_items = {
    [APOLLYON] = {
        code = false,
        data = {
            NW = {},
            NE = {},
            SW = {},
            SE = {},
        },
    },
    [TEMENOS] = {
        code = false,
        data = {
            N = {},
            W = {},
            E = {},
            C = {},
        },
    },
}
local active_zone    = nil
local pending_chest_open = {
    zone = nil,
    sector = nil,
    timestamp = 0,
    resolve_scheduled = false,
}
local pending_reward = {
    zone = nil,
    amount = nil,
    timestamp = 0,
}
local recent_chest_open = {
    zone = nil,
    sector = nil,
    timestamp = 0,
}
local last_action = {
    target = nil,
    sector = nil,
    timestamp = 0,
}
local temp_refresh_paused_until = {
    [APOLLYON] = 0,
    [TEMENOS] = 0,
}
local debug_enabled = false

local update_text_box
local record_chest
local request_update
local refresh_temp_items

local function trace_log(message)
    local player = player_name or (windower.ffxi.get_player() and windower.ffxi.get_player().name) or 'unknown'
    local path = windower.addon_path .. 'data/units_debug_' .. player .. '.log'
    local file = io.open(path, 'a')
    if file then
        file:write(('[%s] %s\n'):format(os.date('%Y-%m-%d %H:%M:%S'), message))
        file:close()
    end
end

local function debug_log(message)
    if debug_enabled then
        trace_log(message)
        windower.add_to_chat(200, 'Units Debug: '..message)
    end
end

local sector_detector = sectors_module.new({
    get_active_zone = function()
        return active_zone
    end,

    debug_log = debug_log,
})

local clear_recent_chest = sector_detector.clear_recent_chest
local clear_recent_reward_sector = sector_detector.clear_recent_reward_sector
local current_chest_sector = sector_detector.current_chest_sector
local current_nearest_sector = sector_detector.current_nearest_sector
local target_chest_sector = sector_detector.target_chest_sector
local target_nearest_sector = sector_detector.target_nearest_sector
local remember_recent_chest = sector_detector.remember_recent_chest
local remember_recent_reward_sector = sector_detector.remember_recent_reward_sector
local detected_reward_sector = sector_detector.detected_reward_sector
local detect_sector = sector_detector.detect_sector
local player_near_chest = sector_detector.player_near_chest

local character_state = state_store_module.new({
    tracking = tracking,
    limbus_temp_items = limbus_temp_items,
    unit_caps = unit_caps,
    climb_remaining = climb_remaining,

    get_active_zone = function()
        return active_zone
    end,

    update_text_box = function()
        update_text_box()
    end,
})

local init_player_state = character_state.init_player_state
local save_state = character_state.save_state
local load_state = character_state.load_state
local schedule_weekly_reset_check = character_state.schedule_weekly_reset_check
local unload_character_state = character_state.unload_character_state
local reset_temp_item_counter = character_state.reset_temp_item_counter
local set_cap = character_state.set_cap
local set_climb_remaining = character_state.set_climb_remaining

-----------------------------------------------------------
-- Pending Reward State
-----------------------------------------------------------

local function clear_pending_chest_open()
    pending_chest_open.zone = nil
    pending_chest_open.sector = nil
    pending_chest_open.timestamp = 0
    pending_chest_open.resolve_scheduled = false
end

local function clear_pending_reward()
    pending_reward.zone = nil
    pending_reward.amount = nil
    pending_reward.timestamp = 0
end

local function clear_recent_chest_open()
    recent_chest_open.zone = nil
    recent_chest_open.sector = nil
    recent_chest_open.timestamp = 0
end

local function clear_last_action()
    last_action.target = nil
    last_action.sector = nil
    last_action.timestamp = 0
end

local function reset_temp_counter_after_chest(zone)
    if not zone_data_numbers[zone] then
        return
    end

    reset_temp_item_counter(zone)
    temp_refresh_paused_until[zone] = os.time() + constants.TEMP_REFRESH_PAUSE_AFTER_CHEST
end

local function pending_chest_open_active()
    if pending_chest_open.zone ~= active_zone or not pending_chest_open.sector then
        return false
    end
    if (os.time() - pending_chest_open.timestamp) > CHEST_GRACE then
        clear_pending_chest_open()
        return false
    end
    return true
end



local function mark_pending_chest_open(sector)
    if not active_zone or not sector then
        return
    end
    pending_chest_open.zone = active_zone
    pending_chest_open.sector = sector
    pending_chest_open.timestamp = os.time()
    pending_chest_open.resolve_scheduled = false
    recent_chest_open.zone = active_zone
    recent_chest_open.sector = sector
    recent_chest_open.timestamp = pending_chest_open.timestamp
end

local function pending_reward_active()
    if pending_reward.zone ~= active_zone or not pending_reward.amount then
        return false
    end
    if (os.time() - pending_reward.timestamp) > CHEST_GRACE then
        clear_pending_reward()
        return false
    end
    return true
end

local function pending_or_detected_sector()
    if pending_chest_open_active() then
        return pending_chest_open.sector
    end
    return detect_sector()
end

local function record_pending_reward()
    if not pending_reward_active() then
        return false
    end

    local sector = pending_or_detected_sector()
    if not sector then
        debug_log('pending reward has no sector to attach to.')
        return false
    end

    record_chest(sector, pending_reward.amount)
    clear_pending_reward()
    return true
end

local function bonus_chest_warning_state()
    local field = active_zone and zone_field[active_zone] or nil
    if not field then
        return {
            near_cap = false,
            unit_capped = false,
            inventory_near_full = inventory.is_main_inventory_near_full(constants.INVENTORY_WARNING_FREE_SLOTS),
            bonus_chest_may_be_lost = false,
        }
    end

    local current = tonumber(current_units[field]) or 0
    local cap = tonumber(unit_caps[field]) or 0
    local unit_capped = cap > 0 and current >= cap
    local near_cap = cap > 0 and current < cap and (cap - current) < constants.STANDARD_AMT
    local inventory_near_full = inventory.is_main_inventory_near_full(constants.INVENTORY_WARNING_FREE_SLOTS)

    return {
        near_cap = near_cap,
        unit_capped = unit_capped,
        inventory_near_full = inventory_near_full,
        bonus_chest_may_be_lost = (near_cap or unit_capped) and inventory_near_full,
    }
end

-----------------------------------------------------------
-- Display
-----------------------------------------------------------

function update_text_box()
    hud.update({
        active_zone = active_zone,
        text_box = text_box,
        hud_hidden = hud_hidden,
        unit_fields = unit_fields,
        current_units = current_units,
        unit_caps = unit_caps,
        tracking = tracking,
        limbus_temp_items = limbus_temp_items,
        climb_remaining = climb_remaining,
        bonus_warning = bonus_chest_warning_state(),
    })
end

-----------------------------------------------------------
-- Chest Recording
-----------------------------------------------------------

function record_chest(sector, amount)
    if not active_zone then return end
    local is_bonus = amount == BONUS_AMT
    local state_name = is_bonus and 'bonus' or 'std'
    local current_state = tracking[active_zone][sector]
    reset_temp_counter_after_chest(active_zone)

    if current_state == state_name then
        save_state()
        update_text_box()
        return
    end

    if current_state == 'bonus' and state_name == 'std' then
        debug_log(('ignored standard chest at %s %s because bonus was already recorded'):format(
            zone_name[active_zone],
            sector
        ))
        save_state()
        update_text_box()
        return
    end

    if current_state == 'std' and state_name == 'std' then
        save_state()
        update_text_box()
        return
    end

    tracking[active_zone][sector] = state_name
    clear_pending_chest_open()
    clear_pending_reward()
    save_state()
    debug_log(('recorded %s chest at %s %s for %d units'):format(
        is_bonus and 'bonus' or 'standard',
        zone_name[active_zone],
        sector,
        amount
    ))

    if debug_enabled then
        if is_bonus then
            windower.add_to_chat(158,
                'Units: BONUS ('..amount..') at '
                ..zone_name[active_zone]..' '..sector..'.')
        else
            windower.add_to_chat(167,
                'Units: Standard ('..amount..') at '
                ..zone_name[active_zone]..' '..sector..'.')
        end
    end

    update_text_box()
end

local function record_temp_item(zone, kind, sector, number, obtained)
    if zone ~= active_zone then
        return false
    end

    if kind == 'code' then
        if limbus_temp_items[zone].code == obtained then
            return false
        end
        limbus_temp_items[zone].code = obtained
    elseif kind == 'data' and sector and number then
        if limbus_temp_items[zone].data[sector][number] == obtained then
            return false
        end
        limbus_temp_items[zone].data[sector][number] = obtained
    else
        return false
    end

    save_state()
    update_text_box()
    debug_log(('%s temp item %s: %s%s%s'):format(
        zone_name[zone],
        obtained and 'obtained' or 'lost',
        kind,
        sector and (' '..sector) or '',
        number and (' #'..number) or ''
    ))
    return true
end

function refresh_temp_items()
    if not zone_data_numbers[active_zone] then
        return false
    end

    if os.time() < (temp_refresh_paused_until[active_zone] or 0) then
        debug_log('temporary item refresh skipped after chest open.')
        return false
    end

    local bag = windower.ffxi.get_items(3)
    if type(bag) ~= 'table' then
        debug_log('temporary item refresh failed: temporary bag unavailable.')
        return false
    end

    local found = {
        code = false,
        data = {},
    }
    for _, sector in ipairs(zone_sectors[active_zone]) do
        found.data[sector] = {}
    end

    for _, item in ipairs(bag) do
        if type(item) == 'table' and type(item.id) == 'number' and item.id > 0 then
            local resource = res.items[item.id]
            local name = resource and (resource.enl or resource.en)
            local zone, kind, sector, number = parse_limbus_temp_item(name)
            if zone == active_zone and kind == 'code' then
                found.code = true
            elseif zone == active_zone and kind == 'data' and sector and number then
                found.data[sector][number] = true
            end
            if debug_enabled and name and (name:match('^Apollyon') or name:match('^Temenos') or name:match('^Tem%.')) then
                debug_log(('temporary bag item: id=%d name=%s matched=%s%s%s'):format(
                    item.id,
                    name,
                    zone and (zone_name[zone]..' '..tostring(kind)) or tostring(kind),
                    sector and (' '..sector) or '',
                    number and (' #'..number) or ''
                ))
            end
        end
    end

    local changed = false
    if found.code and not limbus_temp_items[active_zone].code then
        limbus_temp_items[active_zone].code = true
        changed = true
    end

    for _, sector in ipairs(zone_sectors[active_zone]) do
        for _, number in ipairs(zone_data_numbers[active_zone][sector]) do
            if found.data[sector][number] and not limbus_temp_items[active_zone].data[sector][number] then
                limbus_temp_items[active_zone].data[sector][number] = true
                changed = true
            end
        end
    end

    if changed then
        save_state()
        update_text_box()
        debug_log('refreshed '..zone_name[active_zone]..' temp items from temporary bag.')
    end

    return changed
end

local function is_real_item_update(item, count)
    if type(count) ~= 'number' or count <= 0 then
        return false
    end

    if type(item) == 'number' then
        return item > 0
    end

    if type(item) == 'string' then
        return item ~= '' and item ~= '-'
    end

    return false
end

local function schedule_pending_chest_open_resolution()
    if not pending_chest_open_active() or pending_chest_open.resolve_scheduled then
        return
    end

    pending_chest_open.resolve_scheduled = true
    local zone = pending_chest_open.zone
    local sector = pending_chest_open.sector
    local opened_at = pending_chest_open.timestamp

    coroutine.schedule(function()
        if pending_chest_open.zone ~= zone
            or pending_chest_open.sector ~= sector
            or pending_chest_open.timestamp ~= opened_at then
            return
        end

        pending_chest_open.resolve_scheduled = false

        if pending_reward_active() then
            debug_log('delayed resolution found pending reward; recording detected amount.')
            record_pending_reward()
            return
        end

        pending_chest_open.resolve_scheduled = false
    end, 1.5)
end

local function is_chat_text_source(source)
    return source == 'chat message' or (type(source) == 'string' and source:match('^incoming text'))
end

local function queue_detected_reward(amount, source)
    remember_recent_chest()
    pending_reward.zone = active_zone
    pending_reward.amount = amount
    pending_reward.timestamp = os.time()
    local text_source = is_chat_text_source(source)
    local sector = pending_or_detected_sector()
    if not sector and text_source then
        sector = detected_reward_sector()
        if sector then
            debug_log(('using relaxed text reward sector fallback: %s %s'):format(
                zone_name[active_zone],
                sector
            ))
        end
    end
    debug_log(('matched %d-unit reward from %s; pending sector=%s'):format(
        amount,
        source,
        sector or 'unknown'
    ))

    if sector then
        if pending_chest_open_active() or pending_or_detected_sector() then
            debug_log('using parsed reward text as chest reward source.')
            record_pending_reward()
        else
            debug_log('recording parsed text reward with relaxed sector fallback.')
            record_chest(sector, amount)
            clear_pending_reward()
        end
        return
    end

    request_update()
end

local function record_reward_from_text(amount, source)
    local sector = current_chest_sector() or current_nearest_sector(REWARD_TEXT_DIST)
    if not sector then
        local me = windower.ffxi.get_mob_by_target('me')
        if me then
            debug_log(('text reward had no sector: x=%.2f y=%.2f z=%.2f'):format(
                me.x or 0,
                me.y or 0,
                me.z or 0
            ))
        else
            debug_log('text reward had no sector: player position unavailable.')
        end
    end
    debug_log(('text reward detected: amount=%d source=%s sector=%s'):format(
        amount,
        source,
        sector or 'unknown'
    ))

    pending_reward.zone = active_zone
    pending_reward.amount = amount
    pending_reward.timestamp = os.time()

    if sector then
        record_chest(sector, amount)
        clear_pending_reward()
        clear_pending_chest_open()
        clear_recent_chest_open()
        return true
    end

    request_update()
    return false
end

local function handle_reward_line(clean, source)
    if clean == '' or ignore_self(clean) then
        return false
    end

    local zone, amount = parse_units_gain(clean)
    if not zone or not amount then
        return false
    end

    if zone_name[active_zone] ~= zone then
        debug_log(('ignored %s reward while in %s zone'):format(zone, zone_name[active_zone]))
        return false
    end

    if not exact_chest_reward_text_amount(amount) then
        debug_log(('ignored non-chest reward amount %d from %s'):format(amount, source))
        return false
    end

    debug_log(('matched exact reward text: zone=%s amount=%d source=%s line=%s'):format(
        zone,
        amount,
        tostring(source),
        clean
    ))

    if is_chat_text_source(source) then
        record_reward_from_text(amount, source)
    else
        queue_detected_reward(amount, source)
    end
    return true
end

local function handle_units_total_line(clean, source)
    if clean == '' or ignore_self(clean) then
        return false
    end

    local zone, total, cap = parse_units_total(clean)
    if not zone or not total or not cap then
        return false
    end

    if zone_name[active_zone] ~= zone then
        debug_log(('ignored %s cap while in %s zone'):format(zone, zone_name[active_zone]))
        return false
    end

    local zone_id = zone_id_from_name(zone)
    local field = zone_id and zone_field[zone_id] or nil
    if not field then
        return false
    end

    local old_cap = tonumber(unit_caps[field]) or 0
    if old_cap ~= cap then
        unit_caps[field] = cap
        set_cap(zone_id, cap)
        debug_log(('updated %s cap from %s: %d -> %d'):format(
            field,
            tostring(source),
            old_cap,
            cap
        ))
        update_text_box()
    end

    local packet_current = tonumber(current_units[field]) or 0
    if packet_current ~= 0 and packet_current ~= total then
        debug_log(('text current for %s differed from packet: text=%d packet=%d'):format(
            field,
            total,
            packet_current
        ))
        request_update()
    end

    return true
end

local function handle_climb_remaining_line(clean, source)
    if clean == '' or ignore_self(clean) then
        return false
    end

    local zone, remaining = parse_climb_remaining(clean)
    if not zone or remaining == nil then
        return false
    end

    if zone_name[active_zone] ~= zone then
        debug_log(('ignored %s climb count while in %s zone'):format(zone, zone_name[active_zone]))
        return false
    end

    local zone_id = zone_id_from_name(zone)
    if not zone_id then
        return false
    end

    local old_remaining = tonumber(climb_remaining[zone_id]) or -1
    if old_remaining ~= remaining then
        climb_remaining[zone_id] = remaining
        set_climb_remaining(zone_id, remaining)
        debug_log(('updated %s climb remaining from %s: %d -> %d'):format(
            zone,
            tostring(source),
            old_remaining,
            remaining
        ))
        update_text_box()
    end

    return true
end

local function handle_temp_item_line(clean, source)
    if not zone_data_numbers[active_zone] or clean == '' or ignore_self(clean) then
        return false
    end

    local action, item = parse_temporary_item(clean)
    if not action or not item then
        return false
    end

    local zone, kind, sector, number = parse_limbus_temp_item(item)
    if zone ~= active_zone or not kind then
        return false
    end

    local obtained = action == 'Obtained temporary item'
    if not obtained then
        return false
    end

    if record_temp_item(zone, kind, sector, number, obtained) then
        debug_log(('matched %s from %s: %s'):format(action, source, item:gsub('%.$', '')))
    end
    return true
end

local function is_bonus_shard_item(item)
    if not item then
        return false
    end

    return item:gsub('%.$', ''):lower():match('^shard of ') ~= nil
end

local function handle_bonus_shard_lines(lines, source)
    local shard_count = 0
    for _, line in ipairs(lines) do
        if line ~= '' and not ignore_self(line) then
            local item = parse_obtained_item(line)
            if is_bonus_shard_item(item) then
                shard_count = shard_count + 1
            end
        end
    end

    if shard_count < 2 then
        return false
    end

    debug_log(('matched bonus shard pair from %s: %d shards'):format(
        tostring(source),
        shard_count
    ))
    record_reward_from_text(BONUS_AMT, source..' shard pair')
    return true
end

local function handle_incoming_limbus_text(text, source)
    if not text or text == '' or not active_zone then
        return
    end

    local lines = normalize_chat_lines(text)
    for _, line in ipairs(lines) do
        if line:match('Acquired%s+%w+%s+Units:') then
            debug_log(('reward text candidate from %s: %s'):format(tostring(source), line))
        elseif line:match('Total%s+%w+%s+Units:') then
            debug_log(('units total candidate from %s: %s'):format(tostring(source), line))
        elseif line:match('%w+%s+Operator%s*:') and line:match('collect%s+data') then
            debug_log(('climb count candidate from %s: %s'):format(tostring(source), line))
        end
        handle_units_total_line(line, source)
        handle_climb_remaining_line(line, source)
        handle_temp_item_line(line, source)
        handle_reward_line(line, source)
    end
    handle_bonus_shard_lines(lines, source)
end

-----------------------------------------------------------
-- Packet
-----------------------------------------------------------

function request_update()
    if not windower.ffxi.get_info().logged_in then
        return
    end

    for _, packet in pairs(requests) do
        packets.inject(packet)
    end
end

local function schedule_temp_refresh()
    if not zone_data_numbers[active_zone] then
        return
    end

    refresh_temp_items()
    coroutine.schedule(refresh_temp_items, 1)
    coroutine.schedule(refresh_temp_items, 10)
end

local function schedule_hud_refresh()
    coroutine.schedule(update_text_box, 0.25)
end

windower.register_event('incoming chunk', function(id, data)
    if zone_data_numbers[active_zone] and id == 0x01D then
        schedule_temp_refresh()
        schedule_hud_refresh()
    end

    if zone_data_numbers[active_zone] and (id == 0x01E or id == 0x01F or id == 0x020) then
        coroutine.schedule(refresh_temp_items, 0.5)
        schedule_hud_refresh()
    end

    if id == 0x02D then
        local zone = windower.ffxi.get_info().zone
        if is_limbus_zone(zone) then
            counter = counter + 1
            if counter % refresh_rate == 0 then
                coroutine.schedule(request_update, refresh_delay)
                schedule_hud_refresh()
            end
        end
        return
    end

    if active_zone and pending_chest_open_active() and reward_packet_ids[id] then
        local packet = packets.parse('incoming', data)
        if packet then
            local amount, field = packet_reward_amount(packet)
            if amount then
                queue_detected_reward(amount, ('incoming 0x%03X %s'):format(id, tostring(field)))
                return
            end
        end
    end

    if id == 0x020 and active_zone and pending_chest_open_active() then
        local packet = packets.parse('incoming', data)
        if not packet then return end

        if is_real_item_update(packet.Item, packet.Count) then
            request_update()
            schedule_pending_chest_open_resolution()
        end
        return
    end

    if id ~= 0x118 then return end

    local packet = packets.parse('incoming', data)
    if not packet then return end

    local updated = false
    for field in unit_fields:it() do
        local value = packet[field]
        if type(value) == 'number' and current_units[field] ~= value then
            current_units[field] = value
            updated = true
        end
    end

    if updated or not display_initialized then
        update_text_box()
        display_initialized = true
    end
end)

windower.register_event('outgoing chunk', function(id, original, modified, injected, blocked)
    if blocked or injected or not active_zone or id ~= 0x01A then
        return
    end

    local packet = packets.parse('outgoing', modified or original)
    if not packet then
        return
    end

    debug_log(('outgoing action: category=%s target=%s target_index=%s'):format(
        tostring(packet.Category),
        tostring(packet.Target),
        tostring(packet['Target Index'])
    ))

    local sector = target_chest_sector(packet.Target)
    if not sector then
        local category = packet.Category
        if category ~= 'NPC Interaction' and category ~= 0x00 then
            return
        end
        sector = target_nearest_sector(packet.Target, REWARD_TEXT_DIST)
        if sector then
            debug_log(('using relaxed target sector fallback: %s %s target=%s'):format(
                zone_name[active_zone],
                sector,
                tostring(packet.Target)
            ))
        end
    end

    if not sector then
        sector = current_chest_sector()
    end

    if sector then
        local now = os.clock()
        if last_action.target == packet.Target
            and last_action.sector == sector
            and (now - last_action.timestamp) < 1 then
            return
        end

        last_action.target = packet.Target
        last_action.sector = sector
        last_action.timestamp = now
        remember_recent_chest()
        mark_pending_chest_open(sector)
        coroutine.schedule(request_update, 0.5)
        coroutine.schedule(request_update, 1.5)
        debug_log(('pending chest open at %s %s via action target %s'):format(
            zone_name[active_zone],
            sector,
            tostring(packet.Target)
        ))
    end
end)

windower.register_event('prerender', function()
    if active_zone then
        remember_recent_chest()
        remember_recent_reward_sector()
    end
end)

windower.register_event('incoming text', function(original, modified, _, _, blocked)
    if not active_zone then
        return
    end

    if original and original ~= '' then
        handle_incoming_limbus_text(original, 'incoming text original')
    end

    if modified and modified ~= '' and modified ~= original then
        handle_incoming_limbus_text(modified, 'incoming text modified')
    end
end)

windower.register_event('chat message', function(message)
    if not active_zone then
        return
    end

    handle_incoming_limbus_text(message, 'chat message')
end)

-----------------------------------------------------------
-- Zone Change
-----------------------------------------------------------

windower.register_event('zone change', function(zone)
    local previous_zone = active_zone
    counter = 0
    display_initialized = false
    clear_recent_chest()
    clear_recent_reward_sector()
    clear_recent_chest_open()
    clear_pending_chest_open()
    clear_pending_reward()
    clear_last_action()

    if is_limbus_zone(zone) then
        active_zone = zone
        load_state()
        schedule_weekly_reset_check()
        debug_log(('entered %s with Units v%s.'):format(zone_name[zone], _addon.version))
        request_update()
        schedule_temp_refresh()
        update_text_box()
    else
        if previous_zone then
            debug_log('left '..zone_name[previous_zone]..'.')
        end
        active_zone = nil
        text_box:visible(false)
    end
end)

-----------------------------------------------------------
-- Load / Login / Logout
-----------------------------------------------------------

windower.register_event('load', function()
    local info = windower.ffxi.get_info()
    if info.logged_in then
        local player = windower.ffxi.get_player()
        player_name = player and player.name or nil
        init_player_state()
        local zone = info.zone
        active_zone = is_limbus_zone(zone) and zone or nil
        load_state()
        schedule_weekly_reset_check()
        if is_limbus_zone(zone) then
            debug_log(('loaded in %s with Units v%s.'):format(zone_name[zone], _addon.version))
            request_update()
            schedule_temp_refresh()
            update_text_box()
        else
            active_zone = nil
            text_box:visible(false)
        end
    end
end)

windower.register_event('login', function(name)
    player_name = name
    unload_character_state()
    init_player_state()
    local zone = windower.ffxi.get_info().zone
    active_zone = is_limbus_zone(zone) and zone or nil
    load_state()
    schedule_weekly_reset_check()
    if is_limbus_zone(zone) then
        debug_log(('logged into %s with Units v%s.'):format(zone_name[zone], _addon.version))
        request_update()
        schedule_temp_refresh()
        update_text_box()
    else
        active_zone = nil
        text_box:visible(false)
    end
end)

windower.register_event('logout', function()
    text_box:visible(false)
    current_units['Apollyon Units'] = 0
    current_units['Temenos Units'] = 0
    display_initialized = false
    hud_hidden = false
    active_zone = nil
    clear_recent_chest()
    clear_recent_reward_sector()
    clear_recent_chest_open()
    clear_pending_chest_open()
    clear_pending_reward()
    clear_last_action()
    unload_character_state()
end)

-----------------------------------------------------------
-- Addon Commands
-----------------------------------------------------------

require('modules.commands').register({
    version = _addon.version,
    zone_name = zone_name,
    zone_sectors = zone_sectors,
    tracking = tracking,

    get_active_zone = function()
        return active_zone
    end,

    show_hud = function()
        hud_hidden = false
        update_text_box()
    end,

    hide_hud = function()
        hud_hidden = true
        text_box:visible(false)
    end,

    save_state = save_state,
    update_text_box = update_text_box,
    detect_sector = detect_sector,
    detected_reward_sector = detected_reward_sector,
    player_near_chest = player_near_chest,

    set_debug_enabled = function(value)
        debug_enabled = value
    end,

    is_debug_enabled = function()
        return debug_enabled
    end,
})
