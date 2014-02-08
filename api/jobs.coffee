"use strict"

_ = require('underscore')
fs = require('fs')
cp = require('child_process')
path = require('path')
YAML = require('yamljs')

adb = require('./adb')
config = require('./config')

jobs = []

saveJson = (filename, data) ->
  fs.writeFileSync filename, JSON.stringify(data, null, 2)

removeJob = (job) ->
  index = jobs.indexOf job
  jobs.splice index, 1 if index >= 0

module.exports = exports =
  create: (req, res) ->
    repo = req.param('repo')
    job_id = req.param('job_id') or require('node-uuid').v4()
    if not repo
      return res.send 400, '"repo" is a mandatory parameter for creating a new job!'
    exclusive = req.param('exclusive') not in ['false', 'f', 'False']
    env = req.param('env') or {}
    env.ANDROID_SERIAL ?= 'no_device'

    if exclusive and _.some(jobs, (job) -> job.job_info.env.ANDROID_SERIAL is env.ANDROID_SERIAL and job.job_info.exclusive)
      return res.send 409, 'A job on device with the same ANDROID_SERIAL is running!'

    adb.devices 'ok', (err, devices) ->
      if env.ANDROID_SERIAL not of devices and env.ANDROID_SERIAL isnt 'no_device'
        return res.send 404, 'No specified device attached!'
      if _.some(jobs, (job) -> job.job_info.job_id is job_id)
        return res.send 409, 'A job with the same job_id is running! If you want to re-run the job, please stop the running one firestly.'
      job_path = "#{config.jobs.path}/#{job_id}"
      require('rimraf').sync(job_path)
      fs.mkdirSync(job_path)
      workspace = "#{job_path}/workspace"
      fs.mkdirSync(workspace)
      env.JOB_ID = job_id
      env.WORKSPACE = workspace

      [local_repo, job_out, job_script, job_info] = ("#{job_path}/#{f}" for f in ['repo', 'output', 'run.sh', 'job.json'])
      res.render('run_script',
          repo: repo
          local_repo: local_repo
          init_script: "http://localhost:#{config.port}/api/0/jobs/#{job_id}/init_script/#{repo.init_script or config.jobs.init_script}"
          env: env
        , (err, data) ->
          return res.send 500, err if err
          fs.writeFileSync job_script, data, mode: 0o776
          proc = cp.spawn job_script
          start_time = new Date()
          result =
            repo: repo
            job_id: job_id
            job_pid: proc.pid
            job_path: job_path
            env: env
            exclusive: exclusive
            started_at: start_time.getTime()/1000
            started_datetime: start_time.toString()
          job = 'proc': proc, 'job_info': result
          jobs.push job
          saveJson job_info, result
          proc.stdout.on 'data', (data) ->
            fs.appendFile job_out, data, (err) ->
          proc.stderr.on 'data', (data) ->
            fs.appendFile job_out, data, (err) ->
          proc.on 'close', (code, signal) ->
            removeJob job
            result.exit_code = code
            result.signal = signal if signal
            end_time = new Date()
            result.finished_at = end_time.getTime()/1000
            result.finished_datetime = end_time.toString()
            saveJson job_info, result
          res.json result
      )

  init_script: (req, res) ->
    init_script = path.join config.jobs.path, req.param('job_id'), 'repo', req.param('script_name')
    init_json = YAML.load init_script
    res.render 'init_script', init: init_json
