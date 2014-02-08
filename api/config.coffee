"use strict"

path = require('path')

module.exports = exports =
  port: process.env.PORT or 3000
  jobs: 
    path: path.join(__dirname, '..', 'jobs')
    init_script: '.init.yml'