define ['async','express','module','debug','models/database','models/wechat','conf/config','merge'],(async,express,module,debug,database,WeChat,Config,merge) ->
  router = express.Router()
  log = debug 'http'

  router.use  (req,res,next) ->
    token = req.query.accessToken
    unless token 
      log "No accessToken found in request"
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
  # query:
  # departmentId: default=1
  # detail: show detail,default=false
  # recursive: fetch chidren,default=yes|true
  # status: all/watched/disabled/unwatched, default: watched
  router.get '/', (req, res) ->
    chat = new WeChat res.locals.agentId
    opts = 
      accessToken: res.locals.accessToken
      departmentId: req.query.departmentId
      detail: (req.query.detail in ['yes','true'])
      recursive: (req.query.recursive in [undefined,'yes','true'])
      status: req.query.status
    chat.users opts,(err,list) ->
      if err
        log "failed to get users",err
        res.json  []
      else
        res.json list

  router.post '/', (req,res) ->
    user = req.body
    async.waterfall [
      ((callback) ->
        if user.email
          user.id = user.email.replace /@.*/,'' unless user.id
          callback() 
        else 
          callback('No user email')
      )   
    ],(err) ->
      if err
        log 'failed to create user',err
        res.status(403).json message: err
      else
        log "create user: #{user}"
        user.accessToken = res.locals.accessToken
        chat = new WeChat(res.locals.agentId)
        chat.createUser user, (err1) ->
          log "ressss",err1
          if err1
            log 'failed to create user',err1
            res.status(403).json message: err1
          else
            res.json message: 'OK'


  router.post '/send', (req,res) ->
    chat = new WeChat res.locals.agentId
    req.body.type ?= 'text'
    unless req.body.type in ['text','news']
      log "Not supported message type #{req.body.type}"
      return res.status(403).json message: "Not supported message type #{req.body.type}"
    unless req.body.body
      log 'message body not found',req.body
      return res.status(403).json message: 'message body not found'
    if (not req.body.users) and (not req.body.tagIds) and (not req.body.departmentIds)
      log "tagId/users/departmentIds not found"
      return res.status(403).json message: 'tagId/users/departmentIds not found'
    opts = merge req.body, {accessToken: res.locals.accessToken,appId: res.locals.agentId }
    chat.sendMessage opts, (err) ->
      if err
        log "send message failed",err
        res.status(403).json message: err
      else
        res.json message: 'OK' 

  router.get '/:userId', (req,res) ->
    chat = new WeChat res.locals.agentId
    chat.user {accessToken: res.locals.accessToken,id: req.params.userId}, (err,user) ->
      if err
        log "no such user #{req.params.userId}",err
        res.status(404).json message: "no such user #{req.params.userId}"
      else
        res.json user  

  router.put '/:userId', (req,res) ->
    chat = new WeChat res.locals.agentId
    user = merge req.body,{accessToken: res.locals.accessToken,id: req.params.userId}
    chat.updateUser user, (err) ->
      if err
        log "no such user #{req.params.userId}",err
        res.status(404).json message: "no such user #{req.params.userId}"
      else
        res.json message: 'OK'  

  router.get '/:userId/invite', (req,res) ->
    chat = new WeChat res.locals.agentId
    chat.inviteUser {accessToken: res.locals.accessToken,id: req.params.userId}, (err) ->
      if err
        log "cannt invite user #{req.params.userId}",err
        res.status(403).json message: err
      else
        res.json message: 'OK' 

  router.delete '/:userId', (req,res) ->
    chat = new WeChat res.locals.agentId
    chat.deleteUser {accessToken: res.locals.accessToken,id: req.params.userId}, (err) ->
      if err
        log "can not del user #{req.params.userId}",err
        res.status(404).json message: err
      else
        res.json message: 'OK'

  # opts:
  # type: 消息类型,default to text
  # users/tagIds/departmentIds(Array/String)(Optional)
  # body(object/Array/string)
  router.post '/:userId/send', (req,res) ->
    chat = new WeChat res.locals.agentId
    req.body.type ?= 'text'
    unless req.body.type in ['text','news']
      log "Not supported message type #{req.body.type}"
      return res.status(403).json message: "Not supported message type #{req.body.type}"
    unless req.body.body
      log 'message body not found',req.body
      return res.status(403).json message: 'message body not found'
    req.body.users = [req.params.userId]
    if (not req.body.users) and (not req.body.tagIds) and (not req.body.departmentIds)
      log "tagId/users/departmentIds not found"
      return res.status(403).json message: 'tagId/users/departmentIds not found'
    opts = merge req.body, {accessToken: res.locals.accessToken,appId: res.locals.agentId }
    chat.sendMessage opts, (err) ->
      if err
        log "send message failed",err
        res.status(403).json message: err
      else
        res.json message: 'OK'      


  module.exports = router            