define ['module','change-case','cson','path'], (module,Cc,Cson,path) ->
  conf = Cson.load path.join(path.dirname(module.uri),'config.cson')
  # override wechat configurations with environment variables
  conf.wechat.token = process.env.WECHAT_TOKEN or conf.wechat.token
  conf.wechat.encodingAesKey = process.env.WECHAT_AESKEY or conf.wechat.encodingAesKey

  conf