define [
    'clone'
    'js2xmlparser'
    'express-xml-bodyparser'
    'express'
    'debug'
    'module'
    'change-case'
    'models/wechat'
    'models/wechat-router'
    'conf/config'
  ], (
    clone
    js2xmlparser
    xmlparser
    express
    debug
    module
    Cc
    WeChat
    WeChatRouter
    config
) ->
  router = express.Router()
  debug = debug('http')
  
  router.use '/callback',xmlparser({trim: false,normalize: false,normalizeTags: false, explicitArray: false}), (req,res,next) ->
    if (not req.query.echostr?) and (not req.body.xml?)
      res.status(403).json(message: 'invalid request')
      return
    validReq = WeChat.validateUrl
      timestamp: req.query.timestamp
      nonce: req.query.nonce
      signature: req.query.msg_signature
      message: req.query.echostr or req.body.xml
    unless validReq
      res.status(403).json(message: 'invalid wechat source server')
    else
      if req.query.echostr
        req.query.echostr = WeChat.decrypt req.query.echostr
      else
        req.query.xml.Encrypt = WeChat.decrypt req.query.xml.Encrypt
      next()

  router.get '/callback', (req,res,next) -> 
    res.send req.query.echostr

  router.post '/callback',(req,res,next) ->  
    xmlData = clone(req.body.xml)
    debug xmlData
    jsData = {}
    for k,v of xmlData when k not in ['FromUserName','ToUserName','CreateTime']
      jsData[Cc.camelCase(k)] = v
    jsData.fromUser = xmlData.FromUserName
    (new WeChatRouter()).handle jsData,(err,data) ->
      if err
        debug "error happens when handle #{req.body.xml}\nerr was: #{err}"
        res.status(500)
      else
        response = {}
        if typeof data == 'object'
          response[Cc.camelCase(k)] = v for k,v of data             
        else if typeof data == 'string'
          response.msgType = 'text'
          response.content = data

        response.toUser = xmlData.FromUserName
        response.fromUser = xmlData.ToUserName
        response.time = xmlData.CreateTime
        res.render "wechat/#{response.msgType}", response

  module.exports = router
