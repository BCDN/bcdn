Contents = require './Contents'
TrackerConnection = require './TrackerConnection'

exports = module.exports = class Peer
  constructor: (options, callbacks) ->
    default_options =
      key: 'bcdn'
    default_options extends options

    {trackers, key} = options

    @contents = new Contents()
    @trackerConn = new TrackerConnection trackers, key

    # report error
    @trackerConn.on 'ERROR', (payload) ->
      {msg} = payload
      @constructor.error msg

    # save peer id after joined
    @trackerConn.on 'JOINED', (payload) ->
      {id} = payload
      @constructor.info "tracker has accepted the join request, peer ID: #{id}"
