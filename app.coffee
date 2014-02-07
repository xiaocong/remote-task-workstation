
###
Module dependencies.
###
express = require('express')
http = require('http')
path = require('path')

app = express()

# all environments
app.set 'port', process.env.PORT or 3000
app.set 'views', path.join(__dirname, 'views')
app.set 'jobs', express.static(path.join(__dirname, 'jobs'))
app.set 'view engine', 'jade'
app.use express.favicon()
app.use express.logger('dev')
app.use express.json()
app.use express.urlencoded()
app.use express.methodOverride()
app.use app.router
# app.use express.static(path.join(__dirname, 'jobs'))

# development only
app.use express.errorHandler()  if 'development' is app.get('env')

require('./api')(app)

http.createServer(app).listen app.get('port'), ->
  console.log 'Express server listening on port ' + app.get('port')

