"use strict"

path = require('path')

module.exports = exports =
  port: process.env.PORT or 3031
  jobs: 
    path: path.join(__dirname, '..', 'jobs')
    init_script: '.init.yml'
  reg_server: process.env.REGSERVER_URL
  zk:
    root: process.env.ZK_ROOT or '/remote/alive/workstation'
    url: process.env.ZK_URL
