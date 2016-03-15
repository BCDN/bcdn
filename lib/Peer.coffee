EventEmiter = require 'events'

exports = module.exports = class Peer extends EventEmiter
  constructor: (@key, @id, @token = null) ->
    super()
