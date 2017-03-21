EventEmiter = require 'events'

PeerConnection = require './PeerConnection'

logger = require 'debug'

# Manager for peer connections.
#
# @extend EventEmiter
class PeerManager extends EventEmiter
  # @property [WRTC] wrtc instance for headless testing.
  wrtc: null
  # @property [Object<String, PeerConnection>] peer connections indexed by peer ID (Object<peerId, peerConn>).
  peers: null

  # Create a peer manager instance.
  #
  # @param [Object<String, ?>] options options from {BCDNPeer} for initialize this peer manager.
  constructor: (options) ->
    {@wrtc} = options
    @peers = {}

  # Accept an incoming connection.
  #
  # @param [String] id peer ID of incoming connection.
  # @return [PeerConnection] the connection instance (reuse if a connection was established, create otherwise).
  accept: (id) ->
    # for created peers
    return peerConn if (peerConn = @peers[id])?

    @info "-- prepare connection to peer[id=#{id}, mode=passive]..."
    return @peers[id] = @create id, false

  # Attempt to connect another peer.
  #
  # @param [String] id peer ID of the peer attempt to connect.
  # @return [PeerConnection] the connection instance (reuse if a connection was established, create otherwise).
  connect: (id) ->
    # for connected peers
    return peerConn if (peerConn = @peers[id])?

    @info "-- prepare connection to peer[id=#{id}, mode=active]..."
    return @peers[id] = @create id, true

  # Create a connection instance.
  #
  # @param [String] id peer ID of the partner.
  # @param [Boolean] initiator true if this peer initiate the connection.
  # @return [PeerConnection] the connection instance.
  create: (id, initiator) ->
    if initiator
      peerConn = new PeerConnection id, initiator: true, wrtc: @wrtc
    else
      peerConn = new PeerConnection id, wrtc: @wrtc
    peerConn.signalCount = 0

    do (peerConn) =>
      peerConn.on 'SIGNAL', (data) =>
        @info "!P [event=SIGNAL]: ready to signal " +
              "peer[id=#{peerConn.id}, seq=#{++peerConn.signalCount}]"
        @emit 'signal', peerConn, data
      peerConn.on 'CONNECT', =>
        @info "*P [event=CONNECT]: connected to peer[id=#{peerConn.id}] " +
              "after #{peerConn.signalCount} signals"
        @emit 'connect', peerConn
      peerConn.on 'CLOSE', =>
        @info "*P [event=CLOSE]: peer[id=#{peerConn.id}] has closed " +
              "the connection"
        @emit 'close', peerConn
      peerConn.on 'HELLO', (data) =>
        @info "<P [event=HELLO]: got HELLO packet from peer[id=#{peerConn.id}]"
        @emit 'handshake', peerConn, data
      peerConn.on 'NOTIFY', (data) =>
        @info "<P [event=NOTIFY]: got NOTIFY packet from " +
              "peer[id=#{peerConn.id}] for " +
              "piece[resource=#{data.resource}, hash=#{data.piece}]"
        @emit 'notify', peerConn, data
      peerConn.on 'DEMAND', (data) =>
        @info "<P [event=DEMAND]: got DEMAND packet from " +
              "peer[id=#{peerConn.id}] for piece[hash=#{data}]"
        @emit 'demand', peerConn, data
      peerConn.on 'LENGTH', (data) =>
        @info "<P [event=LENGTH]: got LENGTH packet from " +
              "peer[id=#{peerConn.id}] - #{data}"
        @emit 'length', peerConn, data
      peerConn.on 'PIECE', (data) =>
        @info "<P [event=PIECE]: got PIECE packet from " +
              "peer[id=#{peerConn.id}] - #{data.length}"
        @emit 'piece', peerConn, data
      peerConn.on 'NEXT', =>
        @info "<P [event=NEXT]: ready to fetch next piece from " +
              "peer[id=#{peerConn.id}]"
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

  info: logger 'PeerManager:info'

exports = module.exports = PeerManager
