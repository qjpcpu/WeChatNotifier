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
      return cb("no such event handler: #{events[evt].type}") unless events[evt].type in ['text','callback']
      return cb(null,events[evt].words or '') if events[evt].type == 'text'
      return cb('no callback url') unless Config.callback?.url

      url = Config.callback.eventUrl or Config.callback.url
      return cb('no callback found')  unless url
      if Config.callback.token?.length > 0
        sig = WeChat.calSignature Config.callback.token
        url = "#{url}?timestamp=#{sig.timestamp}&nonce=#{sig.nonce}&signature=#{sig.signature}"

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
