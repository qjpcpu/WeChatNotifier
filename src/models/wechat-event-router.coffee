define [
  'debug'
  'change-case'
  'restler'
  'conf/config'
  'models/wechat'
  'models/database'
  ], (
  debug
  Cc
  rest
  Config
  WeChat
  database
) ->
  log = debug 'wcn:wechat-router'
  class WeChatEventRouter
    handle: (entity,cb) ->
      evt = Cc.lowerCase entity.event
      # system login
      if evt == 'scancode_waitmsg' and entity.eventKey == 'system_login' and entity.scanCodeInfo.ScanType == 'qrcode' and /^login:/.test(entity.scanCodeInfo.ScanResult)
        key = 'qrcode:' + entity.scanCodeInfo.ScanResult
        database.getJson key, (err,value) ->
          if err
            cb(null,'')
          else
            if value.fromUser?.length > 0
              database.del key, (errdel) -> cb(null,'Can not scan a login code twice!')
            else
              value.fromUser = entity.fromUser
              database.putJson key,value,(perr) -> cb(null,'login ok')
        return 
      # system login
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
