SimplePeer = require 'simple-peer'
Serializable = require './Serializable'
mix = require './mix'

logger = require 'debug'

exports = module.exports = class PeerConnection extends mix SimplePeer
                                                          , Serializable
  verbose: logger 'PeerConnection:verbose'
  debug: logger 'PeerConnection:debug'
  info: logger 'PeerConnection:info'

  # tasks it attached to and pieces it has (don't notify resource it has)
  # pieces[hash] => Set[pieces]
  pieces: {}

  constructor: (@id, options) ->
    @debug "Create PeerConnection for #{@id}, initiator: #{!!options.initiator}"
    super options

    @on 'signal', (data) => @emit 'SIGNAL', data
    @on 'data', (data) =>
      content = data

      if data instanceof String
        try
          content = @deserialize data
        catch e
          return @debug "error to deserialize: #{e}, (data=#{JSON.stringify data})"

      # sanitize malformed messages
      return unless content.type in ['HELLO']

      @verbose "peer has sent a message (id=#{@id}, data=#{data})"

      # emit information
      @emit content.type, content.payload
    @on 'connect', => @emit 'CONNECT'
    @on 'close', => @emit 'CLOSE'

  send: (msg) ->
    content = @serialize msg
    super content
    @verbose "message sent to peer: #{content}"

  handshake: (payload) -> @send type: 'HELLO', payload: payload
