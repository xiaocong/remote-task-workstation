"use strict"

cp = require('child_process')

cmd = (timeout, cmd_line, callback) ->
  cmd_line = "adb #{cmd_line}"
  cp.exec cmd_line, {timeout: timeout*1000}, callback

module.exports = exports =
  devices: (status, callback) ->
    cp.exec 'adb devices', (error, stdout, stderr) ->
      devices = {}
      return callback(error, devices) if error

      error_statuses = ['offline', 'no permissions', 'unauthorized']
      lines = stdout.split(/[\n\r]+/)
      for line in lines when m = line.match(/([\w\d]+)\t([\d\s\w]+)/)
        if status in ['ok', 'ready', 'good', 'alive'] and m[2] not in error_statuses
          devices[m[1]] = m[2]
        else if status in ['error', 'err', 'bad'] and m[2] in error_statuses
          devices[m[1]] = m[2]
        else if status is 'all'
          devices[m[1]] = m[2]
      callback null, devices

  getprop: (serial, prop, callback) ->
    if typeof prop is 'string'
      cmd_line = "-s #{serial} shell getprop #{prop}"
      cmd 5, cmd_line, (error, stdout, stderr) ->
        callback error, stdout.toString().trim(), stderr.toString().trim()
    else
      callback = prop
      cmd_line = "-s #{serial} shell getprop"
      cmd 5, cmd_line, (error, stdout, stderr) ->
        return callback error, {} if error

        props = {}
        lines = stdout.split '\n'
        for line in lines when m = line.match(/\[([^[\]]+)\]: +\[([^[\]]+)\]/)
          props[m[1]] = m[2]
        callback error, props

  cmd: cmd
