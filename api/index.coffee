"use strict"

devices = require('./devices')
jobs = require('./jobs')

module.exports = exports = (app) ->
  app.get '/api/ping', (req, res) -> res.send 'pong'
  
  app.get '/api/0/devices', devices.list
  app.get '/api/0/devices/:serial/screenshot', devices.screenshot
  app.post '/api/0/jobs/:job_id', jobs.create
  app.get '/api/0/jobs/:job_id/init_script/:script_name', jobs.init_script