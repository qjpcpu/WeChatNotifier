define [
    'module'
    'express'
    'path'
    'serve-favicon'
    'morgan'
    'fs'
    'file-stream-rotator'
    'cookie-parser'
    'cookie-session'
    'body-parser'
    'routes/index'
    'routes/users'
    'routes/roles'
    'routes/departments'
    'routes/wechat'
    'conf/config'
  ], (
    module
    express
    path
    favicon
    logger
    fs
    FileStreamRotator
    cookieParser
    cookieSession
    bodyParser
    routes
    users
    roles
    departments
    wechat
    appConfig
) ->
  app = express()
  
  # view engine setup
  app.set 'views', path.join(path.dirname(), 'views')
  app.set 'view engine', 'jade'
  
  # uncomment after placing your favicon in /public
  #app.use(favicon(path.join(path.dirname(), 'public', 'favicon.ico')));

  unless app.get('env') == 'development'
    logDirectory = path.dirname() + '/logs'
    fs.existsSync(logDirectory) || fs.mkdirSync(logDirectory)
    accessLogStream = FileStreamRotator.getStream
      filename: logDirectory + '/access-%DATE%.log'
      frequency: 'daily'
      verbose: false
      date_format: "YYYY-MM-DD"
    app.use logger('combined', {stream: accessLogStream})
  else
    app.use logger 'dev'

  app.use bodyParser.json()
  app.use bodyParser.urlencoded(extended: false)
  app.use cookieParser()
  app.use cookieSession {
    secret: 'sOZ9bakJhS8CnNCotHlnI4Jpv5dqFmHlcjOBJ'
    cookie: { secure: true, maxAge: 60 * 60 * (appConfig.auth?.cookieExpireHour or 48) }
  }
  app.use express.static(path.join(path.dirname(), 'public'))
  app.use '/', routes
  app.use '/users', users
  app.use '/roles', roles
  app.use '/departments', departments
  app.use '/wechat',wechat
  
  # catch 404 and forward to error handler
  app.use (req, res, next) ->
    err = new Error('Not Found')
    err.status = 404
    next err
    return
  # error handlers
  # development error handler
  # will print stacktrace
  if app.get('env') == 'development'
    app.use (err, req, res, next) ->
      res.status err.status or 500
      res.render 'error',
        message: err.message
        error: err
      return
  # production error handler
  # no stacktraces leaked to user
  app.use (err, req, res, next) ->
    res.status err.status or 500
    res.render 'error',
      message: err.message
      error: {}
    return
  module.exports = app
  
