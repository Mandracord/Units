local inventory = {}

local function inventory_info_from_result(result)
    if type(result) ~= 'table' then
        return nil
    end

    if type(result.count) == 'number' and type(result.max) == 'number' then
        return result
    end

    if type(result.inventory) == 'table' then
        return result.inventory
    end

    return nil
end

function inventory.is_main_inventory_near_full(free_slot_threshold)
    local threshold = tonumber(free_slot_threshold) or 0
    local info = inventory_info_from_result(windower.ffxi.get_bag_info(0))
    if not info then
        info = inventory_info_from_result(windower.ffxi.get_bag_info())
    end
    if not info or info.enabled == false then
        return false
    end

    return type(info.count) == 'number'
        and type(info.max) == 'number'
        and info.max > 0
        and (info.max - info.count) < threshold
end

return inventory
