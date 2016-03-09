Peer = require './Peer'
Contents = require './Contents'
TrackerConnection = require './TrackerConnection'
ResourceManager = require './ResourceManager'

logger = require 'debug'

exports = module.exports = class BCDNPeer
  debug: logger 'BCDNPeer:debug'
  info: logger 'BCDNPeer:info'
  error: logger 'BCDNPeer:error'

  constructor: (options, callbacks) ->
    # parse options
    default_options =
      key: 'bcdn'
    default_options extends options

    {trackers, key} = options


    # initialize variables
    @peer = new Peer key
    @contents = new Contents()
    @resources = new ResourceManager()
    @trackerConn = new TrackerConnection trackers, @peer
    # TODO: add PeerManager


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
        if resource.auto or @resources.get(resource.hash)?
          @trackerConn.queryResource resource.hash

      @debug "contents has been updated: #{@contents.serialize()}"
    # resource index received
    @trackerConn.on 'INDEX', (payload) => @resources.updateIndex payload
