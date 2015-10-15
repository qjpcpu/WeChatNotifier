define [
  'debug'
  'level'
  'conf/config'
  'multilevel'
  'net'
  ], (
  debug
  level
  config
  multilevel
  net
) ->
  log = debug 'wechatnotifier:db'
  database = {}
  startServe: ->
    database.db = level config.db.path
    log "database listen on :#{config.db.port}..."  
    net.createServer((con) ->
      con.pipe(multilevel.server(database.db)).pipe(con)
    ).listen config.db.port

  connect: -> 
    unless database.db
      database.db = multilevel.client()
      con = net.connect(config.db.port)
      con.pipe(database.db.createRpcStream()).pipe(con)
      log "connect to database ok"
    database.db 

  get: (key,callback) ->
    me = this
    me.connect() unless database.db
    database.db.get key, callback
       
  getJson: (key,callback) -> 
    me = this
    me.connect() unless database.db
    database.db.get key,{valueEncoding: 'json'},callback 

  put: (key,val,callback) -> 
    me = this
    me.connect() unless database.db  
    database.db.put key,val,callback

  putJson: (key,val,callback) -> 
    me = this
    me.connect() unless database.db  
    database.db.put key,val,{valueEncoding: 'json'},callback


  del: (key,callback) -> 
    me = this
    me.connect() unless database.db  
    database.db.del key,callback  

  # arr is:
  # [{type: 'del',key:'k'},{type: 'put',key:'ke',value: {a: 1}}]
  batch: (arr,callback) -> 
    me = this
    me.connect() unless database.db 
    op.valueEncoding = 'json' for op in arr when typeof op.value == 'object'
    database.db.batch arr,callback

  keys: (callback,opts) ->
    me = this
    me.connect() unless database.db
    list = []
    database.db.createKeyStream(opts)
      .on 'data', (key) -> list.push key
      .on 'close', -> callback(list)

  records: (callback,opts) ->
    me = this
    me.connect() unless database.db
    list = []
    if opts?.prefix
      opts.start = opts.prefix
      opts.end = "#{opts.prefix}\xFF"
    database.db.createReadStream(opts)
      .on 'data', (data) -> list.push data
      .on 'close', -> callback(list)

  jsonRecords: (callback,opts) ->
    me = this
    me.connect() unless database.db
    list = []
    opts ?= {}
    opts.valueEncoding = 'json'
    if opts?.prefix
      opts.start = opts.prefix
      opts.end = "#{opts.prefix}\xFF"
    database.db.createReadStream(opts)
      .on 'data', (data) -> list.push data
      .on 'close', -> callback(list)      

