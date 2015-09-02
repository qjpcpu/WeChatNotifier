define ['express','debug','module','../conf/config'], (express,debug,module,config) ->
  router = express.Router()
  debug = debug('http')
  
  router.get '/', (req, res, next) ->
    res.render 'index', title: 'Express'
  
  module.exports = router
