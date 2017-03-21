EventEmiter = require 'events'

Serializable = require './Serializable'
Resource = require './Resource'
TaskState = require './TaskState'
mix = require './mix'

logger = require 'debug'

# Wrapped Resource data model for downloading purpose.
#
# @extend EventEmiter
# @extend Resource
class Task extends mix EventEmiter, Resource
  # @property [Set<String>] all pieces not yet found on any peer nodes (Set<pieceHash>).
  missing: null
  # @property [Object<String, Set<String>>] mapping for where every missing piece can be found (Object<pieceHash, Set<peerId>>).
  found: null
  # @property [Set<String>] all pieces that has been downloaded (Set<pieceHash>).
  hit: null
  # @property [Object<String, Set<String>>] reverse of found, mapping for who has which set of missing pieces (Object<peerId, Set<pieceHash>>).
  available: null
  # @property [Boolean] whether the task has been finished.
  finished: false
  # @property [Number] number of the unique pieces for the task.
  uniquePieceSize: 0
  # @property [TaskState] current state of downloading for this task.
  state: TaskState.PREPARING
  # @property [String] hash of the piece that is currently fetched from tracker by this task, null for not fetching.
  fetching: null

  # Prepare the resource index for this task, and notify others that the task has been prepared.
  #
  # @param [String] resource serialized resource object.
  prepare: (resource) ->
    # make sure the resource only get prepared once.
    return unless @state is TaskState.PREPARING

    # prepare the task by deserializing the serialized resource object.
    @deserialize resource
    @info "-- prepare resource index for task[hash=#{@hash}] " +
             "with #{@pieces.length} pieces"

    # add all pieces to missing pieces.
    # TODO: some pieces may already been downloaded.
    @missing = new Set @pieces
    @found = {}
    @hit = new Set()
    @available = {}
    @uniquePieceSize = @missing.size

    # notify that this task has been prepared.
    @state = TaskState.DOWNLOADING
    @emit 'prepared'

  # FIXME: add an addPeer(peerId) method for initialize @available[peerId] = new Set().

  # Notify this task that another peer own a piece.
  #
  # @param [String] peerId the peer who notifies this task.
  # @param [String] pieceHash hash value of the new piece the peer own.
  notify: (peerId, pieceHash) ->
    # ignore pieces that have already been downloaded.
    return if @hit.has pieceHash

    # move the piece hash from missing to found
    @missing.delete pieceHash
    @found[pieceHash] ?= new Set()
    @found[pieceHash].add peerId
    @available[peerId].add pieceHash

  # Notify this task that a piece has been written.
  #
  # @param [String] pieceHash hash value of the piece gets written.
  write: (pieceHash) ->
    # move the piece has from missing to hit, also cleanup mapping for found and available.
    @missing.delete pieceHash
    if (peers = @found[pieceHash])?
      delete @found[pieceHash]
      peers.forEach (peer) => @available[peer].delete pieceHash
    @hit.add pieceHash

    # check if the task has finished downloading.
    @downloaded() if @missing.size is 0 and Object.keys(@found).length is 0

    # notify that this task owns a new piece.
    @emit 'write', pieceHash

  # State the task has been downloaded and starts sharing.
  downloaded: ->
    # the task can only be marked as sharing when it was downloading.
    return unless @state is TaskState.DOWNLOADING

    @finished = true

    # notify that this task has been downloaded.
    @state = TaskState.SHARING
    @emit 'downloaded'

  # State the task stops sharing.
  done: ->
    # the task can only stop sharing when it was sharing.
    return unless @state is TaskState.SHARING

    # notify that this task has stopped sharing.
    @state = TaskState.DONE
    @emit 'done'

  info: logger 'Task:info'

exports = module.exports = Task
