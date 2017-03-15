SimplePeer = require 'simple-peer'
Serializable = require './Serializable'
mix = require './mix'

logger = require 'debug'

# SimplePeer wrapper for tracker connection.
#
# @extend SimplePeer
# @extend Serializable
class PeerConnection extends mix SimplePeer, Serializable
  # @property [String] ID for this peer connection.
  id: null
  # @property [Object<String, Set<String>>] pieces the peer has for each resource (Object<resourceHash, Set<pieceHash>>).
  pieces: null
  # @property [Number] length of the piece buffer.
  pieceLength: 0
  # @property [Array<Buffer>] the piece buffer.
  pieceBuffers: null

  # Create a peer connection instance for its partner.
  #
  # @param [String] id peer ID of the partner.
  # @param [Object<String, ?>] options options from {BCDNPeer} for initialize this peer connection.
  constructor: (@id, options) ->
    @info "-- create PeerConnection for #{@id}, " +
             "initiator: #{!!options.initiator}"
    super options

    # initialize the pieces information this peer connection own,
    # so don't notify the peer for pieces it own.
    @pieces = {}

    # initialize the piece buffer use to store the next piece.
    @pieceBuffers = []

    # helper to handle message.
    handleMessage = (data) =>
      # note: data is deserialized automatically, no action is required.
      content = data

      # sanitize malformed messages
      return unless content.type in ['HELLO', 'NOTIFY', 'DEMAND', 'LENGTH']

      @debug "<P peer #{@id} has sent a message (data=#{data})"

      # emit event
      @emit content.type, content.payload

    # handle incoming signal.
    @on 'signal', (data) => @emit 'SIGNAL', data
    # handle incoming data.
    @on 'data', (data) =>
      return handleMessage data unless data instanceof Buffer
      @emit 'PIECE', data
    # handle connect/close.
    @on 'connect', => @emit 'CONNECT'
    @on 'close', => @emit 'CLOSE'

  # Connection helper that sends a message to peer.
  #
  # @param [Object] msg message object.
  # @param [Boolean] binary whether the message is in binary.
  send: (msg, binary = false) ->
    return super msg if binary

    content = @serialize msg
    super content
    @debug ">P send message to peer: #{content}"

  # Action helper that handshakes with a partner.
  #
  # @param [Object<String, ?>] payload payload for the handshake packet - { $resourceHash: { state: TaskState, pieces: String[] } }.
  handshake: (payload) ->
    @info ">P [msg=HELLO]: send HELLO packet to peer[id=#{@id}]"
    @send type: 'HELLO', payload: payload

  # Action helper that notifies a partner for a new piece downloaded.
  #
  # @param [Object<String, String>] payload payload for the notify packet - { resource: String, piece: String }.
  notify: (payload) ->
    @info ">P [msg=NOTIFY]: send NOTIFY packet to peer[id=#{@id}] " +
                           "for piece[resource=#{payload.resource}, " +
                                         "hash=#{payload.piece}]"
    @send type: 'NOTIFY', payload: payload

  # Action helper that requests a piece from its partner.
  #
  # @param [String] payload hash of the resource demanded.
  demand: (payload) ->
    @info ">P [msg=DEMAND]: send DEMAND packet to peer[id=#{@id}] " +
                           "for piece[hash=#{payload}]"
    @send type: 'DEMAND', payload: payload

  # Action helper that sends the length of the next piece.
  #
  # @param [Number] payload length of the next piece.
  sendLength: (payload) ->
    @info ">P [msg=LENGTH]: send LENGTH packet to peer[id=#{@id}] - #{payload}"
    @send type: 'LENGTH', payload: payload

  # Action helper that sends the next piece.
  #
  # @param [Buffer] payload the next piece.
  sendPiece: (piece) ->
    @info ">P [msg=PIECE]: send PIECE packet to peer[id=#{@id}] " +
                          "- #{piece.length}"
    @send piece, true

  debug: logger 'PeerConnection:debug'
  info: logger 'PeerConnection:info'
  error: logger 'PeerConnection:error'

exports = module.exports = PeerConnection
