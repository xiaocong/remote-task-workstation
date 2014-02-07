"use strict"

adb = require('./adb')
cp = require('child_process')
# im = require('imagemagick')
gm = require('gm')

module.exports = exports =
  list: (req, res) ->
    result = 'android': []
    adb.devices req.query.status or 'all', (err, devices) ->
      count = 0
      for serial, name of devices
        count += 1
      if count is 0
        return res.json result
      for serial, name of devices
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
          if count is 0
            res.json result
        result.android.push device

  screenshot: (req, res) ->
    height = Number(req.query.height or 0)
    width = Number(req.query.width or 0)
    if height is 0 and width is 0
      width = height = 480
    cp.exec "adb -s #{req.params.serial} shell screencap -p | sed s/\r$//", {maxBuffer: 16*1024*1024, encoding: 'binary'}, (error, stdout, stderr) ->
      gm(new Buffer(stdout, 'binary'), 'screen.png').resize(width, height).stream (err, stdout, stderr) ->
        stdout.pipe res
        res.type 'png'
      # im.resize
      #     srcData: new Buffer(stdout, 'binary')
      #     width: width
      #     height: height
      #     format: 'png'
      #   , (err, stdout, stderr) ->
      #     res.type 'png'
      #     res.send  new Buffer(stdout, 'binary')
