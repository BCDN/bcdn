Resource = require './Resource'

logger = require 'debug'

exports = module.exports = class ResourceManager
  debug: logger 'ResourceManager:debug'

  constructor: ->
    # hash => resource
    @resources = {}

  updateIndex: (indexes) ->
    resource = new Resource()
    resource.deserialize indexes

    @resources[resource.hash] = resource
    @debug "update resource index (hash=#{resource.hash}," +
           "pieces=[#{resource.pieces[0..2]}," +
           "(length=#{resource.pieces.length})...])"

  get: (hash) -> @resources[hash]
