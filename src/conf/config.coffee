define ['module','change-case','cson','path'], (module,Cc,Cson,path) ->
  conf = Cson.load path.join(path.dirname(module.uri),'config.cson')
  unless conf.db
    dbFile = path.join(path.dirname(module.uri),'../data/db.level')
    conf.db = path: dbFile
  conf