EventEmiter = require 'events'

PeerConnection = require './PeerConnection'

logger = require 'debug'

# Manager for peer connections.
class PeerManager extends EventEmiter
  # @property [WRTC] wrtc instance for headless testing.
  wrtc: null
  # @property [Object<String, PeerConnection>] peer connections indexed by peer ID.
  peers: {}

  # Create a peer manager instance.
  #
  # @param [Object<String, ?>] options options from {BCDNPeer} for initialize this peer manager.
  constructor: (options) ->
    {@wrtc} = options

  # Accept an incoming connection.
  #
  # @param [String] id peer ID of incoming connection.
  # @return [PeerConnection] the connection instance (reuse if a connection was established, create otherwise).
  accept: (id) ->
    # for created peers
    return peerConn if (peerConn = @peers[id])?

    @info "accpet connect to #{id}..."
    return @peers[id] = @create id, false

  # Attempt to connect another peer.
  #
  # @param [String] id peer ID of the peer attempt to connect.
  # @return [PeerConnection] the connection instance (reuse if a connection was established, create otherwise).
  connect: (id) ->
    # for connected peers
    return peerConn if (peerConn = @peers[id])?

    @info "connect to #{id}..."
    return @peers[id] = @create id, true

  # Create a connection instance.
  #
  # @param [String] id peer ID of the partner.
  # @param [Boolean] initiator true if this peer initiate the connection.
  # @return [PeerConnection] the connection instance.
  create: (id, initiator) ->
    @debug "create connection for #{id} (initiator=#{initiator})"
    if initiator
      peerConn = new PeerConnection id, initiator: true, wrtc: @wrtc
    else
      peerConn = new PeerConnection id, wrtc: @wrtc

    do (peerConn) =>
      peerConn.on 'SIGNAL', (data) =>
        @info "ready to signal #{peerConn.id}"
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
        @info "got piece from #{peerConn.id}"
        @emit 'piece', peerConn, data
      peerConn.on 'NEXT', =>
        @verbose "ready to fetch next piece from #{peerConn.id}"
        @emit 'next', peerConn

  # Get existing connection by peer ID.
  #
  # @param [String] id peer ID.
  # @return [PeerConnection] the connection instance or undefined if not exist.
  get: (id) => @peers[id]

  # Delete an existing connection by peer ID.
  #
  # @param [String] id peer ID to be deleted.
  delete: (id) => delete @peers[id] if @peers[id]?

  verbose: logger 'PeerManager:verbose'
  debug: logger 'PeerManager:debug'
  info: logger 'PeerManager:info'

exports = module.exports = PeerManager
