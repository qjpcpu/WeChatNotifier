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
        res.locals.role = val.role
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
    chat = new WeChat res.locals.agentId
    return res.status(401).json(message: 'no enough previledge') unless chat.canRead('tag',res.locals.role)    
    chat.tags { accessToken: res.locals.accessToken },(err,list) ->
      if err
        log "failed to get roles",err
        res.json  []
      else
        regex = new RegExp "^#{res.locals.agentId}_"
        list = (
          for r in list when regex.test(r.name)
            r.name = r.name.replace(regex,'')
            r
        )
        res.json list

  router.post '/', (req,res) ->
    chat = new WeChat res.locals.agentId
    return res.status(401).json(message: 'no enough previledge') unless chat.canWrite('tag',res.locals.role)
    unless req.body.name
      log "cannt found role name"
      return res.status(403).json message: "cannot find role name"
    req.body.name = "^#{res.locals.agentId}_#{req.body.name}"
    chat.createTag { accessToken: res.locals.accessToken,name: req.body.name },(err,role) ->
      if err
        res.status(403).json message: err
      else
        regex = new RegExp "^#{res.locals.agentId}_"
        role.name = role.name.replace regex,''
        res.json role

  router.delete '/:id', (req,res) ->
    chat = new WeChat res.locals.agentId
    return res.status(401).json(message: 'no enough previledge') unless chat.canWrite('tag',res.locals.role)
    chat.deleteTag { accessToken: res.locals.accessToken,id: req.params.id },(err,role) ->
      if err
        res.status(403).json message: err
      else
        res.json message: 'OK'

  router.get '/:id/users', (req, res) ->
    chat = new WeChat res.locals.agentId
    return res.status(401).json(message: 'no enough previledge') unless chat.canRead('tag',res.locals.role)
    chat.usersByTag { accessToken: res.locals.accessToken,id: req.params.id }, (err,list) ->
      if err
        log 'failed to get users',err
        res.status(403).json message: err
      else
        res.json list

  router.post '/:id/attach', (req, res) ->
    chat = new WeChat res.locals.agentId
    return res.status(401).json(message: 'no enough previledge') unless chat.canWrite('tag',res.locals.role)
    unless req.body.users
      return res.status(403).json message: 'no user found'
    chat.attachTag { accessToken: res.locals.accessToken,tagId: req.params.id,users: req.body.users }, (err) ->
      if err
        log 'failed to attach role to user',err
        res.status(403).json message: err
      else
        res.json message: 'OK'

  router.post '/:id/detach', (req, res) ->
    chat = new WeChat res.locals.agentId
    return res.status(401).json(message: 'no enough previledge') unless chat.canWrite('tag',res.locals.role)
    unless req.body.users
      return res.status(403).json message: 'no user found'
    chat.detachTag { accessToken: res.locals.accessToken,tagId: req.params.id,users: req.body.users }, (err) ->
      if err
        log 'failed to attach role to user',err
        res.status(403).json message: err
      else
        res.json message: 'OK'        

  module.exports = router            