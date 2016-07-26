EventEmiter = require 'events'

exports = module.exports = class Peer extends EventEmiter
  constructor: (properties) ->
    super()
    {@key, @id, @token} = properties
