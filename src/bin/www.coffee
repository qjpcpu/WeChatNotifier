requirejs = require('../requirejs')

requirejs ['debug','http','app','cluster','os','models/database'], (debug,http,app,cluster,os,database) ->
  log = debug('wechatnotifier:server')

  normalizePort = (val) ->
    port = parseInt(val, 10)
    return val if isNaN(port)
    return port if port >= 0
    false
  
  port = normalizePort(process.env.PORT or '8002')
  
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
  
  onListening = ->
    addr = server.address()
    bind = if typeof addr == 'string' then 'pipe ' + addr else 'port ' + addr.port
    log 'Listening on ' + bind
    return
  
  app.set 'port', port
  
  if cluster.isMaster
    log "main proccess start..."
    database.startServe()
    for i in [1..os.cpus().length]
      cluster.fork()
    cluster.on 'listening', (worker,address) ->
      log "listening: worker #{worker.process.pid}, Address: #{address.address}:#{address.port}"
    cluster.on 'exit', (worker,code,signal) ->
      log "worker: #{worker.process.pid} died"
  else
    database.connect()
    
    server = http.createServer(app)
    
    server.listen port
    server.on 'error', onError
    server.on 'listening', onListening

    process.on 'uncaughtException', (err) ->
      console.error((new Date).toUTCString() + ' uncaughtException:', err.message)
      console.error(err.stack)
      process.exit(1)
