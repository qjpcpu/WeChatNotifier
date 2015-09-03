define [
  'async'
  'moment'
  'debug'
  'sha1'
  'restler'
  '../conf/config'
  ], (
  async
  moment
  debug
  sha1
  rest
  config
) ->
  log = debug 'wechat'
  # validate query parameters: nonce & timestamp & signature
  validate: (params) ->
    signature = sha1 [config.wechat.token,params.timestamp,params.nonce].sort().join('')
    return true if signature == params.signature
    log 'validate WeChat source failed, source query parameters is:', params
    false
  # fetch access token
  fetchAccessToken: (cb) ->
    rest.get('https://api.weixin.qq.com/cgi-bin/token',
      query:
        grant_type: 'client_credential'
        appid: config.wechat.appId
        secret: config.wechat.appSecret
    ).on "complete", (result) ->
      if result.errmsg
        log 'fetch wechat access token failed',result
        cb(result.errmsg)
      else
        # make sure token is available
        result.expires_in -= 60
        expiredAt = moment().add(result.expires_in, 'seconds')
        log "fetch access token success, it would expire at #{expiredAt.format('HH:mm')}"
        cb null,result.access_token,result.expires_in

  # get user list
  users: (accessToken,cb) ->
    handler = 
      userList: []
      nextOpenid: null

    async.forever(
        ((next) ->
          rest.get('https://api.weixin.qq.com/cgi-bin/user/get',
            query:
              access_token: accessToken  
              next_openid:  handler.nextOpenid
          ).on 'complete', (result) ->
            if result.errmsg?
               next result.errmsg
            else
              handler.userList.push result.data.openid... if result.data.openid?.length
              if result.openid?.length
                handler.nextOpenid = result.openid 
                next()
              else 
                next('done')
        )
        ((err) ->
            log "get #{handler.userList.length} wechat subscribers."
            if err == 'done' then cb(null,handler.userList) else cb(err,[])
        )
    )

