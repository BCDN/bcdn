EventEmiter = require 'events'

logger = require 'debug'

# Piece data model.
#
# @extend EventEmiter
class Piece extends EventEmiter
  # @property [String] hash value for this piece.
  hash: null
  # @property [Buffer] buffer contains binary data of this piece.
  data: null

  # Construct a empty Piece object with its hash value.
  #
  # @param [String] hash hash value of the piece.
  constructor: (@hash) -> super()

  # Write the piece data after verified.
  #
  # @param [Buffer] data buffer contains binary data to be written.
  write: (data) ->
    # don't write it if already written.
    return if @data?

    @debug "-- writing data for #{@hash}"

    # write data if not yet be written.
    @data = data

    # and emit the `write` event.
    @emit 'write'

  debug: logger 'Piece:debug'

exports = module.exports = Piece
