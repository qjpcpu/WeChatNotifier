define [
  'express'
  'debug'
  'module'
  'conf/config'
  'models/wechat'
  'xml2js'
  'models/database'
  'node-uuid'
], (
  express
  debug
  module
  config
  WeChat
  xml2js
  database
  uuid
) ->
  router = express.Router()
  log = debug('http')

  router.get '/', (req, res) ->
    res.render 'index', title: 'WeChatNotifier'

  router.post '/exchange_token', (req,res) ->
    token = req.query.accessToken
    unless token 
      log "No accessToken found in request"
      res.status(403).json message: 'no access token found'
      return
    database.getJson "credentials:#{token}", (err,value) ->
      if err
        log "fetch access token config failed",err
        res.status(403).json message: 'no valid access token'
      else
        key = (new Buffer(uuid.v1())).toString('base64')
        arr = [
          { type: 'del',key:"credentials:#{token}" }
          { type: 'put',key:"credentials:#{key}",value: value,valueEncoding: 'json' }
        ]
        database.batch arr, (err) ->
          unless err
            log 'update token OK'
            res.json { message: 'update token ok',token: key }
          else
            log 'update token failed',err
            res.status(403).json message: 'update token failed'
       
  
  module.exports = router
