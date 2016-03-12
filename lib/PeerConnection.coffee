SimplePeer = require 'simple-peer'

logger = require 'debug'

exports = module.exports = class PeerConnection extends SimplePeer
  debug: logger 'PeerConnection:debug'
  info: logger 'PeerConnection:info'

  constructor: (id, options) ->
    @debug "Create PeerConnection for #{id}, initiator: #{!!options.initiator}"
    super options
