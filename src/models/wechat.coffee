define [
  'async'
  'moment'
  'debug'
  'sha1'
  'restler'
  'conf/config'
  ], (
  async
  moment
  debug
  sha1
  rest
  config
) ->
  log = debug 'wechat'
  calSignature: (seed) ->
    timestamp = "#{moment().unix()}"
    nonce = "#{Math.random()}"
    signature = sha1 [seed,timestamp,nonce].sort().join('')
    { timestamp: timestamp, nonce: nonce, signature: signature }

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
        cb null,result.access_token,expiredAt

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
        log "failed to get user[#{openid}]",result.errmsg
        callback result.errmsg
      else
        log "get user successful",result
        callback null,result

  aliasUser: (accessToken,user,callback) ->
    rest.postJson("https://api.weixin.qq.com/cgi-bin/user/info/updateremark?access_token=#{accessToken}",
      openid: user.openid
      remark: user.remark
    ).on 'complete', (result) ->
      if result.errcode != 0
        log "failed to get user[#{openid}]",result.errmsg
        callback result.errmsg
      else
        log "alias user successful",result
        callback()

  # get user info list
  usersInfo: (accessToken,openidList,callback) ->
    return callback('user id list is empty') unless openidList.length
    list = []
    for v,i in openidList
      index = parseInt i/100
      list[index] ?= []
      list[index].push v
    functions = list.map (arr) ->
      (asyncCallback) ->
        rest.postJson("https://api.weixin.qq.com/cgi-bin/user/info/batchget?access_token=#{accessToken}",
          user_list: ({openid: id} for id in arr) 
        ).on 'complete', (result) ->
          if result.errmsg
            log "failed to get user group",result.errmsg
            asyncCallback result.errmsg
          else
            log "get users info successful",result
            asyncCallback null,result.user_info_list
    async.parallel functions,(err,results) ->
      if err?
        callback err
      else
        callback null,(results.reduce (a,b) -> a.concat b)

  # get groups
  groups: (accessToken,callback) ->
    rest.get('https://api.weixin.qq.com/cgi-bin/groups/get',
      query:
        access_token: accessToken
    ).on 'complete', (result) ->
      if result.errmsg
        log "failed to get groups",result.errmsg
        callback result.errmsg
      else
        log "get groups successful",result.groups
        callback null,result.groups
  
  # get group by user
  groupOfUser: (accessToken,openid,callback) ->
    rest.postJson("https://api.weixin.qq.com/cgi-bin/groups/getid?access_token=#{accessToken}",
      openid: openid 
    ).on 'complete', (result) ->
      if result.errmsg
        log "failed to get user group",result.errmsg
        callback result.errmsg
      else
        log "get group successful",result
        callback null,result

  # create group
  createGroup: (accessToken,name,callback) ->
    rest.postJson("https://api.weixin.qq.com/cgi-bin/groups/create?access_token=#{accessToken}",
      group: { name: name }
    ).on 'complete', (result) ->
      if result.errmsg
        log "failed to create group #{name}",result.errmsg
        callback result.errmsg
      else
        log "create group successful",result.group
        callback null,result.group

  # update group name
  updateGroup: (accessToken,group,callback) ->
    rest.postJson("https://api.weixin.qq.com/cgi-bin/groups/update?access_token=#{accessToken}",
      group: { name: group.name, id: group.id } 
    ).on 'complete', (result) ->
      if result.errmsg != 'ok'
        log "failed to update group #{group.name}",result.errmsg
        callback result.errmsg
      else
        log "update group successful",result
        callback null,group

  # migrate user to another group
  migrateUser: (accessToken,groupId,userIds,callback) ->
    rest.postJson("https://api.weixin.qq.com/cgi-bin/groups/members/batchupdate?access_token=#{accessToken}",
      openid_list: userIds
      to_groupid: groupId
    ).on 'complete', (result) ->
      if result.errmsg != 'ok'
        log "failed to migrate users to  group #{groupId}",result.errmsg
        callback result.errmsg
      else
        log "migrate users to group #{groupId} successful",result
        callback null,group

  # remove group
  removeGroup: (accessToken,groupId,callback) ->
    rest.postJson("https://api.weixin.qq.com/cgi-bin/groups/delete?access_token=#{accessToken}",
      group: { id: groupId }
    ).on 'complete', (result) ->
      if result.errmsg?.length and result.errmsg != 'ok'
        log "failed to remove group #{groupId}",result.errmsg
        callback result.errmsg
      else
        log "remove group successful",result
        callback() 

  # set industry
  setIndustry: (accessToken,industries,callback) ->
    industrySet = {}
    industrySet["industry_id#{i + 1}"] = v for v,i in industries
    rest.postJson("https://api.weixin.qq.com/cgi-bin/template/api_set_industry?access_token=#{accessToken}",
      industrySet
    ).on 'complete', (result) ->
      if result.errcode != 0
        log "failed to set industry",result.errmsg
        callback result.errmsg
      else
        log "set industries successful",result
        callback()  

  # get template
  template: (accessToken,shortId,callback) ->
    rest.postJson("https://api.weixin.qq.com/cgi-bin/template/api_add_template?access_token=#{accessToken}",
      template_id_short: shortId 
    ).on 'complete', (result) ->
      if result.errcode != 0
        log "failed to get template",result.errmsg
        callback result.errmsg
      else
        log "get template id  successful",result
        callback null,result.template_id 


  # send template message
  sendTplMessage: (accessToken,opts,callback) ->
    data = {}
    tplConfig = config.wechat.templates[opts.type]
    template = tplConfig.id
    aliasConfig = {}
    if tplConfig.alias
      aliasConfig[v] = k for k,v of tplConfig.alias
    for k,v of opts.data
      if aliasConfig[k] then data[aliasConfig[k]] = {value: v} else data[k] = {value: v}
    functions = opts.to.map (userId) ->
      (asyncCallback) ->
        rest.postJson("https://api.weixin.qq.com/cgi-bin/message/template/send?access_token=#{accessToken}",
          touser: userId
          template_id: template
          data: data
        ).on 'complete', (result) ->
          if result.errcode != 0
            log "failed to send tpl message",result.errmsg
            asyncCallback result.errmsg
          else
            log "get template id  successful",result.msgid
            asyncCallback null,result.msgid  
    async.parallel functions,(err,results) ->
      if err?
        callback err
      else
        callback null,(results.reduce (a,b) -> a.concat b)

  # create menu
  createMenu: (accessToken,menu,callback) ->
    rest.postJson("https://api.weixin.qq.com/cgi-bin/menu/create?access_token=#{accessToken}",
      button: menu
    ).on 'complete', (result) ->
      if result.errcode != 0
        log "failed to create menu",result.errmsg
        callback result.errmsg
      else
        log "create menu  successful",result
        callback()

  # clear menu
  removeMenu: (accessToken,callback) ->
    rest.get("https://api.weixin.qq.com/cgi-bin/menu/delete?access_token=#{accessToken}").on 'complete', (result) ->
      if result.errcode != 0
        log "failed to clear menu",result.errmsg
        callback result.errmsg
      else
        log "remove menu  successful",result
        callback()

  # get menu
  getMenu: (accessToken,callback) ->
    rest.get("https://api.weixin.qq.com/cgi-bin/menu/get?access_token=#{accessToken}").on 'complete', (result) ->
      if result.menu
        log "get menu  successful",result.menu
        callback(null,result.menu.button)        
      else
        log "failed to get menu",result.errmsg
        callback 'fail to get menu'      

