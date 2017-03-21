EventEmiter = require 'events'

Task = require './Task'

logger = require 'debug'

# Manager for schedule and run download tasks.
#
# @extend EventEmiter
class DownloadManager extends EventEmiter
  # @property [Number] number of concurrent threads for downloading.
  threads: null
  # @property [Object<String, Task>] task table indexed by resource hash of the task (Object<resourceHash, task>).
  tasks: null
  # @property [Array<String>] resource hashes for waiting tasks.
  wait: null
  # @property [Set<String>] set of resources hashes for running tasks.
  running: null
  # @property [Set<String>] set of resources hashes for finished tasks.
  done: null

  # Create a download manager instance.
  #
  # @param [Object<String, ?>] options options from {BCDNPeer} for initialize this download manager.
  constructor: (options) ->
    {@threads} = options

    # FIXME: move them to class properties, WARNING: new Set should initialize here!
    # tasks[hash] => Task
    @tasks = {}

    # task controls
    @wait = []
    @running = new Set()
    @done = new Set()

  # Queue a unique task for downloading by the resource hash, and returns the task object.
  #
  # @param [String] hash hash value of the resource.
  # @return [Task] the task object queued.
  queue: (hash) ->
    return task if (task = @tasks[hash])?

    @info "-- queue task[hash=#{hash}] for downloading"
    task = @tasks[hash] = new Task hash
    @wait.push hash

    @run()

    return task

  # Prepare the resource index for a download task, and notify the task.
  #
  # @param [String] hash hash value of the resource.
  # @param [String] resource serialized resource object.
  # @return [Task] the task object prepared.
  prepare: (hash, resource) ->
    # prepare the resource index only if the task exists.
    task = @tasks[hash]
    return unless !!task

    task.prepare resource

    return task

  # Initiates download threads in FCFS (first-come, first-serve) policy.
  run: ->
    while (@running.size < @threads) and (hash = @wait.shift())
      @running.add hash

      @emit 'ready', @tasks[hash]

  info: logger 'DownloadManager:info'

exports = module.exports = DownloadManager
