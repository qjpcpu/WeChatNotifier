define [
    'clone'
    'js2xmlparser'
    'express-xml-bodyparser'
    'express'
    'debug'
    'module'
    'change-case'
    '../models/wechat'
    '../models/wechat-router'
    '../conf/config'
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
  
  router.use (req,res,next) ->
    validReq = WeChat.validate
      timestamp: req.query.timestamp
      nonce: req.query.nonce
      signature: req.query.signature
    if validReq then next() else res.status(403).json(message: 'invalid wechat source server')

  router.get '/callback', (req,res,next) ->
    res.send req.query.echostr

  router.post '/callback', xmlparser({trim: false,normalize: false,normalizeTags: false, explicitArray: false}),(req,res,next) ->
    xmlData = clone(req.body.xml)
    debug xmlData
    jsData = {}
    for k,v of xmlData
      jsData[Cc.camelCase(k)] = v
    (new WeChatRouter()).handle jsData,(err,data) ->
      if err
        debug "error happens when handle #{req.body.xml}\nerr was: #{err}"
        res.status(500)
      else
        response = {}
        if typeof data == 'object'
          for k,v of data
            switch k
              when 'locationX' then response['Location_X'] = v
              when 'locationY' then response['Location_Y'] = v
              else response[Cc.pascalCase(k)] = v
          response.ToUserName = xmlData.fromUserName
          response.FromUserName = xmlData.toUserName
          response.CreateTime = xmlData.createTime              
        else if typeof data == 'string'
          tmp =
            toUserName: xmlData.fromUserName
            fromUserName: xmlData.toUserName
            createTime: xmlData.createTime
            content: data
          response[Cc.pascalCase(k)] = v for k,v of tmp
        response = js2xmlparser 'xml',response, { useCDATA: true }
        res.send response

  module.exports = router
