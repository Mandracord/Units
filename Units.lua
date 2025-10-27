_addon.name = 'Units'
_addon.author = 'Meliora'
_addon.version = '1.1.1'
_addon.commands = {'units'}

-----------------------------------------------------------
-- Imports
-----------------------------------------------------------
require('lists')
require('logger')
packets = require('packets')
texts = require('texts')
config = require('config')

-----------------------------------------------------------
-- Default Settings
-----------------------------------------------------------

local default_settings = {
    pos = {
        x = 450,
        y = 30
    },
    flags = {
        bold = true,
        draggable = true
    },
    padding = 5,
    text = {
        font = 'Consolas',
        size = 11,
        bold = true,
        stroke = {
            alpha = 255,
            blue = 0,
            red = 0,
            green = 0,
            width = 1
        }
    },
    bg = {
        visible = true,
        alpha = 110
    }
}

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
local last_values = {
    ['Apollyon Units'] = 0,
    ['Temenos Units'] = 0
}
local display_initialized = false
local tracked_fields = L {'Apollyon Units', 'Temenos Units'}
local requests = {
    [0x118] = packets.new('outgoing', 0x115)
}

-----------------------------------------------------------
-- Helper And Format Functions
-----------------------------------------------------------

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

-----------------------------------------------------------
--               ! ! DO NOT EDIT BELOW ! !
-----------------------------------------------------------

local function update_text_box()
    local header = ('Apollyon & Temenos Units')
    local separator = string.rep('-', #header)
    local lines = { header, separator }

    for field in tracked_fields:it() do
        local value = last_values[field] or 0
        lines[#lines + 1] = ('%s: [%s]'):format(field, format_value(value))
    end

    local body = table.concat(lines, '\n')
    text_box:text(body)
    if not hud_hidden then
        text_box:visible(true)
    end
end

local function request_update()
    if not windower.ffxi.get_info().logged_in then
        return
    end

    for _, packet in pairs(requests) do
        packets.inject(packet)
    end

    if text_box:visible(true) then 
        text_box:visible(false)
    end
end

windower.register_event('incoming chunk', function(id, data)
    if id == 0x02D then
        local zone = windower.ffxi.get_info().zone
        if zone == 37 or zone == 38 then
            counter = counter + 1
            if counter % refresh_rate == 0 then
                coroutine.schedule(request_update, refresh_delay)
            end
        end
        return
    end

    if id ~= 0x118 then
        return
    end

    local packet = packets.parse('incoming', data)
    if not packet then
        return
    end

    local updated = false
    for field in tracked_fields:it() do
        local value = packet[field]
        if type(value) == 'number' and last_values[field] ~= value then
            last_values[field] = value
            updated = true
        end
    end

    if updated or not display_initialized then
        update_text_box()
        display_initialized = true
    end
end)


windower.register_event('load', function()
    local info = windower.ffxi.get_info()
    if info.logged_in then
        local player = windower.ffxi.get_player()
        player_name = player and player.name or nil
        request_update()
    end
end)

windower.register_event('login', function(name)
    player_name = name
    request_update()
end)

windower.register_event('logout', function()
    text_box:visible(false)
    last_values['Apollyon Units'] = 0
    last_values['Temenos Units'] = 0
    display_initialized = false
    hud_hidden = false
end)

windower.register_event('zone change', function(zone)
    counter = 0
    if zone == 37 or zone == 38 then -- Only display inside Limbus (Apollyon & Temenos)
        request_update()
        if not hud_hidden then
            update_text_box()
        end
    else
        text_box:visible(false)
    end
end)

windower.register_event('addon command', function(cmd, ...)
    cmd = cmd and cmd:lower() or 'help'

    if cmd == 'help' then
        log('Commands: //units show | hide')
        return
    elseif cmd == 'show' then
        hud_hidden = false
        update_text_box()
        return
    elseif cmd == 'hide' then
        hud_hidden = true
        text_box:visible(false)
        return
    end

    log('Unknown command. Use //units help for a list of commands.')
end)
