define [
    'clone'
    'xml2js'
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
    xml2js
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
  log = debug('http')
  
  router.use '/callback',xmlparser({trim: false,normalize: false,normalizeTags: false, explicitArray: false}), (req,res,next) ->
    if (not req.query.echostr?) and (not req.body.xml?)
      res.status(403).json(message: 'invalid request')
      return
    validReq = WeChat.validateUrl
      timestamp: req.query.timestamp
      nonce: req.query.nonce
      signature: req.query.msg_signature
      message: req.query.echostr or req.body.xml.Encrypt
    unless validReq
      res.status(403).json(message: 'invalid wechat source server')
    else
      if req.query.echostr
        req.query.echostr = WeChat.decrypt req.query.echostr
        next()
      else
        decryptMsg = WeChat.decrypt req.body.xml.Encrypt
        xml2js.parseString decryptMsg,{explicitArray : false}, (err,msg) ->
          if err
            log decryptMsg,err
            res.status(200)
          else
            req.body.xml = msg.xml
            next()

  router.get '/callback', (req,res) -> 
    res.send req.query.echostr

  router.post '/callback',(req,res) ->  
    xmlData = clone(req.body.xml)
    log xmlData
    jsData = {}
    for k,v of xmlData when k not in ['FromUserName','ToUserName','CreateTime']
      jsData[Cc.camelCase(k)] = v
    jsData.fromUser = xmlData.FromUserName
    (new WeChatRouter()).handle jsData,(err,data) ->
      if err
        log "error happens when handle #{req.body.xml}\nerr was: #{err}"
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
        WeChat.render response.msgType,response,(err,xmlStr) ->
          res.render "wechat/wrap", WeChat.encrypt(xmlStr)

  module.exports = router
