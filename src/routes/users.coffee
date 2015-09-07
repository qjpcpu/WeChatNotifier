define ['express','module','debug','../models/database','../models/wechat','../conf/config'],(express,module,debug,database,WeChat,Config) ->
  router = express.Router()
  debug = debug 'http'

  router.use '/send_message',(req,res,next) ->
    database.getJson 'wechatToken', (err,wechatToken) ->
      if wechatToken?.token?.length and moment() < moment(wechatToken?.expiredAt) and (not err?)
        req.body.wechatToken = wechatToken.token
        next() 
      else
        WeChat.fetchAccessToken (err,token,expiredAt) ->
          database.putJson 'wechatToken', { token: token, expiredAt: expiredAt.toJSON() }
          req.body.wechatToken = token
          next()

  router.get '/', (req, res, next) ->
    res.send 'respond with a resource'
    
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
    return res.status(403).json(message: 'no message type') unless data.msgType
    return res.status(403).json(message: 'no such message type') unless Config.wechat.templates[data.msgType]
    return res.status(403).json(message: 'no data') unless data.data    
    if data.role
      database.getJson "role:#{data.role}", (err,users) ->  
        data.users = users unless err  
        return res.status(403).json(message: 'no users found') unless data.users
        opts =
          to: data.users
          type: data.msgType
          data: data.data
        WeChat.sendTplMessage data.wechatToken,opts,(err,msg) ->
          res.json message: 'ok'        
    else 
      return res.status(403).json(message: 'no users found') unless data.users
      opts =
        to: data.users
        type: data.msgType
        data: data.data
      WeChat.sendTplMessage data.wechatToken,opts,(err,msg) ->
        res.json message: 'ok'
        


  module.exports = router            