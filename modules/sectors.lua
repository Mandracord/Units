local constants = require('modules.constants')

local sectors = {}

local function nearest_sector(x, y, z, chests)
    local best, best_d2 = nil, math.huge
    for sector, pos in pairs(chests) do
        local dx = x - pos.x
        local dy = y - pos.y
        local dz = z - pos.z
        local d2 = dx*dx + dy*dy + dz*dz
        if d2 < best_d2 then best_d2 = d2 ; best = sector end
    end
    return best, best_d2
end

function sectors.new(context)
    local recent_chest = {
        zone = nil,
        sector = nil,
        timestamp = 0,
    }
    local recent_reward_sector = {
        zone = nil,
        sector = nil,
        timestamp = 0,
    }

    local detector = {}

    function detector.clear_recent_chest()
        recent_chest.zone = nil
        recent_chest.sector = nil
        recent_chest.timestamp = 0
    end

    function detector.clear_recent_reward_sector()
        recent_reward_sector.zone = nil
        recent_reward_sector.sector = nil
        recent_reward_sector.timestamp = 0
    end

    function detector.current_chest_sector()
        local active_zone = context.get_active_zone()
        if not active_zone then return nil end
        local me = windower.ffxi.get_mob_by_target('me')
        if not me then return nil end
        local chests = active_zone == constants.APOLLYON and constants.APOLLYON_CHESTS or constants.TEMENOS_CHESTS
        local sector, d2 = nearest_sector(me.x, me.y, me.z, chests)
        if d2 <= constants.CHEST_DIST * constants.CHEST_DIST then
            return sector
        end
        return nil
    end

    function detector.current_nearest_sector(max_dist)
        local active_zone = context.get_active_zone()
        if not active_zone then return nil end
        local me = windower.ffxi.get_mob_by_target('me')
        if not me then return nil end
        local chests = active_zone == constants.APOLLYON and constants.APOLLYON_CHESTS or constants.TEMENOS_CHESTS
        local sector, d2 = nearest_sector(me.x, me.y, me.z, chests)
        if d2 <= max_dist * max_dist then
            return sector
        end
        return nil
    end

    function detector.target_chest_sector(target_id)
        local active_zone = context.get_active_zone()
        if not active_zone or not target_id then return nil end
        local mob = windower.ffxi.get_mob_by_id(target_id)
        if not mob then return nil end
        local chests = active_zone == constants.APOLLYON and constants.APOLLYON_CHESTS or constants.TEMENOS_CHESTS
        local sector, d2 = nearest_sector(mob.x, mob.y, mob.z, chests)
        context.debug_log(('target sector check: target=%s name=%s x=%.2f y=%.2f z=%.2f nearest=%s dist=%.2f'):format(
            tostring(target_id),
            tostring(mob.name),
            mob.x or 0,
            mob.y or 0,
            mob.z or 0,
            sector or 'unknown',
            math.sqrt(d2)
        ))
        if d2 <= constants.CHEST_DIST * constants.CHEST_DIST then
            return sector
        end
        return nil
    end

    function detector.target_nearest_sector(target_id, max_dist)
        local active_zone = context.get_active_zone()
        if not active_zone or not target_id then return nil end
        local mob = windower.ffxi.get_mob_by_id(target_id)
        if not mob then return nil end
        local chests = active_zone == constants.APOLLYON and constants.APOLLYON_CHESTS or constants.TEMENOS_CHESTS
        local sector, d2 = nearest_sector(mob.x, mob.y, mob.z, chests)
        if d2 <= max_dist * max_dist then
            return sector
        end
        return nil
    end

    function detector.remember_recent_chest()
        local active_zone = context.get_active_zone()
        local sector = detector.current_chest_sector()
        if sector then
            recent_chest.zone = active_zone
            recent_chest.sector = sector
            recent_chest.timestamp = os.time()
        end
        return sector
    end

    function detector.remember_recent_reward_sector()
        local active_zone = context.get_active_zone()
        local sector = detector.current_nearest_sector(constants.REWARD_TEXT_DIST)
        if sector then
            recent_reward_sector.zone = active_zone
            recent_reward_sector.sector = sector
            recent_reward_sector.timestamp = os.time()
        end
        return sector
    end

    function detector.detected_reward_sector()
        local active_zone = context.get_active_zone()
        local sector = detector.remember_recent_reward_sector()
        if sector then
            return sector
        end
        if recent_reward_sector.zone == active_zone
            and recent_reward_sector.sector
            and (os.time() - recent_reward_sector.timestamp) <= constants.CHEST_GRACE then
            return recent_reward_sector.sector
        end
        return nil
    end

    function detector.detect_sector()
        local active_zone = context.get_active_zone()
        local sector = detector.remember_recent_chest()
        if sector then
            return sector
        end
        if recent_chest.zone == active_zone
            and recent_chest.sector
            and (os.time() - recent_chest.timestamp) <= constants.CHEST_GRACE then
            return recent_chest.sector
        end
        return nil
    end

    function detector.player_near_chest()
        return detector.current_chest_sector() ~= nil
    end

    return detector
end

return sectors
