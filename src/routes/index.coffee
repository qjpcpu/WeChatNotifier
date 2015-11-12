define [
  'express'
  'debug'
  'module'
  'conf/config'
  'models/wechat'
  'xml2js'
  'models/database'
  'node-uuid'
  'moment'
  'url-parse'
], (
  express
  debug
  module
  config
  WeChat
  xml2js
  database
  uuid
  moment
  urlParse
) ->
  router = express.Router()
  log = debug('http')

  router.get '/', (req, res) ->
    locals = {
      title: config.auth?.strings?.title or 'Scan QRCode in WeChatNotifier to login'
      qrcode: (new Buffer(Math.random().toString() + uuid.v1().toString())).toString('base64')
    }
    log req.session
    if req.query.id and req.query.redirect_uri
      database.getJson "identifiers:#{req.query.id}", (gerr,value) ->
        if gerr
          log "Can't find id:#{req.query.id}",gerr
          res.render 'index',locals
        else
          locals.id = req.query.id
          redirectUri = req.query.redirect_uri
          if req.query.state
            url = urlParse(req.query.redirect_uri,true)
            url.query.state = req.query.state
            redirectUri = url.toString()
          if req.session.user
            ticket = (new Buffer(uuid.v1())).toString('base64')
            redirectUri = urlParse redirectUri,true
            redirectUri.query.ticket = ticket
            database.putJson "ticket:#{ticket}", { timestamp: moment().unix(),fromUser: req.session.user }, (err) ->
              log "redirect to #{redirectUri.toString()}"
              res.redirect redirectUri.toString()
          else
            locals.qrcode = 'login:' + locals.qrcode
            log locals
            database.putJson "qrcode:#{locals.qrcode}",{ timestamp: moment().unix(),id: req.query.id, redirectUri: redirectUri }, (err) ->
              res.render 'index', locals
    else if req.session.user
      locals.user = req.session.user.name
      locals.qrcode = req.session.user.name
      res.render 'index', locals            
    else
      res.render 'index',locals

  router.post '/check_login', (req,res) ->
    qrcode = req.body.loginCode
    unless qrcode?.length > 0
      res.status(403).json message: 'invalid login code',errcode: 1
      return
    unless /^login:/.test qrcode
      res.status(403).json message: 'invalid login code',errcode: 1
      return
    database.getJson "qrcode:#{qrcode}",(err,value) ->
      if err
        res.status(403).json message: 'no such login code',errcode: 2
      else if moment().unix() - value.timestamp > (config.auth?.qrcodeExpireSec or 300)
        res.status(403).json message: 'login code expired',errcode: 3
      else if value.fromUser? and value.redirectUri?.length > 0
        ticket = (new Buffer(uuid.v1())).toString('base64')
        redirectUri = urlParse value.redirectUri,true
        redirectUri.query.ticket = ticket
        arr = [
          { type: 'del',key: "qrcode:#{qrcode}" }
          { type: 'put',key: "ticket:#{ticket}",value: { timestamp: moment().unix(),fromUser: value.fromUser },valueEncoding: 'json' }
        ]        
        database.batch arr, (err) ->
          req.session.user = value.fromUser
          res.json ticket: ticket,redirect_uri: redirectUri.toString(),message: 'login ok',errcode: 0
      else if not value.fromUser?
        res.json message: 'need scan qrcode',errcode: 4
      else
        res.status(403).json message: 'login code failed',errcode: 5

  router.post '/validate', (req,res) ->
    token = req.query.accessToken
    unless token 
      log "No accessToken found in request"
      res.status(403).json message: 'no access token found'
      return
    ticket = req.body.ticket
    unless ticket
      log "No ticket found in request"
      res.status(403).json message: 'no ticket found'
      return    
    database.getJson "credentials:#{token}", (terr,value) ->
      if terr
        log "fetch access token config failed",terr
        res.status(403).json message: 'no valid access token'
      else      
        database.getJson "ticket:#{ticket}",(err,value) ->
          if err
            res.status(403).json message: 'ticket does not exists'
          else if moment().unix() - value.timestamp > (config.auth?.ticketExpireSec or 60)
            database.del "ticket:#{ticket}",(delerr) ->
              res.status(403).json message: 'ticket expired'
          else if value.fromUser?
            database.del "ticket:#{ticket}",(delerr) ->
              res.json value.fromUser
          else
            database.del "ticket:#{ticket}",(delerr) ->
              res.status(403).json message: 'bad ticket'


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
