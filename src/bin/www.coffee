requirejs = require('../requirejs')

requirejs ['debug','http','app'], (debug,http,app) ->
  debug = debug('wechatnotifier:server')

  normalizePort = (val) ->
    port = parseInt(val, 10)
    return val if isNaN(port)
    return port if port >= 0
    false
  
  port = normalizePort(process.env.PORT or '8000')
  
  onError = (error) ->
    if error.syscall != 'listen'
      throw error
    bind = if typeof port == 'string' then 'Pipe ' + port else 'Port ' + port
    # handle specific listen errors with friendly messages
    switch error.code
      when 'EACCES'
        console.error bind + ' requires elevated privileges'
        process.exit 1
      when 'EADDRINUSE'
        console.error bind + ' is already in use'
        process.exit 1
      else
        throw error
  
  ###*
  # Event listener for HTTP server "listening" event.
  ###
  
  onListening = ->
    addr = server.address()
    bind = if typeof addr == 'string' then 'pipe ' + addr else 'port ' + addr.port
    debug 'Listening on ' + bind
    return
  
  app.set 'port', port
  
  ###*
  # Create HTTP server.
  ###
  
  server = http.createServer(app)
  
  ###*
  # Listen on provided port, on all network interfaces.
  ###
  
  server.listen port
  server.on 'error', onError
  server.on 'listening', onListening

  process.on 'uncaughtException', (err) ->
    console.error((new Date).toUTCString() + ' uncaughtException:', err.message)
    console.error(err.stack)
    process.exit(1)
