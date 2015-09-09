define [
  'debug'
  '../conf/config'
  ], (
  debug
  config
) ->
  log = debug 'wechat-router'
  class WeChatMsgRouter
    handle: (entity,cb) ->
      log 'do nothing now'
      cb()
