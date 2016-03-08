_ = require 'lodash/core'

Serializable = require './Serializable'

exports = module.exports = class Contents extends Serializable
  constructor: ->
    @timestamp = 0
    @resources = {} # path => {size, hash, auto}



  deserialize: (data, cb) ->
    {timestamp, resources} = super data

    # update resources
    for path, newRes of resources
      oldRes = @resources[path]
      unless _.isEqual oldRes, newRes
        @resources[path] = newRes
        cb newRes.hash

    # update timestamp
    @timestamp = timestamp



  serialize: ->
    super timestamp: @timestamp, resources: @resources
