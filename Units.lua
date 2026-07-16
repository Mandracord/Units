_addon.name = 'Units'
_addon.author = 'Meliora'
_addon.version = '0.3.4'
_addon.commands = {'units'}

packets = require('packets')
texts = require('texts')
config = require('config')
res = require('resources')

require('lists')
require('logger')
require('coroutine')


require('modules.core')