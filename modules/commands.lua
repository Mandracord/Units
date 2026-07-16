local commands = {}

function commands.register(context)
    windower.register_event('addon command', function(cmd, ...)
        local args = {...}
        cmd = cmd and cmd:lower() or 'help'

        if cmd == 'help' then
            log('Units v'..context.version)
            log('  //units show                  - Show the HUD')
            log('  //units hide                  - Hide the HUD')
            log('  //units mini                  - Use the minimal HUD')
            log('  //units full                  - Use the full HUD')
            log('  //units sector <sector>       - Mark a sector Normal manually')
            log('    Apollyon: NW NE SW SE')
            log('    Temenos:  N  W  E  C')
            log('  //units pos                   - Print position and detected sector')
            log('  //units debug on|off          - Toggle debug chat output')
            return

        elseif cmd == 'show' then
            context.show_hud()
            return

        elseif cmd == 'hide' then
            context.hide_hud()
            return

        elseif cmd == 'mini' then
            context.set_hud_layout('minimal')
            log('HUD layout set to mini.')
            return

        elseif cmd == 'full' then
            context.set_hud_layout('full')
            log('HUD layout set to full.')
            return

        elseif cmd == 'layout' then
            local value = (args[1] or ''):lower()
            if value == 'full' or value == 'minimal' then
                context.set_hud_layout(value)
                log('HUD layout set to '..context.get_hud_layout()..'.')
            else
                log('Current HUD layout: '..context.get_hud_layout())
                log('Usage: //units layout full|minimal')
            end
            return

        elseif cmd == 'sector' then
            local active_zone = context.get_active_zone()
            local s = (args[1] or ''):upper()
            if not active_zone then
                log('Not currently in Apollyon or Temenos.')
                return
            end

            local valid = false
            for _, v in ipairs(context.zone_sectors[active_zone]) do
                if v == s then valid = true ; break end
            end
            if not valid then
                log('Valid sectors for '..context.zone_name[active_zone]..': '..table.concat(context.zone_sectors[active_zone], ' '))
                return
            end

            if context.tracking[active_zone][s] == nil then
                context.tracking[active_zone][s] = 'std'
                context.save_state()
                log(context.zone_name[active_zone]..' '..s..' marked Normal.')
            else
                log(context.zone_name[active_zone]..' '..s..' is already marked Normal.')
            end
            context.update_text_box()
            return

        elseif cmd == 'pos' then
            local me = windower.ffxi.get_mob_by_target('me')
            if me then
                log(('Position  x=%.2f  y=%.2f  z=%.2f'):format(me.x, me.y, me.z))
                log('Detected sector: '..(context.detect_sector() or 'unknown'))
                log('Reward sector: '..(context.detected_reward_sector() or 'unknown'))
                log('Near chest: '..tostring(context.player_near_chest()))
            else
                log('Cannot read player position.')
            end
            return

        elseif cmd == 'debug' then
            local value = (args[1] or ''):lower()
            if value == 'on' then
                context.set_debug_enabled(true)
            elseif value == 'off' then
                context.set_debug_enabled(false)
            else
                log('Usage: //units debug on|off')
                return
            end
            log('Debug output '..(context.is_debug_enabled() and 'enabled' or 'disabled')..'.')
            return
        end

        log('Unknown command. Use //units help for a list of commands.')
    end)
end

return commands
