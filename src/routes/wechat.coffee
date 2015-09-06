define [
    'js2xmlparser'
    'express-xml-bodyparser'
    'express'
    'debug'
    'module'
    '../models/wechat'
    '../conf/config'
  ], (
    js2xmlparser
    xmlparser
    express
    debug
    module
    WeChat
    config
) ->
  router = express.Router()
  debug = debug('http')
  
  router.use (req,res,next) ->
    validReq = WeChat.validate
      timestamp: req.query.timestamp
      nonce: req.query.nonce
    if validReq then next() else res.status(403).json(message: 'invalid wechat source server')

  router.get '/callback', (req,res,next) ->
    res.send req.query.echostr

  router.post '/callback', xmlparser({trim: false, explicitArray: false}),(req,res,next) ->
    debug req.body
    data = 
      ToUserName: req.body.xml.fromusername
      FromUserName: req.body.xml.tousername
      CreateTime: req.body.xml.createtime
      MsgType: 'text'
      Content: 'echo back: ' + req.body.xml.content
    str = js2xmlparser 'xml',data, { useCDATA: true }
    res.send str

  module.exports = router
