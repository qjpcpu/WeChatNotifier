define ['module','change-case','cson','path'], (module,Cc,Cson,path) ->
  Cson.load path.join(path.dirname(module.uri),'config.cson')
