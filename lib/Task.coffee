Resource = require './Resource'

logger = require 'debug'

exports = module.exports = class Task extends Resource
  @PREPARING   : 1
  @DOWNLOADING : 2
  @SHARING     : 3
  @DONE        : 4

  debug: logger 'Task:debug'

  # track of missing pieces, may be fetched from tracker
  # missing: Set[hash]
  missing: new Set()
  # used to check if a piece is found in any peer
  # found[hash] => Set[peerId]
  found: {}
  # FIXME: remove?
  # scheduled: Set[hash]
  scheduled: new Set()
  # used to record downloaded pieces
  # hit[hash] => Piece
  hit: {}
  # reverse of found, used for select next piece that get from peer
  # available[peerId] => Set[hash]
  available: {}

  blob: null
  state: Task.PREPARING

  constructor: (hash) ->
    super hash

  prepared: ->
    if @state is Task.PREPARING
      @state = Task.DOWNLOADING
      @emit 'prepared'

  downloaded: (pieces) ->
    if @state is Task.DOWNLOADING
      @blob = new Blob pieces
      @state = Task.SHARING
      @emit 'downloaded'

  done: ->
    if @state is Task.SHARING
      @state = Task.DONE
      @emit 'done'
