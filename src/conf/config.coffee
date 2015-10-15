define ['module','change-case','cson','path','debug'], (module,Cc,Cson,path,debug) ->
  conf = Cson.load path.join(path.dirname(module.uri),'config.cson')
  log = debug('conf')
  unless conf.db
    dbFile = path.join(path.dirname(module.uri),'../data/db.level')
    conf.db = 
      path: dbFile
      port: 9346
  log 'get conf',conf
  conf