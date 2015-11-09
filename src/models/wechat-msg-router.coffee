define [
  'debug'
  'conf/config'
  'models/wechat'
  'restler'
  'async'
  ], (
  debug
  Config
  WeChat
  rest
  async
) ->
  log = debug 'wcn:wechat-router'
  class WeChatMsgRouter
    handle: (entity,cb) ->
      wechatConfig = Config.getApp(entity.agentId)
      unless wechatConfig
        log 'no wechat app found'
        return cb(null,'')
      async.waterfall [
        ((callback) ->
          if wechatConfig.messages?.length > 0
            for c in wechatConfig.messages
              if c.match? and (new RegExp(c.match)).test entity.content
                return callback(null,c)
              else if c.equals? and c.equals == entity.content
                return callback(null,c)
            callback 'no messages handler matched'
          else
            callback 'no messages handler'
        )
      ], (err,cfg) ->
        if err
          log 'error happens',err
          cb null,''
        else
          switch cfg.type
            when 'text'
              cb null,cfg.words
            else # 'callback'
              url = cfg.url
              if wechatConfig.callbackToken?.length > 0
                sig = (new WeChat(entity.agentId)).calSignature wechatConfig.callbackToken
                url = "#{url}?timestamp=#{sig.timestamp}&nonce=#{sig.nonce}&signature=#{sig.signature}"

              log "forword message to #{url}",entity
              rest.postJson(url,
                entity
                { timeout: 4000 }
              ).on('timeout',(ms) ->
                log 'request timeout, maybe you request a wrong url',url
                cb 'request timeout'
              ).on 'complete', (result) ->
                if result instanceof Error
                  log 'err ocurrs',result
                  cb result
                else
                  log "get response",result
                  cb null,result
