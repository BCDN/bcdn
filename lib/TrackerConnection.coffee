WebSocket = require 'ws'
Serializable = require './Serializable'
mix = require './mix'
logger = require 'debug'

exports = module.exports = class TrackerConnection extends mix WebSocket
                                                             , Serializable
  @debug: logger 'tracker:debug'
  @info: logger 'tracker:info'
  @error: logger 'tracker:error'
  constructor: (trackers = [], @key, @token) ->
    # TODO: maybe move to disconnect event for exception handling (reconnect)?
    @selectNearestTracker trackers, (tracker) =>
      super tracker

      # join the network when tracker is ready
      @on 'ready', =>
        # generate token if not provided
        @token ?= @generateToken()

        content = @serialize type: 'JOIN', payload: token: @token
        @send content

      # helper to handle message
      handleMessage = (data) =>
        try
          content = @deserialize data
        catch e
          @constructor.debug "error to deserialize: #{e}, (data=#{data})"
          return

        # ignore malformed messages
        return unless content.type?

        # emit event
        @emit content.type, content.payload


      # handle incoming messages
      @on 'message', (data, flags) =>
        return handleMessage data unless flags.binary

        # TODO handle binary data otherwise (initial piece)


      # handle close event
      @on 'close', (code, data) =>
        return handleMessage data if code is 1002 and data?

        @emit 'ERROR', msg: "socket has closed unexpected, (code=#{code})"

      @on 'open', => @emit 'ready'

  selectNearestTracker: (trackers, cb) ->
    @constructor.info "selecting the nearest tracker from #{trackers}..."

    minPing = Infinity
    nearestTracker = null

    # select the tracker with least ping
    for tracker in trackers
      url = "#{tracker}?key=#{@key}"
      socket = new WebSocket url

      now = undefined
      socket.on 'pong', =>
        ping = new Date().getTime() - now
        @constructor.debug "ping for #{tracker}: #{ping}ms"

        if ping < minPing
          minPing = ping
          nearestTracker = url

        socket.close()

      socket.on 'open', =>
        now = new Date().getTime()
        socket.ping 'HELLO'
        @constructor.debug "pinging #{tracker}..."

    # wait for connection
    checkInterval = 100 # 100 milliseconds
    wait = setInterval =>
      if nearestTracker?
        clearInterval wait
        @constructor.info "select #{nearestTracker} as the nearest tracker"

        cb nearestTracker
    , checkInterval

  generateToken: -> Math.random().toString(36).substr(2)
