define [
  'models/wechat-event-router'
  'models/wechat-msg-router'
  'conf/config'
  ], (
  WeChatEventRouter
  WeChatMsgRouter
  config
) ->
  class WeChatRouter
    handle: (entity,cb) ->
      switch entity.msgType
        when 'event' then (new WeChatEventRouter()).handle entity,cb
        else (new WeChatMsgRouter()).handle entity,cb
