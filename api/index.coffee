"use strict"

devices = require('./devices')

module.exports = exports = (app) ->
  app.get '/api/ping', (req, res) -> res.send 'pong'
  app.get '/api/0/devices', devices.list
  app.get '/api/0/devices/:serial/screenshot', devices.screenshot