"use strict"

_ = require('underscore')
fs = require('fs')
cp = require('child_process')
path = require('path')
YAML = require('yamljs')

adb = require('../adb')
config = require('../config')
pubsub = require('../pubsub')

jobs = []

saveJson = (filename, data) ->
  fs.writeFile filename, JSON.stringify(data, null, 2), (err) ->

removeJob = (job) ->
  index = jobs.indexOf job
  jobs.splice index, 1 if index >= 0
  pubsub.pub 'job'

addJob = (job) ->
  jobs.push job
  pubsub.pub 'job'

jobsInfo = -> jobs: (job.job_info for job in jobs)

module.exports = exports = jobApi =
  jobsInfo: jobsInfo

  create: (req, res) ->
    repo = req.param('repo')
    job_id = req.params.job_id or require('node-uuid').v4()
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
      job_path = path.join config.jobs.path, job_id
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
          proc = cp.spawn job_script, [], detached: true
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
          job = proc: proc, job_info: result
          addJob job
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

  get: (req, res) ->
    job_id = req.params.job_id
    res.sendfile path.join(config.jobs.path, req.param('job_id'), 'job.json')

  list: (req, res) ->
    result = jobsInfo()
    if req.param('all') not in ['true', '1']
      res.json result
    else
      fs.readdir config.jobs.path, (err, files) ->
        files = _.map(files, (f) -> path.join(config.jobs.path, f, 'job.json')).filter (f) -> fs.existsSync(f)
        result.all = _.map files, (f) ->
          delete require.cache[f]
          require(f)
        res.json result

  cancel: (req, res) ->
    job = _.find jobs, (job) -> job.job_info.job_id is req.params.job_id
    if job
      process.kill -job.proc.pid, 'SIGTERM'
      res.send 200
    else
      res.send 410, 'The requested job is already dead!'

  files: (req, res) ->
    filename = path.join config.jobs.path, req.params.job_id, req.params[0]
    fs.stat filename, (err, stats) ->
      return res.send 404 if err

      if stats.isFile()
        res.sendfile filename
      else if stats.isDirectory()
        fs.readdir filename, (err, files) ->
          return res.send 500 if err
          result = for file in files
            st = fs.statSync path.join(filename, file)
            name: file, is_dir: st.isDirectory(), create_time: st.ctime.getTime()/1000, modify_time: st.mtime.getTime()/1000, size: st.size
          res.json files: result
      else
        res.send 500

  delete_files: (req, res) ->
    for job in jobs when job.job_info.job_id is req.params.job_id
      return res.send 409, 'The specified job is running!'
    require('rimraf') path.join(config.jobs.path, req.params.job_id), (err) ->
      res.send if err then 500 else 200

  stream: (req, res) ->
    lines = Number(req.param('lines')) or 40
    job = _.find jobs, (job) -> job.job_info.job_id is req.params.job_id
    job_out = path.join config.jobs.path, req.params.job_id, 'output'
    tail = if job
      cp.spawn 'tail', ["--lines=#{lines}", "--pid=#{job.proc.pid}", "-f", job_out]
    else
      cp.spawn 'tail', ["--lines=#{lines}", job_out]
    timer = setInterval ->
      res.write '\0'
    , 5000
    tail.stdout.on 'data', (data) ->
      res.write data
    tail.on 'close', (code, signal) ->
      clearInterval timer
      res.end()
    res.on 'close', ->
      tail.kill()
