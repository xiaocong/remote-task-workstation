"use strict"

devices = require('./devices')
jobs = require('./jobs')

module.exports = exports = (app) ->
  app.get '/api/ping', (req, res) -> res.send 'pong'
  
  app.get '/api/0/devices', devices.list
  app.get '/api/0/devices/:serial/screenshot0', devices.screenshot
  app.get '/api/0/devices/:serial/screenshot', devices.screenshot2

  app.post '/api/0/jobs/:job_id', jobs.create
  app.post '/api/0/jobs', jobs.create
  app.get '/api/0/jobs/:job_id', jobs.get
  app.get '/api/0/jobs/:job_id/init_script/:script_name', jobs.init_script
  app.get '/api/0/jobs', jobs.list
  app.get '/api/0/jobs/:job_id/stop', jobs.cancel
  app.delete '/api/0/jobs/:job_id', jobs.cancel
  app.get '/api/0/jobs/:job_id/files/*', jobs.files
  app.delete '/api/0/jobs/:job_id/files', jobs.delete_files
  app.get '/api/0/jobs/:job_id/remove_files', jobs.delete_files
  app.get '/api/0/jobs/:job_id/stream', jobs.stream
