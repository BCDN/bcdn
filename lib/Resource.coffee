_ = require 'lodash/core'
Serializable = require './Serializable'
ResourceState = require './ResourceState'

exports = module.exports = class Resource extends Serializable
  constructor: (@hash, @size, @auto) ->
    @blob = null
    @uploadSize = 0
    @pieces = null
    @state = null

  # update resource from tracker node (note: only called once when preparing)
  prepare: (data) ->
    @pieces = @deserialize data

  # get blob for resource
  # TODO: check if update arraybuffer will update blob data
  getBlob: ->
    return @blob if @blob?

    if @state in [ResourceState.PREPARING, ResourceState.DOWNLOADING]
      return null

    pieces = [] # TODO: query resource manager for pieces

    @blob = new Blob pieces
