Serializable = require './Serializable'

exports = module.exports = class Contents extends Serializable
  constructor: ->
    @timestamp = 0
    @resources = {} # path => {hash, size, auto}



  # update contents from tracker node (note: might be called multiple times)
  update: (data) ->
    {_timestamp, _resources} = @deserialize data

    # update resources
    for path, newRes of _resources
      oldRes = @resources[path]
      unless _.isEqual oldHash, newHash
        @resources[path] = newRes
        # TODO: notify ResourceManager that resource requires update!

    # update timestamp
    @timestamp = _timestamp
