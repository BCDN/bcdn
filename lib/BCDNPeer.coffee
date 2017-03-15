Peer = require './Peer'
Contents = require './Contents'
TrackerConnection = require './TrackerConnection'
PeerManager = require './PeerManager'
DownloadManager = require './DownloadManager'
PieceManager = require './PieceManager'
TaskState = require './TaskState'
Util = require './Util'

logger = require 'debug'

# Entry point of peer node.
class BCDNPeer
  # @property [Peer] the peer itself.
  peer: null
  # @property [Contents] contents for the namespace (or key) that this peer visits.
  contents: null
  # @property [TrackerConnection] the connection between this peer and its tracker.
  trackerConn: null
  # @property [PeerManager] the manager for peer connection management.
  peers: null
  # @property [DownloadManager] the download manager.
  download: null
  # @property [PieceManager] the manager for pieces of tasks.
  pieces: null

  # Create a BCDN peer instance.
  #
  # @param [Object<String, ?>] options options for the peer node instance.
  # @param [Function] onUpdate callback function when contents gets updated.
  constructor: (options, onUpdate) ->
    # apply default options.
    default_options = key: 'bcdn'
    default_options extends options

    # generate default token (if not provided).
    options.token ?= Util.generateToken()

    # initialize data models and managers.
    @peer = new Peer options
    @contents = new Contents()
    @trackerConn = new TrackerConnection options
    @peers = new PeerManager options
    @download = new DownloadManager options
    @pieces = new PieceManager options

    # setup handles for tracker connection.
    @trackerConn.on 'ERROR', (payload) =>
      {msg} = payload
      @info "<T [event=ERROR]: #{msg}"
      # note: since the connection will be closed from tracker-side,
      #       error handling is not required.

    @trackerConn.on 'JOINED', (payload) =>
      {id} = payload
      @peer.id = id

      @info "*T [event=CONNECT]: connected to " +
            "tracker[id=#{@peer.id.substr(0, @peer.id.indexOf('-'))}]"
      @info "<T [event=JOINED]: got JOINED packet from tracker, " +
            "assigning peer ID - #{@peer.id}"

    @trackerConn.on 'UPDATE', (payload) =>
      @contents.deserialize payload, (path, oldHash, newHash) =>
        # future work: handle path related change, not important
        return

      @info "<T [event=UPDATE]: got UPDATE packet from tracker"
      onUpdate()

    @trackerConn.on 'RESOURCE', (payload) =>
      {hash, resource, candidates} = payload

      @info "<T [event=RESOURCE]: got RESOURCE packet from tracker, " +
            "adding task[hash=#{hash}] with available candidates - " +
            "#{candidates.join ', '}"
      task = @download.prepare hash, resource

      # connect all possible candidates.
      candidates.forEach (peer) =>
        # prevent connect to itself, this is not necessary since candidates
        # are sent to this peer before track itself, but just in case...
        return if peer is @peer.id

        peerConn = @peers.connect peer

        # attach current task to peer connection. TODO: reset? or just initialize?
        peerConn.pieces[task.hash] = new Set()
        # resend hello if new task was added.
        @peers.emit 'connect', peerConn if peerConn.connected

    @trackerConn.on 'SIGNAL', (payload) =>
      {from, signal} = payload

      @info "<T [event=SIGNAL]: got SIGNAL packet from peer[id=#{from}] " +
            "via tracker"
      peer = @peers.accept from
      peer.signal signal

    @trackerConn.on 'PIECE', (buffer) =>
      @info "<T [event=PIECE]: got PIECE packet from tracker"
      @pieces.write buffer, 'tracker'

    # setup handles for tracker download manager.
    @download.on 'ready', (task) =>
      @info "-- start task[hash=#{task.hash}]"
      @trackerConn.downloadResource task.hash

    # setup handles for tracker peer manager.
    @peers.on 'signal', (peerConn, data) =>
      @trackerConn.signal to: peerConn.id, signal: data

    @peers.on 'connect', (peerConn) =>
      # construct information for handshaking we has for this peer.
      info = {}
      for hash in Object.keys peerConn.pieces
        task = @download.tasks[hash]
        # set state of current task.
        info[hash] = state: task.state
        # set pieces if it's downloading.
        if task.state is TaskState.DOWNLOADING
          info[hash].pieces = Array.from task.hit
      peerConn.handshake info

    @peers.on 'close', (peerConn) =>
      # remove from peer list.
      @peers.delete peerConn.id

      # remove piece tracking for peer from task.
      for hash, pieces of peerConn.pieces
        task = @download.tasks[hash]

        # remove the pool for next exchange.
        task.available[peerConn.id]? and delete task.available[peerConn.id]

        pieces.forEach (piece) =>
          return unless task.found[piece]?
          task.found[piece].delete peerConn.id

          # if no more peer has this piece,
          # unschedule it and add it back to missing.
          if task.found[piece].size is 0
            delete task.found[piece]
            task.missing.add piece

        if task.state is TaskState.DOWNLOADING and not task.fetching?
          task.emit 'fetch'

    @peers.on 'handshake', (peerConn, info) =>
      flagReconnect = false
      for hash, tracking of info
        # for download tasks only.
        task = @download.tasks[hash]

        # attach tasks if not added.
        unless peerConn.pieces[hash]?
          peerConn.pieces[hash] = new Set()
          flagReconnect = true

        continue unless task.state is TaskState.DOWNLOADING

        # retrieve pieces from tracking info.
        {state, pieces} = tracking
        pieces = task.pieces if state is TaskState.SHARING

        # prepare pool for next exchange.
        task.available[peerConn.id] ?= new Set()

        for piece in pieces
          # track pieces peer has to its connection.
          peerConn.pieces[hash].add piece
          # notify task.
          task.notify peerConn.id, piece

      @peers.emit 'connect', peerConn if flagReconnect
      peerConn.emit 'NEXT' unless peerConn.demandingLock

    @peers.on 'notify', (peerConn, payload) =>
      {resource, piece} = payload
      peerConn.pieces[resource].add piece
      if (task = @download.tasks[resource])?
        task.notify peerConn.id, piece
      peerConn.emit 'NEXT' unless peerConn.demandingLock

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
        @pieces.write mergedBuffer, "peer[#{peerConn.id}]"
        peerConn.emit 'NEXT'

    @peers.on 'next', (peerConn) =>
      peerConn.demandingLock = true

      # for the resource hash of each task bound to this peer connection
      # demand next missing piece available from any task.
      for hash in Object.keys peerConn.pieces
        task = @download.tasks[hash]
        if (pieces = task.available[peerConn.id])?
          if (hash = pieces.values().next().value)?
            return peerConn.demand hash

      # TODO: better options: select the piece the least peers owned.
      #                       select the piece the most task requests.
      #                       select the piece in random order.
      #       They are not being implemented since they requires stats module.

      peerConn.demandingLock = false

  # Get a resource by its path.
  #
  # @param [String] path path of the resource.
  # @param [Function] onFinish callback function when a resource download task has been finished.
  # @option onFinish [Array<Buffer>] buffers all buffers of the task.
  # @return [Task] the download task.
  get: (path, onFinish) ->
    # get resource metadata.
    return unless (metadata = @contents.resources[path])?
    {size, hash} = metadata

    # queue the resource or get current task.
    task = @download.queue hash

    do (task) =>
      # start working once prepared.
      task.on 'prepared', =>
        # create and/or bind piece to task.
        for hash in task.pieces
          do (piece = @pieces.prepare hash) =>
            if piece.data?
              task.write piece.hash
            else
              piece.on 'write', => task.write piece.hash
        # start fetch job.
        task.emit 'fetch'

      # add job to fetch random missing piece from tracker.
      task.on 'fetch', =>
        missing = Array.from task.missing

        if missing.length is 0
          task.fetching = null
          return

        i = Math.floor Math.random() * missing.length
        next = missing[i]
        task.fetching = next
        @trackerConn.fetch next

      # notify peer on write piece.
      task.on 'write', (pieceHash) =>
        # for each peer bound to this task...
        # notify them only if they don't have this piece.
        for peerId in Object.keys task.available
          continue unless (peerConn = @peers.get peerId)?
          continue if peerConn.pieces[task.hash].has pieceHash
          peerConn.notify resource: task.hash, piece: pieceHash

        # if this piece is fetched from tracker, fetch the next piece.
        task.emit 'fetch' if pieceHash is task.fetching

      if task.finished
        # if the task has downloaded the resource, callback with the blob.
        onFinish @buffersFor task
      else
        # otherwise call back on task finish downloading the resource.
        task.on 'downloaded', => onFinish @buffersFor task

      # return the task.
      return task

  # Get all buffers of a task.
  #
  # @param [Task] task the task reference.
  # @return [Array<Buffer>] all buffers of the task.
  buffersFor: (task) ->
    (piece = @pieces.get hash) and piece.data for hash in task.pieces

  debug: logger 'BCDNPeer:debug'
  info: logger 'BCDNPeer:info'

exports = module.exports = BCDNPeer
