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

  router.get '/', (req, res) ->
    chat = new WeChat res.locals.agentId
    chat.departments {accessToken: res.locals.accessToken,id: req.query.parentId },(err,list) ->
      if err
        log "failed to get departments",err
        res.json  []
      else
        res.json list

  router.post '/', (req, res) ->
    unless req.body.name
      log "no department name"
      res.status(403).json message: 'no department name'
      return
    chat = new WeChat res.locals.agentId
    chat.createDepartment {accessToken: res.locals.accessToken,parentId: req.body.parentId,name: req.body.name },(err) ->
      if err
        log "failed to create department",err
        res.status(403).json message: err
      else
        res.json message: 'OK'        

  router.put '/:id', (req, res) ->
    chat = new WeChat res.locals.agentId
    chat.updateDepartment {accessToken: res.locals.accessToken,id: req.params.id,parentId: req.body.parentId,name: req.body.name },(err) ->
      if err
        log "failed to update department",err
        res.status(403).json message: err
      else
        res.json message: 'OK'

  router.delete '/:id', (req, res) ->
    chat = new WeChat res.locals.agentId
    chat.deleteDepartment {accessToken: res.locals.accessToken,id: req.params.id },(err) ->
      if err
        log "failed to del department",err
        res.status(403).json message: err
      else
        res.json message: 'OK'

  router.get '/:id/users', (req, res) ->
    chat = new WeChat res.locals.agentId
    chat.users {accessToken: res.locals.accessToken,recursive: (req.query.recursive in [undefined,'yes','true']),departmentId: req.params.id },(err,list) ->
      if err
        log "failed to get department users",err
        res.status(403).json message: err
      else
        res.json list

  router.delete '/:id/:userId', (req, res) ->
    chat = new WeChat res.locals.agentId
    chat.user { accessToken: res.locals.accessToken,id: req.params.userId }, (err,user) ->
      if err
        log 'failed to get user',err
        res.status(403).json message: err
      else
        departments = (d for d in user.department when d != parseInt(req.params.id))
        if departments.length == 0
          return res.status(403).json message: "#{req.params.userId} must belong to at least one department."
        chat.updateUser { accessToken: res.locals.accessToken, id: req.params.userId, departmentIds: departments }, (derr) ->
          if derr
            res.status(403).json message: derr
          else 
            res.json message: 'OK'

  router.post '/:id/:userId', (req, res) ->
    chat = new WeChat res.locals.agentId
    chat.user { accessToken: res.locals.accessToken,id: req.params.userId }, (err,user) ->
      if err
        log 'failed to get user',err
        res.status(403).json message: err
      else
        if parseInt(req.params.id) in user.department
          log "user #{req.params.userId} already in this department"
          return res.json message: 'OK'
        user.department.push  parseInt(req.params.id)
        chat.updateUser { accessToken: res.locals.accessToken, id: req.params.userId, departmentIds: user.department }, (derr) ->
          if derr
            res.status(403).json message: derr
          else 
            res.json message: 'OK'                   

  module.exports = router            