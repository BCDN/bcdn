EventEmiter = require 'events'

logger = require 'debug'

exports = module.exports = class Piece extends EventEmiter
  verbose: logger 'Piece:verbose'

  constructor: (@hash) ->
    super()

  # write the piece data after verified
  write: (data) ->
    return if @data?

    @verbose "write data for #{@hash}"
    # write data if everything is OK
    @data = data

    # and emit
    @emit 'write'
