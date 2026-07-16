local constants = require('modules.constants')

local hud = {}
local WARNING_COLOR = '\\cs(255,80,80)'
local SUCCESS_COLOR = '\\cs(120,255,120)'
local RESET_COLOR = '\\cr'

local function warning_lines(context)
    local warning = context.bonus_warning or {}

    if warning.bonus_chest_may_be_lost then
        return {
            '!! Bonus chest may be lost !!',
            '!! Less than 10 inventory slots free !!',
            '!! Clear space before zoning !!',
            '!! Items arrive as slots open !!',
        }
    elseif warning.near_cap then
        return {
            '!! Limbus Units almost capped !!',
            '!! Bonus chest may cap you !!',
        }
    elseif warning.unit_capped then
        return {
            '!! Limbus Units is at max amount !!',
            '!! Unit rewards will be wasted !!',
        }
    elseif warning.inventory_near_full then
        return {
            '!! Inventory nearly full !!',
            '!! Less than 10 inventory slots free !!',
            '!! Clear space before zoning !!',
            '!! Items drop as space is freed up !!',
        }
    end

    return nil
end

local function comma_value(n)
    local left, num, right = string.match(n, '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

local function format_value(value)
    local str = tostring(value or 0)
    if #str <= 3 then
        return str
    end
    return comma_value(str)
end

local function format_units_display(field, current_units, unit_caps)
    local current = tonumber(current_units[field]) or 0
    local max = tonumber(unit_caps[field]) or 0
    if max <= 0 then
        return format_value(current)
    end
    if current >= max then
        return WARNING_COLOR .. format_value(current)..' - 100%'..RESET_COLOR
    end
    return ('%s - %.1f%%'):format(format_value(current), (current / max) * 100)
end

local function format_short_units_display(field, current_units, unit_caps)
    local current = tonumber(current_units[field]) or 0
    local max = tonumber(unit_caps[field]) or 0
    if max <= 0 then
        return format_value(current)
    end
    if current >= max then
        return WARNING_COLOR .. format_value(current)..' 100%'..RESET_COLOR
    end
    return ('%s %.1f%%'):format(format_value(current), (current / max) * 100)
end

local function format_obtained(value)
    return value and constants.CHECKED or constants.UNCHECKED
end

local function format_climb_display(active_zone, climb_remaining)
    if type(climb_remaining) ~= 'table' then
        return nil
    end

    local remaining = tonumber(climb_remaining[active_zone])
    if not remaining or remaining < 0 then
        return nil
    end

    local current = constants.CLIMB_LIMIT - remaining
    if current < 0 then
        current = 0
    elseif current > constants.CLIMB_LIMIT then
        current = constants.CLIMB_LIMIT
    end

    return ('Climb %d/%d'):format(current, constants.CLIMB_LIMIT)
end

local function format_data_line(active_zone, limbus_temp_items, sector)
    local data = limbus_temp_items[active_zone].data[sector]
    local sector_complete = true
    local values = {}
    for _, number in ipairs(constants.zone_data_numbers[active_zone][sector]) do
        local obtained = data[number]
        if not obtained then
            sector_complete = false
        end
        values[#values + 1] = obtained and constants.CHECKED or constants.UNCHECKED
    end

    if sector_complete then
        return ('%s data:  %sDONE%s'):format(
            sector,
            SUCCESS_COLOR,
            RESET_COLOR
        )
    end

    return ('%s data:  %s'):format(sector, table.concat(values, ' '))
end

local function all_data_collected(active_zone, limbus_temp_items)
    for _, sector in ipairs(constants.zone_sectors[active_zone]) do
        for _, number in ipairs(constants.zone_data_numbers[active_zone][sector]) do
            if not limbus_temp_items[active_zone].data[sector][number] then
                return false
            end
        end
    end

    return true
end

local function chest_status_text(state)
    return state == 'std' and 'Normal' or 'Possible Bonus'
end

local function bonus_chance(active_zone, tracking)
    local possible = 0
    for _, sector in ipairs(constants.zone_sectors[active_zone]) do
        if tracking[active_zone][sector] ~= 'std' then
            possible = possible + 1
        end
    end

    local chances = {
        [1] = '100%',
        [2] = '50%',
        [3] = '33%',
        [4] = '25%',
    }
    return chances[possible] or 'Unknown'
end

local function last_bonus_text(active_zone, last_bonus)
    return last_bonus[active_zone] or 'Unknown'
end

local function short_unit_label(field)
    if field == 'Apollyon Units' then
        return 'Apollyon'
    elseif field == 'Temenos Units' then
        return 'Temenos'
    end
    return field
end

local function update_minimal(context)
    local active_zone = context.active_zone
    local parts = {}
    local unit_parts = {}

    for field in context.unit_fields:it() do
        unit_parts[#unit_parts+1] = ('%s: %s'):format(
            short_unit_label(field),
            format_short_units_display(field, context.current_units, context.unit_caps)
        )
    end
    parts[#parts+1] = table.concat(unit_parts, ' ')

    local chest_parts = {}
    for _, s in ipairs(constants.zone_sectors[active_zone]) do
        chest_parts[#chest_parts+1] = ('%s: %s'):format(s, chest_status_text(context.tracking[active_zone][s]))
    end
    parts[#parts+1] = 'Chest status: '..table.concat(chest_parts, ' ')
    parts[#parts+1] = 'Bonus Chance: '..bonus_chance(active_zone, context.tracking)
    parts[#parts+1] = 'Last Bonus: '..last_bonus_text(active_zone, context.last_bonus)

    context.text_box:text(table.concat(parts, ' | '))
end

local function update_full(context)
    local active_zone = context.active_zone
    local text_box = context.text_box
    local lines = {}
    local header = 'Limbus Units'
    local separator = string.rep('-', math.max(constants.HUD_WIDTH, #header))

    lines[#lines+1] = header
    lines[#lines+1] = separator
    for field in context.unit_fields:it() do
        lines[#lines+1] = ('%s: [%s]'):format(field, format_units_display(field, context.current_units, context.unit_caps))
    end

    local warning = warning_lines(context)
    if warning then
        lines[#lines+1] = ''
        for _, line in ipairs(warning) do
            lines[#lines+1] = WARNING_COLOR..line..RESET_COLOR
        end
    end

    lines[#lines+1] = ''
    lines[#lines+1] = constants.zone_name[active_zone]..' Chests'
    lines[#lines+1] = separator
    for _, s in ipairs(constants.zone_sectors[active_zone]) do
        local st = context.tracking[active_zone][s]
        local tag = chest_status_text(st)
        local label = s..string.rep(' ', 3 - #s)
        lines[#lines+1] = ('%s: %s'):format(label, tag)
    end
    lines[#lines+1] = ''
    lines[#lines+1] = 'Bonus Chance: '..bonus_chance(active_zone, context.tracking)
    lines[#lines+1] = 'Last Bonus: '..last_bonus_text(active_zone, context.last_bonus)

    if constants.zone_data_numbers[active_zone] then
        lines[#lines+1] = ''
        lines[#lines+1] = constants.zone_name[active_zone]..' Data'
        lines[#lines+1] = separator
        local climb_display = format_climb_display(active_zone, context.climb_remaining)
        if climb_display then
            lines[#lines+1] = climb_display
        end
        lines[#lines+1] = ('Code: %s'):format(format_obtained(context.limbus_temp_items[active_zone].code))
        if all_data_collected(active_zone, context.limbus_temp_items) then
            lines[#lines+1] = SUCCESS_COLOR..'Collected all '..constants.zone_name[active_zone]..' data!'..RESET_COLOR
            lines[#lines+1] = SUCCESS_COLOR..'Open a chest to reset'..RESET_COLOR
        else
            for _, s in ipairs(constants.zone_sectors[active_zone]) do
                lines[#lines+1] = format_data_line(active_zone, context.limbus_temp_items, s)
            end
        end
    end

    text_box:text(table.concat(lines, '\n'))
end

function hud.update(context)
    local active_zone = context.active_zone
    local text_box = context.text_box

    if not constants.is_limbus_zone(active_zone) then
        text_box:visible(false)
        return
    end

    if context.hud_layout == 'minimal' then
        update_minimal(context)
    else
        update_full(context)
    end

    text_box:visible(not context.hud_hidden and constants.is_limbus_zone(active_zone))
end

return hud
