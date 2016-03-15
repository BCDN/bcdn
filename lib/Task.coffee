Resource = require './Resource'

logger = require 'debug'

exports = module.exports = class Task extends Resource
  @PREPARING   : 1
  @DOWNLOADING : 2
  @SHARING     : 3
  @DONE        : 4

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

    @blob = null
    @state = Task.PREPARING

  prepared: ->
    if @state is Task.PREPARING
      @state = Task.DOWNLOADING
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
    @emit 'write', hash

  downloaded: (pieces) ->
    if @state is Task.DOWNLOADING
      @blob = new Blob pieces
      @state = Task.SHARING
      @emit 'downloaded'

  done: ->
    if @state is Task.SHARING
      @state = Task.DONE
      @emit 'done'
