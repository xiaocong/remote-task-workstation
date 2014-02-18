"use strict"

fs = require('fs')
os = require('os')
io = require('socket.io-client')
request = require('request')
zookeeper = require('node-zookeeper-client')
Backbone = require('backbone')
_ = require('underscore')

config = require('./config')
devices = require('./api/devices')
jobs = require('./api/jobs')

ip = do ->
  ifaces = os.networkInterfaces()
  for dev, addrs of ifaces when dev isnt 'lo'
    for addr in addrs when addr.family is 'IPv4' and addr.address isnt '127.0.0.1'
      return addr.address

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
    info.api.jobs = jobs.jobsInfo().jobs
    devices.devicesInfo 'good', (result) ->
      info.api.devices = result
      cb info

module.exports = exports = register =
  register: ->
    if config.zk.url
      register.regToZookeeperServer()
    else if config.reg_server
      register.regToHttpServer()
    else
      console.error 'Reg server was not defined!'
      process.exit(-1)

  regToHttpServer: ->
    serverUrl = "http://localhost:#{config.port}"
    socket = io.connect(config.reg_server)
    iostream = require('socket.io-stream')

    register = (cb) ->
      getInfo (info) ->
        socket.emit 'register', info, cb

    update = ->
      getInfo (info) ->
        socket.emit 'update', info

    socket.on 'connect', ->
      callback = (options) ->
        if options.returncode isnt 0
          return setTimeout ->
            register callback
          , 10000
        else
          intervalId = setInterval update, 10000
          socket.on 'disconnect', -> clearInterval intervalId
      register callback

      ss = iostream(socket)
      socket.on 'disconnect', ->
        ss.removeAllListeners()
      ss.on 'http', (body, options) ->
        headers = {}
        headers[key] = value for key, value of options.headers when key in ['content-type', 'accept']
        rawData = ''
        body.on 'data', (chunk) ->
          rawData += chunk
        body.on 'end', ->
          opt =
            url: "#{serverUrl}#{options.path}"
            method: options.method or 'GET'
            qs: options.query or ''
            headers: headers
            body: rawData
          req = request(opt)
          stream = iostream.createStream()
          req.on('error', (err) ->
            stream.end(err)
          ).pipe stream
          req.on 'response', (response) ->
            ss.emit 'response', stream,
              statusCode: response.statusCode
              headers: response.headers
              id: options.id

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

              intervalId = setInterval ->
                  getInfo (msg) -> zkNodeInfo.set 'api', getApi(msg)
                , 10000
              zk.once 'disconnect', ->
                clearInterval intervalId
                zkNodeInfo.off 'change'

        createZkNode()