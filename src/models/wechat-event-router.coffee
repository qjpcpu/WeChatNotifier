define [
  'debug'
  'change-case'
  'restler'
  'conf/config'
  'models/wechat'
  ], (
  debug
  Cc
  rest
  Config
  WeChat
) ->
  log = debug 'wcn:wechat-router'
  class WeChatEventRouter
    handle: (entity,cb) ->
      evt = Cc.lowerCase entity.event
      wechatConfig = Config.getApp(entity.agentId)
      events = wechatConfig.events
      unless events[evt]
        log 'Swallow event', entity
        return cb(null,'')
      return cb("no such event handler: #{events[evt].type}") unless events[evt].type in ['text','callback']
      return cb(null,events[evt].words or '') if events[evt].type == 'text'
      return cb('no callback url') unless events[evt].url

      url = events[evt].url

      if wechatConfig.callbackToken?.length > 0
        chat = new WeChat(entity.agentId)
        sig = chat.calSignature wechatConfig.callbackToken
        url = "#{url}?timestamp=#{sig.timestamp}&nonce=#{sig.nonce}&signature=#{sig.signature}"

      log "forword message to #{url}",entity
      rest.postJson(url,
        entity
        { timeout: 4000 }
      ).on('timeout', (ms) ->
        log 'request timeout, maybe you request a wrong url',url
        cb 'request timeout'
      ).on 'complete', (result) ->
        if result instanceof Error
          log 'err ocurrs',result
          cb result
        else
          log "get response",result
          cb null,result
