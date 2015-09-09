define [
  'debug'
  'change-case'
  'restler'
  '../conf/config'
  './wechat'
  ], (
  debug
  Cc
  rest
  Config
  WeChat
) ->
  log = debug 'wechat-router'
  class WeChatEventRouter
    handle: (entity,cb) ->
      evt = Cc.lowerCase entity.event
      events = Config.wechat.events
      unless events[evt]
        log 'Swallow event', entity
        return cb(null,'')
      return cb('no such event handler type') unless events[evt] in ['text','callback']
      return cb(null,events[evt].words or '') if events[evt] == 'text'
      return cb('no callback url') unless Config.callback?.url

      url = Config.callback.eventUrl or Config.callback.url
      return cb('no callback found')  unless url
      if Config.callback.token?.length > 0
        sig = WeChat.calSignature Config.callback.token
        url = "#{url}?timestamp=#{sig.timestamp}&nonce=#{sig.nonce}&signature=#{sig.signature}"

      rest.postJson(url,
        entity
      ).on 'complete', (result) ->
        if result instanceof Error
          log 'err ocurrs',result
          cb result
        else
          log "get response",result
          cb null,result
