Serializable = require './Serializable'
ResourceState = require './ResourceState'

exports = module.exports = class Resource extends Serializable
  constructor: (@hash = null) ->
    @blob = null
    @uploadSize = 0
    @pieces = null
    @state = null



  # get blob for resource
  # TODO: check if update arraybuffer will update blob data
  getBlob: ->
    return @blob if @blob?

    if @state in [ResourceState.PREPARING, ResourceState.DOWNLOADING]
      return null

    pieces = [] # TODO: query resource manager for pieces

    @blob = new Blob pieces



  deserialize: (data) ->
    {@hash, @pieces} = super data



  serialize: ->
    super hash: @hash, pieces: @pieces
