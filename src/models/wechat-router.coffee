define [
  'models/wechat-event-router'
  'models/wechat-system-event-router'
  'models/wechat-msg-router'
  'conf/config'
  'change-case'
  ], (
  WeChatEventRouter
  WeChatSytemEventRouter
  WeChatMsgRouter
  config
  Cc
) ->
  class WeChatRouter
    handle: (entity,cb) ->
      switch entity.msgType
        when 'text' then  (new WeChatMsgRouter()).handle entity,cb
        when 'event'
          evt = Cc.lowerCase entity.event
          if /^system_/.test(entity.eventKey)
            (new WeChatSytemEventRouter()).handle entity,cb
          else 
            (new WeChatEventRouter()).handle entity,cb
        else cb("no router for #{entity.msgType}")
