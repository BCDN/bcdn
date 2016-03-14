Peer = require './Peer'
Contents = require './Contents'
TrackerConnection = require './TrackerConnection'
PeerManager = require './PeerManager'
DownloadManager = require './DownloadManager'
Task = require './Task'

logger = require 'debug'

exports = module.exports = class BCDNPeer
  debug: logger 'BCDNPeer:debug'
  info: logger 'BCDNPeer:info'
  error: logger 'BCDNPeer:error'

  constructor: (options, onUpdate) ->
    # parse options
    default_options =
      key: 'bcdn'
    default_options extends options

    {trackers, key} = options


    # initialize variables
    @peer = new Peer key
    @contents = new Contents()
    @trackerConn = new TrackerConnection trackers, @peer
    @peers = new PeerManager @peer, options
    @download = new DownloadManager options


    # report error on tracker connection error
    @trackerConn.on 'ERROR', (payload) =>
      {msg} = payload
      @error msg
    # save peer id after joined the network
    @trackerConn.on 'JOINED', (payload) =>
      {id} = payload
      @peer.id = id
      @info "tracker has accepted the join request, peer ID: #{@peer.id}"
    # got contents updates
    @trackerConn.on 'UPDATE', (payload) =>
      @contents.deserialize payload, (path, resource) =>
        @debug "FIXME: #{path} has changed to resource: #{resource.hash}!"

        # if the resource requires auto-load or is tracking, fetch it's pieces
        if resource.auto # TODO: or tracked resources
          @get path, (blob) =>
            console.log "#{path} has finished downloading."

      @debug "contents has been updated: #{@contents.serialize()}"
      onUpdate()
    # resource info received
    @trackerConn.on 'RESOURCE', (payload) =>
      {hash, resource, candidates} = payload
      @download.prepare hash, resource

      # connect all possible candidates
      task = @download.tasks[hash]
      candidates.forEach (peer) =>
        if (peerConn = @peers.connect peer)?
          # attach current task to peer connection
          # TODO: remove the attached task after task has finished
          peerConn.pieces[task.hash] = new Set()

          # resend hello if new task was added
          @peers.emit 'connect', peerConn if peerConn.connected

      # FIXME: bind piece to the task

    @trackerConn.on 'SIGNAL', (payload) =>
      peer = payload.from
      @peers.accept peer
      @peers.processSignal payload

    @download.on 'ready', (task) =>
      @info "start task #{task.hash}"
      @trackerConn.downloadResource hash: task.hash

    @peers.on 'signal', (peerConn, data) =>
      @trackerConn.signal to: peerConn.id, signal: data

    @peers.on 'connect', (peerConn) =>
      # construct information for handshaking we has for this peer
      # info[resourceHash] => state: TaskState, pieces: [piecesHit]
      info = {}
      for hash in Object.keys peerConn.pieces
        task = @download.tasks[hash]
        # set state
        info[hash] = state: task.state
        # set pieces if it's downloading
        if task.state == Task.DOWNLOADING
          info[hash].pieces = Object.keys task.hit

      peerConn.handshake info

    @peers.on 'close', (peerConn) =>
      # remove piece tracking for peer from task
      for hash, pieces of peerConn.pieces
        task = @download.tasks[hash]

        # remove the pool for next exchange
        task.available[peerConn.id]? and delete task.available[peerConn.id]

        for piece in pieces
          task.found[piece].delete peerConn.id

          # if no more peer has this piece, unschedule it move it back to missing
          if task.found[piece].size is 0
            task.scheduled.delete piece
            delete task.found[piece]
            task.missing.add piece
          # FIXME: need test
        @debug "DEBUG close result:", task.missing, task.found, task.available

    @peers.on 'handshake', (peerConn, info) =>
      flagReconnect = false
      @debug "DEBUG handshake info:", info

      for hash, tracking of info
        # for downloading tasks only
        task = @download.tasks[hash]
        continue unless task.state == Task.DOWNLOADING

        # attach tasks if not added
        unless peerConn.pieces[hash]?
          peerConn.pieces[hash] = new Set()
          flagReconnect = true

        # retrieve pieces from tracking info
        {state, pieces} = tracking
        pieces = task.pieces if tracking.state == Task.SHARING

        # prepare pool for next exchange
        task.available[peerConn.id] ?= new Set()

        for piece in pieces
          # track pieces peer has to its connection
          peerConn.pieces[hash].add piece

          # set to found for pieces haven't been downloaded
          unless task.hit[piece]?
            # move from missing to found
            task.missing.delete piece
            task.found[piece] ?= new Set()
            task.found[piece].add peerConn.id
            task.available[peerConn.id] = piece
        # FIXME: need test
        @debug "DEBUG handshake result:",
               task.missing, task.found, task.available

      @peers.emit 'connect', peerConn if flagReconnect


  get: (path, onFinish) ->
    # get resource metadata
    return unless (metadata = @contents.resources[path])?
    {size, hash, auto} = metadata

    # queue the resource or get current task
    task = @download.queue hash

    if task.blob?
      # if the task has downloaded the resource, callback with the blob
      onFinish task.blob
    else
      # otherwise call back on task finish downloading the resource
      task.on 'downloaded', => onFinish task.blob

    # return the task
    return task
