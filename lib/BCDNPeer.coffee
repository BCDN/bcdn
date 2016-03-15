Peer = require './Peer'
Contents = require './Contents'
TrackerConnection = require './TrackerConnection'
PeerManager = require './PeerManager'
DownloadManager = require './DownloadManager'
PieceManager = require './PieceManager'
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
    @pieces = new PieceManager options


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
      @contents.deserialize payload, (path, oldHash, newHash) =>
        # TODO handle path related change, not important
        return

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

    @trackerConn.on 'SIGNAL', (payload) =>
      peer = payload.from
      @peers.accept peer
      @peers.processSignal payload

    @trackerConn.on 'PIECE', (buffer) =>
      @pieces.write buffer

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
        if task.state is Task.DOWNLOADING
          info[hash].pieces = Array.from task.hit

      peerConn.handshake info

    @peers.on 'close', (peerConn) =>
      # remove from peer list
      @peers.delete peerConn.id

      # remove piece tracking for peer from task
      for hash, pieces of peerConn.pieces
        task = @download.tasks[hash]

        # remove the pool for next exchange
        task.available[peerConn.id]? and delete task.available[peerConn.id]

        pieces.forEach (piece) =>
          return unless task.found[piece]?
          task.found[piece].delete peerConn.id

          # if no more peer has this piece, unschedule it move it back to missing
          if task.found[piece].size is 0
            delete task.found[piece]
            task.missing.add piece

        if task.state is Task.DOWNLOADING and not task.fetching?
          task.emit 'fetch'

    @peers.on 'handshake', (peerConn, info) =>
      flagReconnect = false
      for hash, tracking of info
        # for downloading tasks only
        task = @download.tasks[hash]

        # attach tasks if not added
        unless peerConn.pieces[hash]?
          peerConn.pieces[hash] = new Set()
          flagReconnect = true

        continue unless task.state is Task.DOWNLOADING

        # retrieve pieces from tracking info
        {state, pieces} = tracking
        pieces = task.pieces if tracking.state is Task.SHARING

        # prepare pool for next exchange
        task.available[peerConn.id] ?= new Set()

        for piece in pieces
          # track pieces peer has to its connection
          peerConn.pieces[hash].add piece

          # notify task
          task.notify peerConn.id, piece

      @peers.emit 'connect', peerConn if flagReconnect
      peerConn.emit 'NEXT' unless peerConn.demanding

    @peers.on 'notify', (peerConn, payload) =>
      {resource, piece} = payload
      peerConn.pieces[resource].add piece
      if (task = @download.tasks[resource])?
        task.notify peerConn.id, piece

    @peers.on 'demand', (peerConn, hash) =>
      piece = @pieces.get hash
      peerConn.sendLength piece.data.length
      peerConn.sendPiece piece.data

    @peers.on 'length', (peerConn, length) =>
      peerConn.pieceLength = length
      peerConn.pieceBuffers = []

    @peers.on 'piece', (peerConn, buffer) =>
      peerConn.pieceBuffers.push buffer
      peerConn.pieceLength -= buffer.length

      if peerConn.pieceLength is 0
        mergedBuffer = Buffer.concat peerConn.pieceBuffers
        @pieces.write mergedBuffer
        peerConn.emit 'NEXT'

    @peers.on 'next', (peerConn) =>
      peerConn.demanding = true
      for hash in Object.keys peerConn.pieces
        task = @download.tasks[hash]
        if (pieces = task.available[peerConn.id])?
          if (hash = pieces.values().next().value)?
            return peerConn.demand hash
      peerConn.demanding = false


  get: (path, onFinish) ->
    # get resource metadata
    return unless (metadata = @contents.resources[path])?
    {size, hash} = metadata

    # queue the resource or get current task
    task = @download.queue hash

    do (task) =>
      # start working once prepared
      task.on 'prepared', =>
        # bind piece to task
        for hash in task.pieces
          do (piece = @pieces.prepare hash) =>
            if piece.data?
              task.write piece.hash
            else
              piece.on 'write', => task.write piece.hash
        # start fetch job
        task.emit 'fetch'

      # add job to fetch random missing piece from tracker
      task.on 'fetch', =>
        if task.missing.size is 0
          task.fetching = null
          return

        i = Math.floor Math.random() * task.missing.size
        next = Array.from(task.missing)[i]
        task.fetching = next
        task.missing.delete next
        @trackerConn.fetch next

      # notify peer on write piece
      task.on 'write', (hash) =>
        # for every peer tracked by the task
        for peer, hashs of task.available
          # for notify them if they don't have that piece
          unless hashs.has hash
            if (peerConn = @peers.get peer)?
              peerConn.notify resource: task.hash, piece: hash
        task.emit 'fetch' if hash is task.fetching

      if task.finished
        # if the task has downloaded the resource, callback with the blob
        onFinish @buffersFor task
      else
        # otherwise call back on task finish downloading the resource
        task.on 'downloaded', => onFinish @buffersFor task

      # return the task
      return task

  buffersFor: (task) ->
    (piece = @pieces.get hash) and piece.data for hash in task.pieces
