"use strict"

adb = require('../adb')
cp = require('child_process')
gm = require('gm')
_ = require('underscore')
path = require('path')

devicesInfo = (status, callback) ->
  result = android: []
  adb.devices status or 'all', (err, devices) ->
    count = 0
    for serial, name of devices
      count += 1
    return callback result if count is 0

    _.each devices, (name, serial) ->
      device = 'adb': {'serial': serial, 'device': name}
      adb.getprop serial, (err, props) ->
        if not err
          device.product =
            'brand': props['ro.product.brand']
            'manufacturer': props['ro.product.manufacturer']
            'model': props['ro.product.model']
            'board': props['ro.product.board']
            'device': props['ro.product.device']
          device.locale =
            'language': props['ro.product.locale.language']
            'region': props['ro.product.locale.region']
          device.build =
            'fingerprint': props['ro.build.fingerprint']
            'type': props['ro.build.type']
            'date_utc': props['ro.build.date.utc']
            'display_id': props['ro.build.display.id']
            'id': props['ro.build.id']
            'version':
              'incremental': props['ro.build.version.incremental']
              'release': props['ro.build.version.release']
              'sdk': props['ro.build.version.sdk']
              'codename': props['ro.build.version.codename']
        count -= 1
        callback(result) if count is 0
      result.android.push device

module.exports = exports =
  devicesInfo: devicesInfo

  list: (req, res) ->
    devicesInfo req.query.status or 'all', (info) ->
      res.json info

  screenshot: (req, res) ->
    height = Number(req.query.height or 0)
    width = Number(req.query.width or 0)
    if height is 0 and width is 0
      width = height = 480
    cp.exec "adb -s #{req.params.serial} shell screencap -p | sed s/\r$//", {maxBuffer: 16*1024*1024, encoding: 'binary'}, (error, stdout, stderr) ->
      gm(new Buffer(stdout, 'binary'), 'screen.png').resize(width, height).toBuffer (err, buffer) ->
        res.type 'png'
        res.send buffer
      # gm(new Buffer(stdout, 'binary'), 'screen.png').resize(width, height).stream (err, stdout, stderr) ->
      #   stdout.pipe res
      #   res.type 'png'

  screenshot2: (req, res) ->
    height = Number(req.query.height or 0)
    width = Number(req.query.width or 0)
    if height is 0 and width is 0
      width = height = 480
    png_file = path.join '/tmp', "#{new Date().getTime().toString()}.png"
    cp.exec "java -classpath #{path.join(__dirname, 'jar', 'ddms.jar')}:#{path.join(__dirname, 'jar', 'screenshot.jar')} com.android.screenshot.Screenshot -s #{req.params.serial} #{png_file}", (error, stdout, stderr) ->
      return res.send 500 if error
      gm(png_file).resize(width, height).toBuffer (err, buffer) ->
        res.type 'png'
        res.send buffer
        cp.exec "rm #{png_file}"
      # gm(png_file).resize(width, height).stream (err, stdout, stderr) ->
      #   stdout.pipe res
      #   res.type 'png'
      #   cp.exec "rm #{png_file}"
