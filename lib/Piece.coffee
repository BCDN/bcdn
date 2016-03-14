EventEmiter = require 'events'

exports = module.exports = class Piece extends EventEmiter
  data: null

  constructor: (@hash) ->

  # write the piece data after verified
  verifyAndWrite: (data) ->
    return if @data?

    # TODO verify data integrity with hash and size

    # write data if everything is OK
    @data = data
