define [
  'debug'
  'conf/config'
  'models/wechat'
  'restler'
  'async'
  'models/tuling'
  ], (
  debug
  Config
  WeChat
  rest
  async
  Tuling
) ->
  log = debug 'wechat-router'
  class WeChatMsgRouter
    handle: (entity,cb) ->
      async.waterfall [
        ((callback) ->
          if Config.wechat.messages?.length > 0
            cfg = null
            for c in Config.wechat.messages
              if c.match and (new RegExp(c.match).test entity.content
                cfg = c
                callback null,cfg
                break
              else if c.equals and c.equals == entity.content
                cfg = c
                callback null,cfg
                break
            callback('no matched message') unless cfg
          else
            callback('swallow messge')
        )
      ], (err,cfg) ->
        if err
          log 'error happens',err
          cb null,''
        else
          switch cfg.type
            when 'text'
              cb null,cfg.words
            when 'tuling'
              Tuling.ask entity.fromUser,entity.content, (result) -> cb(null,result)
            else # 'callback'
              url = Config.callback.messageUrl or  Config.callback.url
              return cb('no callback found')  unless url
              if Config.callback.token?.length > 0
                sig = WeChat.calSignature Config.callback.token
                url = "#{url}?timestamp=#{sig.timestamp}&nonce=#{sig.nonce}&signature=#{sig.signature}"
        
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
