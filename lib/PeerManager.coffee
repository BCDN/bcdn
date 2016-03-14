EventEmiter = require 'events'

PeerConnection = require './PeerConnection'

logger = require 'debug'

exports = module.exports = class PeerManager extends EventEmiter
  verbose: logger 'PeerManager:verbose'
  debug: logger 'PeerManager:debug'
  info: logger 'PeerManager:info'

  peers: {}

  constructor: (@self, options) ->
    {@wrtc} = options

  processSignal: (detail) ->
    {from, signal} = detail
    @peers[from].signal signal

  accept: (id) ->
    # ignore self
    return null if id is @self.id
    # for connected peers
    return peerConn if (peerConn = @peers[id])?

    @info "accpet connect to #{id}..."
    return @peers[id] = @create id, false

  connect: (id) ->
    # ignore self
    return null if id is @self.id
    # for connected peers
    return peerConn if (peerConn = @peers[id])?

    @info "connect to #{id}..."
    return @peers[id] = @create id, true

  create: (id, initiator) ->
    @debug "create connection for #{id} (initiator=#{initiator})"
    if initiator
      peerConn = new PeerConnection id, initiator: true, wrtc: @wrtc
    else
      peerConn = new PeerConnection id, wrtc: @wrtc

    peerConn.on 'SIGNAL', (data) =>
      @verbose "ready to signal #{peerConn.id}"
      @emit 'signal', peerConn, data
    peerConn.on 'CONNECT', =>
      @debug "connected to #{peerConn.id}"
      @emit 'connect', peerConn
    peerConn.on 'HELLO', (data) =>
      @debug "got handshake from #{peerConn.id}"
      @emit 'handshake', peerConn, data
