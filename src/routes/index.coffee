define ['express','debug','module','conf/config','models/wechat','xml2js'], (express,debug,module,config,WeChat,xml2js) ->
  router = express.Router()
  log = debug('http')
  
  router.get '/', (req, res, next) ->
    res.render 'index', title: 'WeChatNotifier'
  
  module.exports = router
