define [
  'debug'
  'levelup'
  '../conf/config'
  ], (
  debug
  levelup
  config
) ->
  log = debug 'db'
  db = levelup config.db.path
  log "connect to database #{config.db.path}"
  db: -> db
  getJson: (key,callback) -> db.get key,{valueEncoding: 'json'},callback
  putJson: (key,val,callback) -> db.put key,val,{valueEncoding: 'json'},callback
