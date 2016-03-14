EventEmiter = require 'events'

Task = require './Task'

logger = require 'debug'

exports = module.exports = class DownloadManager extends EventEmiter
  debug: logger 'DownloadManager:debug'

  constructor: (options) ->
    {@threads} = options

    # tasks[hash] => Task
    @tasks = {}

    # task controls
    @wait = []
    @running = new Set()
    @done = new Set()

  queue: (hash) ->
    return task if (task = @tasks[hash])?

    @debug "queue task for downloading #{hash}"
    task = @tasks[hash] = new Task hash
    @wait.push hash

    @run()

    return task

  prepare: (hash, resource) ->
    task = @tasks[hash]
    task.deserialize resource
    task.missing = new Set(task.pieces)
    task.prepared()
    @debug "prepare resource index (hash=#{task.hash}," +
           "pieces=[#{task.pieces[0..2]}," +
           "(length=#{task.pieces.length})...])"

  run: ->
    while (@running.size < @threads) and (hash = @wait.shift())
      @running.add hash

      @emit 'ready', @tasks[hash]
