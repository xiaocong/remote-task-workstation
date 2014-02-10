"use strict"

fs = require('fs')
io = require('socket.io-client')
request = require('request')

config = require('./config')
devices = require('./api/devices')
jobs = require('./api/jobs')

module.exports = exports =
  regToHttpServer: ->
    serverUrl = "http://localhost:#{config.port}"
    socket = io.connect(config.reg_server)
    iostream = require('socket.io-stream')
    ss = iostream(socket)
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

    socket.on 'connect', ->
      callback = (options) ->
        if options.returncode isnt 0
          return setTimeout ->
            register callback
          , 10000
        else
          timeoutId = setInterval update, 10000
          socket.on 'disconnect', -> clearTimeout timeoutId
      register callback

    register = (cb) ->
      getInfo (info) ->
        socket.emit 'register', info, cb

    update = ->
      getInfo (info) ->
        socket.emit 'update', info

    getInfo = do ->
      info = 
        mac: fs.readFileSync('/sys/class/net/eth0/address').toString().trim()
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
