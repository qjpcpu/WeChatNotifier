define [
  'debug'
  '../conf/config'
  './wechat'
  'restler'
  ], (
  debug
  Config
  WeChat
  rest
) ->
  log = debug 'wechat-router'
  class WeChatMsgRouter
    handle: (entity,cb) ->
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
