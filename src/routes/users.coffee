define ['async','express','module','debug','models/database','models/wechat','conf/config'],(async,express,module,debug,database,WeChat,Config) ->
  router = express.Router()
  log = debug 'http'

  router.use  (req,res,next) ->
    token = req.query.access_token
    unless token 
      log "No access_token found in request"
      res.status(403).json message: 'no access token found'
      return
    database.getJson "credentials:#{token}", (err,val) ->
      if err
        log "fetch access token config failed",err
        res.status(403).json message: 'no valid access token'
      else
        res.locals.agentId = val.agentId
        next()

  router.use (req,res,next) ->
    database.getJson "wechat:app_#{res.locals.agentId}", (err,wechatToken) ->
      if wechatToken?.token?.length and moment() < moment(wechatToken?.expiredAt) and (not err?)
        res.locals.accessToken = wechatToken.token
        next()
      else
        chat = new WeChat res.locals.agentId
        chat.fetchAccessToken (err,token,expiredAt) ->
          database.putJson "wechat:app_#{res.locals.agentId}", { token: token, expiredAt: expiredAt.toJSON() }, (lerr) ->
            res.locals.accessToken = token
            next()

  router.get '/', (req, res) ->
    log res.locals
    res.send 'empty'


  router.post '/create', (req,res) ->
    user = req.body
    async.waterfall [
      ((callback) ->
        if user.email
          user.id = user.email.replace /@.*/,''
          callback() 
        else 
          callback('No user email')
      )       
      ((callback) ->
        if user.mobile then callback() else callback('No user mobile')
      )    
    ],(err) ->
      if err
        log 'failed to create user',err
        res.status(403).json message: err
      else
        log "create user: #{user}"
        user.accessToken = res.locals.accessToken
        chat = new WeChat(res.locals.agentId)
        chat.createUser user, (err1,data) ->
          if err1
            log 'failed to create user',err1
            res.status(403).json message: err1
          else
            res.status(200)
 
  router.post '/alias', (req,res) ->
    data = req.body
    return res.status(403).json(message: 'no alias name') unless data.alias
    return res.status(403).json(message: 'no user found') unless data.userId
    async.waterfall [
      ((callback) ->
        refreshToken callback
      )    
    ],(err,token) ->
      if err
        log 'failed to fetch token',err
        res.status(403).json message: 'failed to fetch token'
      else
        WeChat.aliasUser token,{openid: data.userId,remark: data.alias }, (err1) ->
          if err1
            log 'failed to alias user',err1
            res.status(403).json message: 'failed to alias user'
          else
            res.send ''

  router.post '/attach_role', (req,res) ->
    data = req.body
    return res.status(403).json(message: 'no role specified') unless data.role
    return res.status(403).json(message: 'no users found') unless data.users
    database.getJson "role:#{data.role}", (err,list) ->
      list = [] if err
      for u in data.users
        list.push u unless u in list
      database.putJson "role:#{data.role}", list
      res.json message: 'ok'

  router.post '/detach_role', (req,res) ->
    data = req.body
    return res.status(403).json(message: 'no role specified') unless data.role
    return res.status(403).json(message: 'no users found') unless data.users
    database.getJson "role:#{data.role}", (err,list) ->
      return res.json(message: 'ok') if err
      result = (u for u in list when u not in data.users)
      database.putJson "role:#{data.role}", result
      res.json message: 'ok'

  router.post '/send_message', (req,res) ->
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

  router.get '/:userId', (req,res) ->
    chat = new WeChat res.locals.agentId
    log req.params
    chat.user {accessToken: res.locals.accessToken,id: req.params.userId}, (err,user) ->
      if err
        log "no such user #{req.params.userId}",err
        res.status(404).json message: "no such user #{req.params.userId}"
      else
        res.json user      

  module.exports = router            