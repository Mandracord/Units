local constants = require('modules.constants')

local reward_packets = {}

function reward_packets.exact_chest_reward_amount(amount)
    if amount == constants.STANDARD_AMT or amount == constants.BONUS_AMT then
        return amount
    end
    return nil
end

function reward_packets.exact_chest_reward_text_amount(amount)
    return amount == constants.STANDARD_AMT or amount == constants.BONUS_AMT
end

function reward_packets.find_reward_amount_in_data(data)
    if type(data) ~= 'string' or #data < 4 then
        return nil
    end

    for i = 1, #data - 3 do
        local b1, b2, b3, b4 = data:byte(i, i + 3)
        local value = b1 + b2 * 0x100 + b3 * 0x10000 + b4 * 0x1000000
        local amount = reward_packets.exact_chest_reward_amount(value)
        if amount then
            return amount
        end
    end

    return nil
end

function reward_packets.packet_reward_amount(packet)
    if type(packet) ~= 'table' then
        return nil, nil
    end

    for field, value in pairs(packet) do
        local field_name = tostring(field)
        if field_name:match('^Param %d+$') then
            local amount = reward_packets.exact_chest_reward_amount(value)
            if amount then
                return amount, field_name
            end
        elseif field_name == 'Menu Parameters' then
            local amount = reward_packets.find_reward_amount_in_data(value)
            if amount then
                return amount, field_name
            end
        end
    end

    return nil, nil
end

return reward_packets
