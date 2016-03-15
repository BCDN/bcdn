EventEmiter = require 'events'

PeerConnection = require './PeerConnection'

logger = require 'debug'

exports = module.exports = class PeerManager extends EventEmiter
  verbose: logger 'PeerManager:verbose'
  debug: logger 'PeerManager:debug'
  info: logger 'PeerManager:info'

  constructor: (@self, options) ->
    {@wrtc} = options

    # peers[id] => PeerConenction
    @peers = {}

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

    do (peerConn) =>
      peerConn.on 'SIGNAL', (data) =>
        @verbose "ready to signal #{peerConn.id}"
        @emit 'signal', peerConn, data
      peerConn.on 'CONNECT', =>
        @info "connected to #{peerConn.id}"
        @emit 'connect', peerConn
      peerConn.on 'CLOSE', =>
        @info "peer #{peerConn.id} has closed the connection"
        @emit 'close', peerConn
      peerConn.on 'HELLO', (data) =>
        @debug "got handshake from #{peerConn.id}"
        @emit 'handshake', peerConn, data
      peerConn.on 'NOTIFY', (data) =>
        @verbose "got notify from #{peerConn.id}"
        @emit 'notify', peerConn, data
      peerConn.on 'DEMAND', (data) =>
        @verbose "got demand from #{peerConn.id}"
        @emit 'demand', peerConn, data
      peerConn.on 'LENGTH', (data) =>
        @verbose "got piece length from #{peerConn.id}"
        @emit 'length', peerConn, data
      peerConn.on 'PIECE', (data) =>
        @verbose "got piece from #{peerConn.id}"
        @emit 'piece', peerConn, data
      peerConn.on 'NEXT', =>
        @verbose "ready to fetch next piece from #{peerConn.id}"
        @emit 'next', peerConn

  get: (id) => @peers[id]
  delete: (id) => delete @peers[id] if @peers[id]?
