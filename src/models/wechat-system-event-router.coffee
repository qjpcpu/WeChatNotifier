define [
  'debug'
  'change-case'
  'restler'
  'conf/config'
  'models/wechat'
  'models/database'
  'moment'
  'async'
  ], (
  debug
  Cc
  rest
  Config
  WeChat
  database
  moment
  async
) ->
  log = debug 'wcn:wechat-router'
  class WeChatSystemEventRouter
    handle: (entity,cb) ->
      evt = Cc.lowerCase entity.event
      # system login
      if evt == 'scancode_waitmsg' and entity.eventKey == 'system_login' and entity.scanCodeInfo.ScanType == 'qrcode' and /^login:/.test(entity.scanCodeInfo.ScanResult)
        key = 'qrcode:' + entity.scanCodeInfo.ScanResult
        database.getJson key, (err,value) ->
          if err
            cb(null,'')
          else
            if value.fromUser
              database.del key, (errdel) -> cb(null,'Can not scan a login code twice!')
            else
              async.waterfall [
                ((acb) ->
                  database.getJson "wechat:app_#{entity.agentId}", (err,wechatToken) ->
                    if wechatToken?.token?.length and moment() < moment(wechatToken?.expiredAt) and (not err?)
                      acb(null,wechatToken.token)
                    else
                      chat = new WeChat entity.agentId
                      chat.fetchAccessToken (err,token,expiredAt) ->
                        database.putJson "wechat:app_#{entity.agentId}", { token: token, expiredAt: expiredAt.toJSON() }, (lerr) ->
                          acb(null,token)                  
                )
                ((token,acb) ->
                  chat = new WeChat entity.agentId
                  chat.user { accessToken: token,id: entity.fromUser }, (uerr,user) ->
                    if uerr
                      log "no such user #{entity.fromUser}",uerr
                      acb "no such user #{entity.fromUser}"
                    else
                      acb(null,user)                 
                )
              ], (asyncErr,user) ->
                value.fromUser = user
                database.putJson key,value,(perr) -> cb(null,"Welcome, #{user.name}!")
      else 
        cb null,''