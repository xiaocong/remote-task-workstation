"use strict"

fs = require('fs')
os = require('os')
io = require('socket.io-client')
request = require('request')
zookeeper = require('node-zookeeper-client')
Backbone = require('backbone')
_ = require('underscore')

logger = require('./logger')
config = require('./config')
devices = require('./api/devices')
pubsub = require('./pubsub')

require("http").globalAgent.maxSockets = 10000  # bull shit, default is 5!!!

ip = do ->
  ifaces = os.networkInterfaces()
  for dev, addrs of ifaces when dev isnt 'lo'
    for addr in addrs when addr.family is 'IPv4' and addr.address isnt '127.0.0.1'
      return addr.address

serverUrl = "http://localhost:#{config.port}"

getInfo = do ->
  info =
    mac: fs.readFileSync('/sys/class/net/eth0/address').toString().trim()
    owner: config.owner
    api:
      status: 'up'
      jobs: []
      devices:
        android: []
  require('child_process').exec 'uname -n -m -o', (err, stdout, stderr) ->
    info.uname = stdout.toString().trim()
  (cb) ->
    request.get {url: "#{serverUrl}/api/0/jobs", json: true}, (err, res, jobs) ->
      if not err and res.statusCode is 200
        info.api.jobs = jobs.jobs
      else
        info.api.jobs = []
      request.get {url: "#{serverUrl}/api/0/devices", json: true, qs: {status: 'good'}}, (err, res, devices) ->
        if not err and res.statusCode is 200
          info.api.devices = devices
        else
          info.api.devices =
            android: []
        cb info

module.exports = exports = reg =
  register: ->
    if config.zk.url
      reg.regToZookeeperServer()
    else if config.reg_server
      reg.regToHttpServer()
    else
      console.error 'Reg server was not defined!'
      process.exit(-1)

  regToHttpServer: ->
    socket = io.connect(config.reg_server)
    iostream = require('socket.io-stream')

    register = (cb) ->
      getInfo (info) ->
        try
          socket.emit 'register', info, cb
        catch error
          logger.error "Error during emitting register msg: #{error}"


    registered = false
    update = ->
      logger.debug 'Update workstation info.....'
      getInfo (info) ->
        logger.debug 'Sending info to server.'
        try
          socket.emit('update', info) if registered
        catch error
          logger.error "Error during emitting update msg: #{error}"

    socket.on 'error', (err) ->
      logger.error "Socket error: #{err}"

    socket.on 'disconnect', ->
      console.info 'SocketIO disconnected!'
      registered = false
      iostream(socket).removeAllListeners 'http'

    requests = {}
    socket.on 'close-http-response', (options) ->
      logger.debug "Local request #{options.id} aborts!"
      requests["#{options.id}"]?.abort()

    socket.on 'connect', ->
      console.info 'SocketIO connected!'
      callback = (options) ->
        if options.returncode isnt 0
          console.error 'Registering error!'
          setTimeout ->
            console.info 'Retry register!'
            register(callback) if not registered
          , 10000
        else
          console.info 'Registering successfully!'
          registered = true
          intervalId = setInterval update, 10000
          pubsub.sub 'job', update
          clear = ->
            console.info 'Remove interval updates.'
            clearInterval intervalId
            pubsub.unsub 'job', update
            socket.removeListener 'disconnect', clear
          socket.on 'disconnect', clear
      register(callback) if not registered

      iostream(socket).on 'http', (body, options) ->
        logger.debug "Received http request on #{options.path}, id: #{options.id}"
        headers = {}
        headers[key] = value for key, value of options.headers when key in ['content-type', 'accept']
        rawData = ''
        body.on 'data', (chunk) ->
          rawData += chunk
        body.on 'end', ->
          logger.debug "Request body is '#{rawData}', id: #{options.id}"
          opt =
            url: "#{serverUrl}#{options.path}"
            method: options.method or 'GET'
            qs: options.query or ''
            headers: headers
            body: rawData
          req = request(opt)
          requests["#{options.id}"] = req
          stream = iostream.createStream()
          stream.on 'end', ->
            logger.debug "Stream #{options.id} ended!"
            delete requests["#{options.id}"]
          req.on('error', (err) ->
            stream.end(err)
          ).pipe stream
          req.on 'response', (response) ->
            logger.debug "Begin responding to request id: #{options.id}"
            try
              iostream(socket).emit 'response', stream,
                statusCode: response.statusCode
                headers: response.headers
                id: options.id
            catch error
              logger.error "Error during emitting strem response msg: #{error}"


  regToZookeeperServer: ->
    zk = zookeeper.createClient(config.zk.url)
    zk.connect()
    zk.on 'connected', ->
      zk.mkdirp config.zk.root, (err) ->
        return process.exit(-1) if err
        zk_point = (mac) ->
          "#{config.zk.root}/#{mac}"

        createZkNode = ->
          getInfo (msg) ->
            getApi = (msg) ->
              status: msg.api.status
              path: "/api"
              port: config.port
              jobs: msg.api.jobs ? []
              devices:
                android: msg.api.devices?.android ? []

            zkNodeInfo = new Backbone.Model
              ip: ip,
              mac: msg.mac
              uname: msg.uname
              owner: msg.owner
              api: getApi(msg)

            zk.create zk_point(msg.mac), new Buffer(JSON.stringify zkNodeInfo.toJSON()), zookeeper.CreateMode.EPHEMERAL, (err, path) ->
              return setTimeout createZkNode, 10000 if err

              zkNodeInfo.on 'change', (event) ->
                zk.setData path, new Buffer(JSON.stringify zkNodeInfo.toJSON()), (err, stat) ->
                  console.log(err) if err

              update = ->
                getInfo (msg) ->
                  zkNodeInfo.set 'api', getApi(msg)
              intervalId = setInterval update, 10000
              pubsub.sub 'job', update
              zk.once 'disconnect', ->
                clearInterval intervalId
                pubsub.unsub 'job', update
                zkNodeInfo.off 'change'

        createZkNode()