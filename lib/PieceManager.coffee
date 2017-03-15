crypto = require 'crypto'
EventEmiter = require 'events'

Piece = require './Piece'

logger = require 'debug'

# Manager for pieces.
#
# @extend EventEmiter
class PieceManager extends EventEmiter
  # @property [Object<String, Piece>] pieces storage for pieces indexed by piece hash (Object<pieceHash, piece>).
  pieces: null

  # Create a piece manager instance.
  constructor: ->
    super()

    # pieces[hash] => Piece
    @pieces = {}

  # Prepare a new piece or reuse an existing piece.
  #
  # @param [Piece] hash hash of the piece gets prepared.
  prepare: (hash) -> @pieces[hash] ?= new Piece hash

  # Write a buffer to the current piece data model.
  #
  # @param [Buffer] buffer buffer of the new piece data.
  # @param [String] from source of the buffer, used for logging.
  write: (buffer, from = 'unknown') ->
    # hash it before write
    hash = crypto.createHash('sha256').update(buffer).digest 'hex'
    return unless (piece = @pieces[hash])?

    @info "-- write piece[hash=#{hash}] from #{from}"
    piece.write buffer

  # Get a piece from the storage.
  #
  # @param [String] hash hash value for the piece
  get: (hash) -> @pieces[hash]

  info: logger 'PieceManager:info'

exports = module.exports = PieceManager
