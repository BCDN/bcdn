WebSocket = require 'ws'

Serializable = require './Serializable'
mix = require './mix'

logger = require 'debug'

exports = module.exports = class TrackerConnection extends mix WebSocket
                                                             , Serializable
  debug: logger 'TrackerConnection:debug'
  info: logger 'TrackerConnection:info'
  error: logger 'TrackerConnection:error'

  constructor: (trackers = [], @peer) ->
    # TODO: maybe move to disconnect event for exception handling (reconnect)?
    @selectNearestTracker trackers, (tracker) =>
      generateToken = -> Math.random().toString(36).substr(2)
      super "#{tracker}&token=#{@peer.token ?= generateToken()}"

      # helper to handle message
      handleMessage = (data, close = false) =>
        try
          content = @deserialize data
        catch e
          return @debug "error to deserialize: #{e}, (data=#{data})"

        #  sanitize malformed messages
        return unless content.type in ['ERROR', 'JOINED']

        _action = if close then "closed the connection with" else "sent"
        @debug "tracker has #{_action} a message (data=#{data})"

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



  selectNearestTracker: (trackers, cb) ->
    @info "selecting the nearest tracker from #{trackers}..."

    minPing = Infinity
    nearestTracker = null


    # select the tracker with least ping
    for tracker in trackers
      url = "#{tracker}?key=#{@peer.key}"
      socket = new WebSocket url

      now = undefined
      socket.on 'pong', =>
        ping = new Date().getTime() - now
        @debug "ping for #{tracker}: #{ping}ms"

        if ping < minPing
          minPing = ping
          nearestTracker = url

        socket.close()

      socket.on 'open', =>
        now = new Date().getTime()
        socket.ping 'HELLO'
        @debug "pinging #{tracker}..."


    # wait for result
    checkInterval = 100 # 100 milliseconds
    wait = setInterval =>
      if nearestTracker?
        clearInterval wait
        @info "select #{nearestTracker} as the nearest tracker"

        cb nearestTracker
    , checkInterval
