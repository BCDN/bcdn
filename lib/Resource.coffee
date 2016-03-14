EventEmiter = require 'events'

Serializable = require './Serializable'
mix = require './mix'

exports = module.exports = class Resource extends mix EventEmiter, Serializable
  pieces: null

  constructor: (@hash) ->
    super()

  deserialize: (data) ->
    {@hash, @pieces} = super data

  serialize: ->
    super hash: @hash, pieces: @pieces
