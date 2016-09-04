EventEmiter = require 'events'

mix = require './mix'

Serializable = require './Serializable'
Resource = require './Resource'
TaskState = require './TaskState'

logger = require 'debug'

exports = module.exports = class Task extends mix EventEmiter, Resource
  debug: logger 'Task:debug'

  constructor: (hash) ->
    super hash

    # track of missing pieces, may be fetched from tracker
    # missing: Set[hash]
    @missing = new Set()
    # used to check if a piece is found in any peer
    # found[hash] => Set[peerId]
    @found = {}
    # used to record downloaded pieces
    # hit[hash] => Set[piece]
    @hit = new Set()
    # reverse of found, used for select next piece that get from peer
    # available[peerId] => Set[hash]
    @available = {}

    @finished = false
    @state = TaskState.PREPARING

  prepared: ->
    if @state is TaskState.PREPARING
      @state = TaskState.DOWNLOADING
      @emit 'prepared'

  notify: (peer, hash) ->
    # set to found for pieces haven't been downloaded
    unless @hit.has hash
      # move from missing to found
      @missing.delete hash
      @found[hash] ?= new Set()
      @found[hash].add peer
      @available[peer].add hash

  write: (hash) ->
    @missing.delete hash
    if (peers = @found[hash])?
      delete @found[hash]
      peers.forEach (peer) => @available[peer].delete hash
    @hit.add hash

    # check finishing
    @downloaded() if @missing.size is 0 and Object.keys(@found).length is 0
    @emit 'write', hash

  downloaded: ->
    if @state is TaskState.DOWNLOADING
      @finished = true
      @state = TaskState.SHARING
      @emit 'downloaded'

  done: ->
    if @state is TaskState.SHARING
      @state = TaskState.DONE
      @emit 'done'
