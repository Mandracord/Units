local constants = require('modules.constants')

local parsers = {}

local function clean_control_chars(text, separator)
    local clean = text.strip_format and text:strip_format() or text
    clean = clean:gsub('\7', separator)
    clean = clean:gsub('[\1-\8\11\12\14-\31]', ' ')
    return clean
end

function parsers.units_gain(text)
    if not text or text == '' then
        return nil
    end

    local clean = clean_control_chars(text, '\n')
    local zone, amount = clean:match('Acquired%s+(Apollyon)%s+Units:%s*([%d,]+)')
    if not zone then
        zone, amount = clean:match('Acquired%s+(Temenos)%s+Units:%s*([%d,]+)')
    end
    if not zone or not amount then
        return nil
    end

    return zone, tonumber((amount:gsub(',', '')), 10)
end

function parsers.zone_id_from_name(zone)
    if zone == 'Apollyon' then
        return constants.APOLLYON
    elseif zone == 'Temenos' then
        return constants.TEMENOS
    end
    return nil
end

function parsers.units_total(text)
    if not text or text == '' then
        return nil
    end

    local clean = clean_control_chars(text, '\n')
    local zone, current, cap = clean:match('Total%s+(Apollyon)%s+Units:%s*([%d,]+)%s*/%s*([%d,]+)')
    if not zone then
        zone, current, cap = clean:match('Total%s+(Temenos)%s+Units:%s*([%d,]+)%s*/%s*([%d,]+)')
    end
    if not zone or not current or not cap then
        return nil
    end

    return zone,
        tonumber((current:gsub(',', '')), 10),
        tonumber((cap:gsub(',', '')), 10)
end

function parsers.climb_remaining(text)
    if not text or text == '' then
        return nil
    end

    local clean = clean_control_chars(text, '\n')
    local zone, remaining = clean:match('^(Apollyon)%s+Operator%s*:%s*You%s+may%s+collect%s+data%s+([%d,]+)%s+more%s+times*%.?$')
    if not zone then
        zone, remaining = clean:match('^(Temenos)%s+Operator%s*:%s*You%s+may%s+collect%s+data%s+([%d,]+)%s+more%s+times*%.?$')
    end
    if not zone or not remaining then
        return nil
    end

    return zone, tonumber((remaining:gsub(',', '')), 10)
end

function parsers.obtained_item(text)
    if not text or text == '' then
        return nil
    end

    local clean = text.strip_format and text:strip_format() or text
    return clean:match('^Obtained:%s+(.+)%.?$')
end

function parsers.temporary_item(text)
    if not text or text == '' then
        return nil, nil
    end

    local clean = text.strip_format and text:strip_format() or text
    local action, item = clean:match('^(Obtained temporary item):%s+(.+)%.?$')
    if action and item then
        return action, item
    end
    return clean:match('^(Lost temporary item):%s+(.+)%.?$')
end

function parsers.limbus_temp_item(item)
    if not item then
        return nil
    end

    item = item:gsub('%.$', '')
    local lower = item:lower()
    if lower == 'apollyon code' then
        return constants.APOLLYON, 'code'
    elseif lower == 'temenos code' then
        return constants.TEMENOS, 'code'
    end

    local sector, number = item:match('^Apollyon%s+([NS][EW])%s+#([1-5])%s+data$')
    if not sector then
        sector, number = item:match('^Apollyon%s+([NS][EW])%s+#([1-5])$')
    end
    if sector and constants.zone_data_numbers[constants.APOLLYON][sector] and number then
        for _, valid_number in ipairs(constants.zone_data_numbers[constants.APOLLYON][sector]) do
            if valid_number == number then
                return constants.APOLLYON, 'data', sector, number
            end
        end
    end

    local tower, floor = item:match('^Temenos%s+(%a+)%s+tower%s+F([1-7])%s+data$')
    if not tower then
        tower, floor = item:match('^Tem%.%s+([NWEC])%-F([1-7])$')
    end

    local temenos_sector = {
        north = 'N',
        west = 'W',
        east = 'E',
        central = 'C',
        N = 'N',
        W = 'W',
        E = 'E',
        C = 'C',
    }
    sector = temenos_sector[tower]
    if sector and constants.zone_data_numbers[constants.TEMENOS][sector] and floor then
        for _, valid_number in ipairs(constants.zone_data_numbers[constants.TEMENOS][sector]) do
            if valid_number == floor then
                return constants.TEMENOS, 'data', sector, floor
            end
        end
    end

    return nil
end

function parsers.normalize_chat_lines(text)
    local clean = text.strip_format and text:strip_format() or text
    clean = clean:gsub('\r', '\n')
    clean = clean:gsub('\7', '\n')
    clean = clean:gsub('[\1-\8\11\12\14-\31]', '')

    local lines = {}
    for raw_line in clean:gmatch('[^\n]+') do
        local line = raw_line
            :gsub('^%[%d%d:%d%d:%d%d%]%s*', '')
            :gsub('^%s+', '')
            :gsub('%s+$', '')

        if line ~= '' then
            lines[#lines + 1] = line
        end
    end

    return lines
end

function parsers.ignore_self(text)
    return text:match('^Units Debug:') or text:match('^Units:')
end

return parsers
