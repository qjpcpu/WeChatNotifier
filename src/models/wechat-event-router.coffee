define [
  'debug'
  '../conf/config'
  ], (
  debug
  config
) ->
  log = debug 'wechat-router'
  class WeChatEventRouter
    handle: (entity,cb) ->
      log 'do nothing now'
      cb()
