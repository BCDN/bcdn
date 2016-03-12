PeerConnection = require './PeerConnection'

logger = require 'debug'

exports = module.exports = class PeerManager
  verbose: logger 'PeerManager:verbose'
  debug: logger 'PeerManager:debug'
  info: logger 'PeerManager:info'

  peers: {}

  constructor: (@self, options) ->
    {@wrtc} = options

  processSignal: (detail) ->
    {from, signal} = detail
    @peers[from].signal signal

  accept: (id, cb) ->
    # ignore self or connected peers
    return if id is @self.id or id in Object.keys @peers

    peerConn = @peers[id] = new PeerConnection id, wrtc: @wrtc
    peerConn.on 'signal', (data) =>
      @verbose "signal #{id}: #{data}"
      cb 'signal', data
    peerConn.on 'connect', =>
      @info "connected from #{id}"
      cb 'connect'
    peerConn.on 'data', (data) =>
      @verbose "got data from #{id}: #{data}"
      cb 'data', data

  connect: (id, cb) ->
    # ignore self or connected peers
    return if id is @self.id or id in Object.keys @peers
    @info "connect to #{id}..."

    peerConn = @peers[id] = new PeerConnection id, initiator: true, wrtc: @wrtc
    peerConn.on 'signal', (data) =>
      @verbose "signal #{id}: #{data}"
      cb 'signal', data
    peerConn.on 'connect', =>
      @info "connected to #{id}"
      cb 'connect'
    peerConn.on 'data', (data) =>
      @verbose "got data from #{id}: #{data}"
      cb 'data', data
