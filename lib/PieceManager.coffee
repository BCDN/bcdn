crypto = require 'crypto'
EventEmiter = require 'events'

Piece = require './Piece'

logger = require 'debug'

exports = module.exports = class PieceManager extends EventEmiter
  debug: logger 'PieceManager:debug'

  constructor: ->
    super()

    # pieces[hash] => Piece
    @pieces = {}

  prepare: (hash) => @pieces[hash] ?= new Piece hash

  write: (buffer) =>
    # hash it before write
    hash = crypto.createHash('sha256').update(buffer).digest 'hex'
    return unless (piece = @pieces[hash])?

    @debug "write piece #{hash}"
    piece.write buffer
