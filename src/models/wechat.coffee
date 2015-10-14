define [
  'async'
  'moment'
  'debug'
  'sha1'
  'restler'
  'conf/config'
  'wechat-crypto'
  'module'
  'path'
  'jade'
  ], (
  async
  moment
  debug
  sha1
  rest
  config
  WXBizMsgCrypt
  module
  path
  jade
) ->
  log = debug 'wechat'
  calSignature: (seed) ->
    timestamp = "#{moment().unix()}"
    nonce = "#{Math.random()}"
    signature = sha1 [seed,timestamp,nonce].sort().join('')
    { timestamp: timestamp, nonce: nonce, signature: signature }

  # validate query parameters: nonce & timestamp & signature
  validateUrl: (params) ->
    signature = sha1 [config.wechat.token,params.timestamp,params.nonce,params.message].sort().join('')
    return true if signature == params.signature
    log 'validate WeChat source failed, source query parameters is:', params
    false

  encrypt: (message) ->
    cryptor = new WXBizMsgCrypt(config.wechat.token, config.wechat.encodingAesKey, config.wechat.corpId)
    message = cryptor.encrypt(message)
    timestamp = "#{moment().unix()}"
    nonce = (Math.random() * 10000000).toFixed(0)
    signature = cryptor.getSignature timestamp,nonce,message
    { message: message, timestamp: timestamp, nonce: nonce, signature: signature}    

  decrypt: (message) ->
    cryptor = new WXBizMsgCrypt(config.wechat.token, config.wechat.encodingAesKey, config.wechat.corpId)
    cryptor.decrypt(message).message

  # fetch access token
  fetchAccessToken: (cb) ->
    rest.get('https://qyapi.weixin.qq.com/cgi-bin/gettoken',
      query:
        corpid: config.wechat.corpId
        corpsecret: config.wechat.corpSecret
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

  # opts:
  # accessToken 
  # id(optional)
  departments: (opts,cb) ->
    rest.get('https://qyapi.weixin.qq.com/cgi-bin/department/list',
      query: 
        access_token: opts.accessToken
        id: opts.id
    ).once 'complete', (result) ->
      if result.errcode != 0
        cb(result.errmsg)
      else
        cb(null,result.department)

  createDepartment: (opts,cb) ->
    rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/department/create?access_token=#{opts.accessToken}",
      #query:  
      #  access_token: opts.accessToken
      #data:
      name: opts.name
      parentid: opts.parentId or 1
    ).once 'complete', (res) ->
      if res.errcode != 0
        cb(res.errmsg)
      else
        cb(null,{id: res.id})

  updateDepartment: (opts,cb) ->
    rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/department/update?access_token=#{opts.accessToken}",
      id: opts.id
      name: opts.name
      parentid: opts.parentId
    ).once 'complete', (err) ->
      if err.errcode == 0 then cb() else cb(err.errmsg)

  deleteDepartment: (opts,cb) ->
    rest.get('https://qyapi.weixin.qq.com/cgi-bin/department/delete',
      query:
        access_token: opts.accessToken
        id: opts.id
    ).once 'complete', (err) ->
      if err.errcode == 0 then cb() else cb(err.errmsg)

  users: (opts,cb) ->
    switch opts.status
      when 'all' then tag = 0
      when 'watched' then tag = 1
      when 'disabled' then tag = 2
      when 'unwatched' then tag = 4
      else tag = 1
    if opts.detail
      url = 'https://qyapi.weixin.qq.com/cgi-bin/user/list'
    else
      url = 'https://qyapi.weixin.qq.com/cgi-bin/user/simplelist'
    rest.get(url,
      query:
        access_token: opts.accessToken
        department_id: opts.id or 1
        fetch_child: (if opts.recursive then 1 else 0)
        status: tag
    ).once 'complete', (res) ->
      if res.errcode == 0
        cb(null,res.userlist)
      else
        cb res.errmsg

  # get certain user
  user: (accessToken,id,callback) ->
    rest.get('https://qyapi.weixin.qq.com/cgi-bin/user/get',
      query:
        access_token: accessToken
        userid: id
    ).on 'complete', (result) ->
      if result.errcode != 0
        log "failed to get user[#{id}]",result.errmsg
        callback result.errmsg
      else
        log "get user successful",result
        callback null,result

  createUser: (opts,cb) ->
    switch opts.sex
      when 'male' then opts.sex = 1
      when 'female' then opts.sex = 2
      else opts.sex = undefined
    rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/user/create?access_token=#{opts.accessToken}",
      userid: opts.id
      name: opts.name or opts.id
      department: (if opts.departmentIds?.length > 0 then opts.departmentIds else [1])
      position: opts.position
      mobile: opts.mobile
      email: opts.email
      gender: opts.sex
    ).once 'complete', (res) ->
      if res.errcode == 0 then cb() else cb(res.errmsg)

  updateUser: (opts,cb) ->
    if opts.sex
      switch opts.sex
        when 'male' then opts.sex = 1
        when 'female' then opts.sex = 2
        else delete opts.sex
    if opts.state
      switch opts.state
        when 'enable' then opts.state = 1
        when 'disable' then opts.state = 0
        else delete opts.state
    rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/user/update?access_token=#{opts.accessToken}",
      userid: opts.id
      name: opts.name
      department: opts.departmentIds
      position: opts.position
      mobile: opts.mobile
      email: opts.email
      gender: opts.sex
      enable: opts.state
    ).once 'complete', (res) ->
      if res.errcode == 0 then cb() else cb(res.errmsg)

  # delete user: opts.id is userid
  # delete users: opts.id is user list (Array)
  deleteUser: (opts,cb) ->
    rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/user/batchdelete?access_token=#{opts.accessToken}",
      useridlist: if typeof opts.id == 'string' then [opts.id] else opts.id
    ).once 'complete', (res) ->
      if res.errcode == 0 then cb() else cb(res.errmsg)

  inviteUser: (opts,cb) ->
    rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/invite/send?access_token=#{opts.accessToken}",
      userid: opts.id        
    ).once 'complete', (res) ->
      if res.errcode == 0 then cb(null,res.type) else cb(res.errmsg)

  formatMessage: (msg) ->
    # if you want send to all users, msg.users should be '@all'
    opts = 
      touser: if typeof msg.users == 'object' then msg.users.join('|') else msg.users
      toparty: if typeof msg.departmentIds == 'object' then msg.departmentIds.join('|') else msg.departmentIds
      totag: if typeof msg.tags == 'object' then msg.tags.join('|') else msg.tags
      msgtype: msg.type or 'text'
      agentid: msg.appId
      safe: if msg.encrypt then 1 else 0
    switch opts.msgtype
      when 'text' then opts[opts.msgtype] = { content: msg.body }
      when 'image','voice','file' then opts[opts.msgtype] = { media_id: msg.body.mediaId }
      when 'video'
        opts[opts.msgtype] = 
          media_id: msg.body.mediaId
          title: msg.body.title
          description: msg.body.description
      when 'news'
        if msg.body instanceof Array
          posts = []
          for a,i in msg.body when i < 10
            posts.push
              title: a.title
              description: a.description
              url: a.url
              picurl: a.picUrl
          opts[opts.msgtype] = articles: posts
        else
          opts[opts.msgtype] = articles: []
    opts
  
  # opts:
  # appId,应用id
  # type: 消息类型
  # users/tags/departmentIds(Array/String)(Optional)
  # body(object/Array/string)
  sendMessage: (opts,cb) ->
    wc = this
    rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=#{opts.accessToken}",
      wc.formatMessage(opts)
    ).once 'complete', (res) ->
      log "send message response: #{res}"
      if res.errcode == 0 then cb() else cb(res.invaliduser or res.invalidparty or res.invalidtag or res.errmsg)

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

  render: (view,locals,cb) ->
    file = path.join path.dirname(module.uri),"../views/wechat/#{view}.jade"
    jade.renderFile file,locals,cb

