WebSocket = require 'ws'
Peer = require 'simple-peer'

module.exports = class BCDN
  # TODO: add signing key
  constructor: (@servers = [], @key) ->
    # initialize instance variables
    @client = {}
    @peers = {}

  join: (id = '', token = generateToken()) ->
    # select the server with the least connection time
    for server in @servers
      wsUrl = "#{server}?key=#{@key}"
      ws = new WebSocket wsUrl

      ws.on 'open', ->
        ws.send JSON.stringify type: 'PING'

    # # TODO: signal server
    # if data
    #   peer = new Peer initiator: true
    #   peer.signal(data)
    #   peer.on 'signal', (data) ->
    #     # AJAX @config.master_signal
    # else
    #   peer = new Peer()
  generateToken: -> Math.random().toString(36).substr(2)
