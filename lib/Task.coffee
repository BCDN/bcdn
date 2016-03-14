Resource = require './Resource'

logger = require 'debug'

exports = module.exports = class Task extends Resource
  @PREPARING   : 1
  @DOWNLOADING : 2
  @SHARING     : 3
  @DONE        : 4

  debug: logger 'Task:debug'

  candidates: new Set()

  # missing:[hash]
  missing: new Set()
  # found/schedule[hash] => [peerId]
  found: {}
  scheduled: {}
  # hit[hash] => Piece
  hit: {}

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
