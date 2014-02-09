"use strict"

path = require('path')

module.exports = exports =
  port: process.env.PORT or 3000
  jobs: 
    path: path.join(__dirname, '..', 'jobs')
    init_script: '.init.yml'
  reg_server: process.env.REGSERVER_URL or 'http://localhost:3100/ws-proxy'