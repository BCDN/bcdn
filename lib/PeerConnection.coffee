SimplePeer = require 'simple-peer'
Serializable = require './Serializable'
mix = require './mix'

logger = require 'debug'

exports = module.exports = class PeerConnection extends mix SimplePeer
                                                          , Serializable
  verbose: logger 'PeerConnection:verbose'
  debug: logger 'PeerConnection:debug'
  info: logger 'PeerConnection:info'

  constructor: (@id, options) ->
    @debug "Create PeerConnection for #{@id}, " +
           "initiator: #{!!options.initiator}"
    super options

    # tasks it attached to and pieces it has (don't notify resource it has)
    # pieces[hash] => Set[pieces]
    @pieces = {}

    # use to store next piece
    @pieceLength = 0
    @pieceBuffers = []

    @on 'signal', (data) => @emit 'SIGNAL', data
    @on 'data', (data) =>
      content = data

      return @emit 'PIECE', data if data instanceof Buffer

      if data instanceof String
        try
          content = @deserialize data
        catch e
          return @debug "error to deserialize: #{e}, (data=#{data})"

      # sanitize malformed messages
      return unless content.type in ['HELLO', 'NOTIFY', 'DEMAND', 'LENGTH']

      @verbose "peer has sent a message (id=#{@id}, data=#{data})"

      # emit information
      @emit content.type, content.payload
    @on 'connect', => @emit 'CONNECT'
    @on 'close', => @emit 'CLOSE'

  send: (msg, binary = false) ->
    return super msg if binary

    content = @serialize msg
    super content
    @verbose "message sent to peer: #{content}"

  handshake: (payload)  -> @send type: 'HELLO',  payload: payload
  notify: (payload)     -> @send type: 'NOTIFY', payload: payload
  demand: (payload)     -> @send type: 'DEMAND', payload: payload
  sendLength: (payload) -> @send type: 'LENGTH', payload: payload
  sendPiece: (piece)    -> @send piece, true
