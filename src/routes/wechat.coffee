define ['js2xmlparser','express-xml-bodyparser','express','debug','module','sha1','../conf/config'], (js2xmlparser,xmlparser,express,debug,module,sha1,config) ->
  router = express.Router()
  debug = debug('http')
  
  router.get '/', (req, res, next) ->
    signature = sha1 [config.wechat.token,req.query.timestamp,req.query.nonce].sort().join('')
    if signature == req.query.signature
      debug "微信验证成功"
      res.send req.query.echostr
    else
      debug '微信验证失败',req.query.signature,signature
      res.status(403).send ''

  router.post '/', xmlparser({trim: false, explicitArray: false}),(req,res,next) ->
    debug req.body
    data = 
      ToUserName: req.body.xml.fromusername
      FromUserName: req.body.xml.tousername
      CreateTime: req.body.xml.createtime
      MsgType: 'text'
    if req.body.xml.msgtype == 'text'
      Tuling.ask req.body.xml.fromusername,req.body.xml.content, (result) ->
        data.Content = result
        debug result
        str = js2xmlparser('xml',data,{ useCDATA: true })
        res.send str
    else if req.body.xml.msgtype == 'event' and req.body.xml.event == 'subscribe'
      data.Content = "Hi,我是jason的小robot, my name is Jessie.\n目前你只能问我一些诸如天气或列车之类的问题，但我的目标其实是想成为一个便民小帮手\n"
      data.Content += "如果我不理你，要么是因为你网络不好，要么是因为我Node.js学得还不好,更重要的是我没说我服务有5个9哦少年"
      str = js2xmlparser('xml',data,{ useCDATA: true })
      res.send str
    else if req.body.xml.msgtype == 'event' and req.body.xml.event == 'unsubscribe'
      data.Content = "你不喜欢Jessie吗? Anayway, byebye."
      str = js2xmlparser('xml',data,{ useCDATA: true })
      res.send str

  module.exports = router
