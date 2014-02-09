
###
Module dependencies.
###
express = require('express')
http = require('http')
path = require('path')

config = require('./lib/config')

app = express()

# all environments
app.set 'port', config.port
app.set 'views', path.join(__dirname, 'views')
app.set 'view engine', 'ejs'

app.use express.favicon()
app.use express.logger('dev')
app.use express.json()
app.use express.urlencoded()
app.use express.methodOverride()
app.use app.router
# app.use express.static(path.join(__dirname, 'jobs'))

# development only
app.use express.errorHandler()  if 'development' is app.get('env')

require('./lib/api')(app)

http.createServer(app).listen app.get('port'), ->
  console.log 'Express server listening on port ' + app.get('port')

require('./lib/workstation').regToHttpServer()