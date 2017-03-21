EventEmiter = require 'events'

# Peer data model.
#
# @extend EventEmiter
class Peer extends EventEmiter
  # @property [String] connection key of this peer.
  key: null
  # @property [String] full peer ID (with leading tracker ID).
  id: null
  # @property [String] token provided by this peer.
  token: null

  # Construct a Peer object from its properties.
  #
  # @param [Object] properties properties of this peer.
  constructor: (properties) ->
    super()
    {@key, @id, @token} = properties

exports = module.exports = Peer
