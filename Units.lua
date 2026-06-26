_addon.name = 'Units'
_addon.author = 'Meliora'
_addon.version = '0.3.3'
_addon.commands = {'units'}

require('lists')
require('logger')
require('coroutine')

packets = require('packets')
texts = require('texts')
config = require('config')
res = require('resources')

require('modules.core')
