define [
    'clone'
    'js2xmlparser'
    'express-xml-bodyparser'
    'express'
    'debug'
    'module'
    'change-case'
    '../models/wechat'
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
        if typeof data == 'object'
          data.toUserName = xmlData.fromUserName
          data.fromUserName = xmlData.toUserName
          data.createTime = xmlData.createTime
          newData = {}
          for k,v of data
            switch k
              when 'locationX' then newData['Location_X'] = v
              when 'locationY' then newData['Location_Y'] = v
              else newData[Cc.pascalCase(k)] = v
          data = js2xmlparser 'xml',newData, { useCDATA: true }
        # now data is a string
        res.send data

  module.exports = router
