Serializable = require './Serializable'

# Contents data model.
#
# @extend Serializable
class Contents extends Serializable
  # @property [Number] timestamp of contents update time.
  timestamp: 0
  # @property [Object<String, Object>] list of all resource records (with its size and hash value) indexed by its path.
  resources: null

  # Override {Serializable#deserialize}.
  #
  # @param [String] data string of serialized contents object.
  # @param [Function] callback callback function gets invoked for each changed resources.
  # @option callback [String] path path of the changed resource.
  # @option callback [String] oldRes record for old resource.
  # @option callback [String] newRes record for new resource.
  deserialize: (data, callback) ->
    {timestamp, resources} = super data

    # update resources
    @resources ?= {}
    for path, newRes of resources
      unless (oldRes = @resources[path])? and (oldRes.hash == newRes.hash)
        @resources[path] = newRes
        callback path, oldRes, newRes

    # update timestamp
    @timestamp = timestamp

  # Override {Serializable#serialize}.
  #
  # @return [String] see {Serializable#serialize}.
  serialize: ->
    super timestamp: @timestamp, resources: @resources

exports = module.exports = Contents
