define ['async','express','module','debug','models/database','models/wechat','conf/config'],(async,express,module,debug,database,WeChat,Config) ->
  router = express.Router()
  debug = debug 'http'

  router.get '/', (req, res, next) ->
    res.send 'respond with a resource'
 
  router.post '/alias', (req,res,next) ->
    data = req.body
    return res.status(403).json(message: 'no alias name') unless data.alias
    return res.status(403).json(message: 'no user found') unless data.userId
    async.waterfall [
      ((callback) ->
        database.getJson 'wechatToken', (err,wechatToken) ->
          if wechatToken?.token?.length and moment() < moment(wechatToken?.expiredAt) and (not err?)
            callback null,wechatToken.token
          else
            WeChat.fetchAccessToken (err,token,expiredAt) ->
              database.putJson 'wechatToken', { token: token, expiredAt: expiredAt.toJSON() }
              callback null,token     
      )    
    ],(err,token) ->
      if err
        debug 'failed to fetch token',err
        res.status(403).json message: 'failed to fetch token'
      else
        WeChat.aliasUser token,{openid: data.userId,remark: data.alias }, (err1) ->
          if err1
            debug 'failed to alias user',err1
            res.status(403).json message: 'failed to alias user'
          else
            res.send ''

  router.post '/attach_role', (req,res,next) ->
    data = req.body
    return res.status(403).json(message: 'no role specified') unless data.role
    return res.status(403).json(message: 'no users found') unless data.users
    database.getJson "role:#{data.role}", (err,list) ->
      list = [] if err
      for u in data.users
        list.push u unless u in list
      database.putJson "role:#{data.role}", list
      res.json message: 'ok'

  router.post '/detach_role', (req,res,next) ->
    data = req.body
    return res.status(403).json(message: 'no role specified') unless data.role
    return res.status(403).json(message: 'no users found') unless data.users
    database.getJson "role:#{data.role}", (err,list) ->
      return res.json(message: 'ok') if err
      result = (u for u in list when u not in data.users)
      database.putJson "role:#{data.role}", result
      res.json message: 'ok'

  router.post '/send_message', (req,res,next) ->
    data = req.body
    async.series [
      ((callback) ->
        if data.msgType then callback() else callback('no message type')
      )
      ((callback) ->
        unless Config.wechat.templates[data.msgType] then callback('no such message type') else callback()
      )
      ((callback) ->
        unless data.data then callback('no payload') else callback()
      )            
      ((callback) ->
        if data.role
          database.getJson "role:#{data.role}", (err,users) ->  
            data.users = users unless err
            callback null,data.users
        else
          callback null,data.users      
      )
      ((callback) ->
        if data.users?.length then callback(null,data.users) else callback('no user found')
      )
      ((callback) ->
        database.getJson 'wechatToken', (err,wechatToken) ->
          if wechatToken?.token?.length and moment() < moment(wechatToken?.expiredAt) and (not err?)
            req.body.wechatToken = wechatToken.token
            callback null,wechatToken.token
          else
            WeChat.fetchAccessToken (err,token,expiredAt) ->
              database.putJson 'wechatToken', { token: token, expiredAt: expiredAt.toJSON() }
              req.body.wechatToken = token
              callback null,token     
      )
    ], (err,results) ->
      if err
        res.status(403).json message: err
      else
        opts =
          to: data.users
          type: data.msgType
          data: data.data
        WeChat.sendTplMessage data.wechatToken,opts,(err,msg) ->
          res.json message: 'ok'

  module.exports = router            