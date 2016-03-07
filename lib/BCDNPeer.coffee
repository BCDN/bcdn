Peer = require './Peer'
Contents = require './Contents'
TrackerConnection = require './TrackerConnection'

exports = module.exports = class BCDNPeer
  constructor: (options, callbacks) ->
    # parse options
    default_options =
      key: 'bcdn'
    default_options extends options

    {trackers, key} = options


    # initialize variables
    @peer = new Peer key
    @contents = new Contents()
    @trackerConn = new TrackerConnection trackers, @peer
    # TODO: add PeerManager


    # report error on tracker connection error
    @trackerConn.on 'ERROR', (payload) ->
      {msg} = payload
      @error msg


    # save peer id after joined the network
    @trackerConn.on 'JOINED', (payload) ->
      {id} = payload
      @peer.id = id
      @info "tracker has accepted the join request, peer ID: #{@peer.id}"
