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
    if (not req.query.echostr?) and (not req.body.xml?.Encrypt?)
      res.status(403).json(message: 'invalid request, lost body')
      return
    if (not req.query.timestamp?) or (not req.query.nonce?) or (not req.query.msg_signature?)
      res.status(403).json message: 'invalid request from unkown source'
      return
    if req.body.xml?.AgentID
      chat = new WeChat req.body.xml.AgentID
    else
      chat = new WeChat config.wechat.apps[0].id
      for app,i in config.wechat.apps when i > 0
        wc = new WeChat app.id
        vr = wc.validateUrl
          timestamp: req.query.timestamp
          nonce: req.query.nonce
          signature: req.query.msg_signature
          message: req.query.echostr or req.body.xml.Encrypt
        if vr
          chat = wc
          break

    validReq = chat.validateUrl
      timestamp: req.query.timestamp
      nonce: req.query.nonce
      signature: req.query.msg_signature
      message: req.query.echostr or req.body.xml.Encrypt
    unless validReq
      res.status(403).json(message: 'invalid callback request from unkown source')
    else
      if req.query.echostr
        req.query.echostr = chat.decrypt req.query.echostr
        next()
      else
        decryptMsg = chat.decrypt req.body.xml.Encrypt
        xml2js.parseString decryptMsg,{explicitArray : false}, (err,msg) ->
          if err
            log decryptMsg,err
            res.json message: 'ok'
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
        response = 
          toUser: xmlData.FromUserName
          fromUser: xmlData.ToUserName
          time: "#{moment().unix()}"
          msgType: 'text'
          content: "oops! error happens"
        chat = new WeChat(jsData.agentId)
        chat.render response.msgType,response,(err,xmlStr) ->
          res.render "wechat/wrap", chat.encrypt(xmlStr)        
      else
        response = {}
        if typeof data == 'object' and data.msgType in ['text','news','image','music','video','voice']
          response[Cc.camelCase(k)] = v for k,v of data             
        else if typeof data == 'string'
          response.msgType = 'text'
          response.content = data
        else
          log "bad response from server",data
          response = 
            msgType: 'text'
            content: "oops! bad response from server"          

        response.toUser = xmlData.FromUserName
        response.fromUser = xmlData.ToUserName
        response.time = "#{moment().unix()}"
        chat = new WeChat(jsData.agentId)
        chat.render response.msgType,response,(err,xmlStr) ->
          res.render "wechat/wrap", chat.encrypt(xmlStr)

  module.exports = router
