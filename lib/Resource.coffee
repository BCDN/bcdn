Serializable = require './Serializable'

# Resource data model.
#
# @extend Serializable
class Resource extends Serializable
  # @property [String] hash value for this resource.
  hash: null
  # @property [Array<String>] list of hash values for pieces of this resource.
  pieces: null

  # Construct a empty Resource object with its hash value.
  #
  # @param [String] hash hash value of the resource.
  constructor: (@hash) -> super()

  # Override {Serializable#deserialize}.
  #
  # @param [String] see {Serializable#deserialize}.
  deserialize: (data) ->
    {@hash, @pieces} = super data

  # Override {Serializable#serialize}.
  #
  # @return [String] see {Serializable#serialize}.
  serialize: ->
    super hash: @hash, pieces: @pieces

exports = module.exports = Resource
