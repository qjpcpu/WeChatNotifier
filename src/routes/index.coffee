define ['express','debug','module','conf/config','models/wechat','xml2js','models/database'], (express,debug,module,config,WeChat,xml2js,database) ->
  router = express.Router()
  log = debug('http')

  router.get '/', (req, res) ->
    res.render 'index', title: 'WeChatNotifier'
  
  module.exports = router
