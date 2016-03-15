Serializable = require './Serializable'

exports = module.exports = class Contents extends Serializable
  constructor: ->
    @timestamp = 0
    @resources = {} # path => {size, hash}



  deserialize: (data, cb) ->
    {timestamp, resources} = super data

    # update resources
    for path, newRes of resources
      unless (oldRes = @resources[path])? and (oldRes.hash == newRes.hash)
        @resources[path] = newRes
        cb path, oldRes, newRes

    # update timestamp
    @timestamp = timestamp



  serialize: ->
    super timestamp: @timestamp, resources: @resources
