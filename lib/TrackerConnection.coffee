WebSocket = require 'ws'

Serializable = require './Serializable'
mix = require './mix'

logger = require 'debug'

# WebSocket wrapper for tracker connection.
#
# @extend WebSocket
# @extend Serializable
class TrackerConnection extends mix WebSocket, Serializable
  # @property [Array<String>] all tracker URLs.
  trackers: null
  # @property [String] connection key for namespacing.
  key: null
  # @property [String] token used for authenticate peer ID on reconnect.
  token: null

  # Instantiate a connection to a tracker.
  #
  # @param [Object<String, ?>] options options from {BCDNPeer} for initialize this tracker connection.
  constructor: (options) ->
    {@trackers, @key, @token} = options

    @selectNearestTracker (tracker) =>
      @info "-- join network by connecting to tracker #{@trackers}..."
      super "#{tracker}&token=#{@token}"

      # helper to handle message.
      handleMessage = (data, close = false) =>
        try
          content = @deserialize data
        catch e
          return @error "EE error to deserialize: #{e}, (data=#{data})"

        # sanitize malformed messages.
        return unless content.type in ['ERROR', 'JOINED', 'UPDATE', 'RESOURCE',
                                       'SIGNAL']

        _action = if close then "closed the connection with" else "sent"
        @debug "<T tracker has #{_action} a message (data=#{data})"

        # emit event.
        @emit content.type, content.payload


      # handle incoming messages.
      @on 'message', (data, flags) =>
        return handleMessage data unless flags.binary
        @emit 'PIECE', data

      # handle close event.
      @on 'close', (code, data) =>
        return handleMessage data if code is 1002 and data?

        @emit 'ERROR', msg: "socket has closed unexpected, (code=#{code})"

  # Select the nearest tracker.
  #
  # @param [Function] callback callback function when the nearest tracker got selected.
  # @option callback [String] URL for the selected tracker.
  selectNearestTracker: (callback) ->
    @info "-- selecting the nearest tracker from #{@trackers}..."

    minPing = Infinity
    nearestTracker = null

    # select the tracker with least ping
    for tracker in @trackers
      url = "#{tracker}?key=#{@key}"
      do (socket = new WebSocket url) =>

        socket.on 'error', (error) =>
          @error "EE error on ping tracker - #{error}"

        now = undefined
        socket.on 'pong', =>
          ping = new Date().getTime() - now
          @info "-- ping for #{tracker}: #{ping}ms"

          if ping < minPing
            minPing = ping
            nearestTracker = url

          socket.close()

        socket.on 'open', =>
          now = new Date().getTime()
          socket.ping 'HELLO'
          @info "-- pinging #{tracker}..."

    # wait for result
    waitTimeout = 10000 # 10 seconds
    checkInterval = 100 # 100 milliseconds

    wait = setTimeout =>
      throw new Error "no tracker available"
    , waitTimeout

    check = setInterval =>
      if nearestTracker?
        clearTimeout wait
        clearInterval check
        @info "-- select #{nearestTracker} as the nearest tracker"

        callback nearestTracker
    , checkInterval

  # Connection helper that sends a message to tracker.
  #
  # @param [Object] msg message object.
  send: (msg) ->
    content = @serialize msg
    super content
    @debug ">T message sent to tracker: #{content}"

  # Action helper that starts downloading a resource.
  #
  # @param [String] hash hash value of the resource.
  downloadResource: (hash) ->
    @info ">T [msg=DOWNLOAD]: send DOWNLOAD packet to tracker " +
          "for resource[hash=#{hash}]"
    @send type: 'DOWNLOAD', payload: hash

  # Action helper that requests fetching a piece.
  #
  # @param [String] hash hash value of the piece.
  fetch: (hash) ->
    @info ">T [msg=FETCH]: send FETCH packet to tracker"
    @send type: 'FETCH',    payload: hash

  # Action helper that sends a signal packet to a peer for establish direct connection.
  #
  # @param [Object] detail the signal packet.
  signal: (detail) ->
    @info ">T [msg=SIGNAL]: send SIGNAL packet to peer[id=#{detail.to}] " +
          "via tracker"
    @send type: 'SIGNAL', payload: detail

  debug: logger 'TrackerConnection:debug'
  info: logger 'TrackerConnection:info'
  error: logger 'TrackerConnection:error'

exports = module.exports = TrackerConnection
