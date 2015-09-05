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
  # get certain user
  user: (accessToken,openid,callback) ->
    rest.get('https://api.weixin.qq.com/cgi-bin/user/info',
      query:
        access_token: accessToken
        openid: openid
        lang: 'zh_CN'
    ).on 'complete', (result) ->
      if result.errmsg
        log "failed to get user[#{openid}]",errmsg
        callback errmsg
      else
        log "get user successful",result
        callback null,result
  
  # get groups
  groups: (accessToken,callback) ->
    rest.get('https://api.weixin.qq.com/cgi-bin/groups/get',
      query:
        access_token: accessToken
    ).on 'complete', (result) ->
      if result.errmsg
        log "failed to get groups",errmsg
        callback errmsg
      else
        log "get groups successful",result.groups
        callback null,result.groups
  
  # get group by user
  groupOfUser: (accessToken,openid,callback) ->
    rest.post('https://api.weixin.qq.com/cgi-bin/groups/getid',
      query: { access_token: accessToken }
      data: { openid: openid }
    ).on 'complete', (result) ->
      if result.errmsg
        log "failed to get user group",errmsg
        callback errmsg
      else
        log "get group successful",result
        callback null,result

  # create group
  createGroup: (accessToken,name,callback) ->
    rest.post('https://api.weixin.qq.com/cgi-bin/groups/create',
      query: { access_token: accessToken }
      data: { group: { name: name } }
    ).on 'complete', (result) ->
      if result.errmsg
        log "failed to create group #{name}",errmsg
        callback errmsg
      else
        log "create group successful",result.group
        callback null,result.group

  # update group name
  updateGroup: (accessToken,group,callback) ->
    rest.post('https://api.weixin.qq.com/cgi-bin/groups/update',
      query: { access_token: accessToken }
      data: { group: { name: group.name, id: group.id } }
    ).on 'complete', (result) ->
      if result.errmsg != 'ok'
        log "failed to update group #{group.name}",errmsg
        callback errmsg
      else
        log "update group successful",result
        callback null,group

  # migrate user to another group
  migrateUser: (accessToken,groupId,userIds,callback) ->
    rest.post('https://api.weixin.qq.com/cgi-bin/groups/members/batchupdate',
      query: { access_token: accessToken }
      data: 
        openid_list: userIds
        to_groupid: groupId
    ).on 'complete', (result) ->
      if result.errmsg != 'ok'
        log "failed to migrate users to  group #{groupId}",errmsg
        callback errmsg
      else
        log "migrate users to group #{groupId} successful",result
        callback null,group

  # remove group
  removeGroup: (accessToken,groupId,callback) ->
    rest.post('https://api.weixin.qq.com/cgi-bin/groups/delete',
      query: { access_token: accessToken }
      data: { group: { id: groupId } }
    ).on 'complete', (result) ->
      if result.errmsg != 'ok'
        log "failed to remove group #{groupId}",errmsg
        callback errmsg
      else
        log "remove group successful",result
        callback() 

  # set industry
  setIndustry: (accessToken,industries,callback) ->
    industrySet = {}
    industrySet["industry_id#{i + 1}"] = v for v,i in industries
    rest.post('https://api.weixin.qq.com/cgi-bin/template/api_set_industry',
      query: { access_token: accessToken }
      data: industrySet
    ).on 'complete', (result) ->
      if result.errcode != 0
        log "failed to set industry",errmsg
        callback errmsg
      else
        log "set industries successful",result
        callback()  

  # get template
  template: (accessToken,shortId,callback) ->
    rest.post('https://api.weixin.qq.com/cgi-bin/template/api_add_template',
      query: { access_token: accessToken }
      data: { template_id_short: shortId }
    ).on 'complete', (result) ->
      if result.errcode != 0
        log "failed to get template",errmsg
        callback errmsg
      else
        log "get template id  successful",result
        callback null,result.template_id                       