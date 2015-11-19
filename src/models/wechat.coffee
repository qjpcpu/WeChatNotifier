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
  log = debug 'wcn:wechat'
  class WeChat
    constructor: (appId) ->
      @config = config.getApp appId

    authRules: ->
      {
        manager: 
          read: [ 'department','user','tag','message','token','menu' ]
          write: [ 'department','user','tag','message','token' ]
        notifier:
          read: [ 'department','user','tag','message','token','menu' ]
          write: [ 'message' ]
        complexNotifier:
          read: [ 'department','user','tag','message','token','menu' ]
          write: [ 'message','tag' ]        
        viewer:
          read: [ 'department','user','tag','message','token','menu' ]
          write: []
      }

    canRead: (resource,role) ->
      return false unless role
      rules = this.authRules()
      return false unless rules[role]
      resource in rules[role].read

    canWrite: (resource,role) ->
      return false unless role
      rules = this.authRules()
      return false unless rules[role]
      resource in rules[role].write      
    
    calSignature: (seed) ->
      timestamp = "#{moment().unix()}"
      nonce = "#{Math.random()}"
      signature = sha1 [seed,timestamp,nonce].sort().join('')
      { timestamp: timestamp, nonce: nonce, signature: signature }
  
    # validate query parameters: nonce & timestamp & signature
    validateUrl: (params) ->
      wc = this.config
      signature = sha1 [wc.token,params.timestamp,params.nonce,params.message].sort().join('')
      return true if signature == params.signature
      log 'validate WeChat source failed, source query parameters is:', params
      false
  
    encrypt: (message) ->
      wc = this.config
      message = message.toString()
      cryptor = new WXBizMsgCrypt(wc.token, wc.encodingAesKey, wc.corpId)
      message = cryptor.encrypt(message)
      timestamp = "#{moment().unix()}"
      nonce = (Math.random() * 10000000).toFixed(0)
      signature = cryptor.getSignature timestamp,nonce,message
      { message: message, timestamp: timestamp, nonce: nonce, signature: signature}    
  
    decrypt: (message) ->
      wc = this.config
      cryptor = new WXBizMsgCrypt(wc.token, wc.encodingAesKey, wc.corpId)
      cryptor.decrypt(message).message
  
    # fetch access token
    fetchAccessToken: (cb) ->
      wc = this.config
      rest.get('https://qyapi.weixin.qq.com/cgi-bin/gettoken',
        query:
          corpid: wc.corpId
          corpsecret: wc.corpSecret
      ).on "complete", (result) ->
        if result.errmsg
          log 'fetch wechat access token failed',result
          cb(result.errmsg)
        else
          # make sure token is available
          result.expires_in -= 60
          expiredAt = moment().add(result.expires_in, 'seconds')
          log "fetch access token success, it would expire at #{expiredAt.format('HH:mm')}"
          wc.accessToken = result.access_token
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
          department_id: opts.departmentId or 1
          fetch_child: (if opts.recursive then 1 else 0)
          status: tag
      ).once 'complete', (res) ->
        if res.errcode == 0
          cb(null,res.userlist)
        else
          cb res.errmsg
  
    # get certain user
    user: (opts,callback) ->
      rest.get('https://qyapi.weixin.qq.com/cgi-bin/user/get',
        query:
          access_token: opts.accessToken
          userid: opts.id
      ).on 'complete', (result) ->
        if result.errcode != 0
          log "failed to get user[#{opts.id}]",result.errmsg
          callback result.errmsg
        else
          log "get user successful",result
          callback null,result
  
    createUser: (opts,cb) ->
      switch opts.sex
        when 'male' then opts.sex = 1
        when 'female' then opts.sex = 2

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
        totag: if typeof msg.tagIds == 'object' then msg.tagIds.join('|') else msg.tagIds
        msgtype: msg.type or 'text'
        agentid: msg.appId
        safe: if msg.encrypt then 1 else 0
      switch opts.msgtype
        when 'text'
          throw 'text message body must be string' unless typeof msg.body == 'string'
          opts[opts.msgtype] = { content: msg.body }
        when 'image','voice','file'
          throw 'message body must be hash object' unless typeof msg.body == 'object'
          throw 'no mediaId found in messge body' unless msg.body.mediaId
          opts[opts.msgtype] = { media_id: msg.body.mediaId }
        when 'video'
          throw 'message body must be hash object' unless typeof msg.body == 'object'
          throw 'no mediaId found in messge body' unless msg.body.mediaId
          throw 'no title found in video message body' unless msg.body.title
          opts[opts.msgtype] = 
            media_id: msg.body.mediaId
            title: msg.body.title
            description: msg.body.description
        when 'news'
          unless msg.body instanceof Array
            if msg.body.title? then msg.body = [ msg.body ] else throw 'news message body must be array'
          posts = []
          for a,i in msg.body when i < 10
            throw "every news must have a title" unless a.title
            posts.push
              title: a.title
              description: a.description
              url: a.url
              picurl: a.picUrl
          opts[opts.msgtype] = articles: posts

      opts
    
    # opts:
    # appId,应用id
    # type: 消息类型
    # users/tags/departmentIds(Array/String)(Optional)
    # body(object/Array/string)
    sendMessage: (opts,cb) ->
      wc = this
      msgBody = {}
      try
        log "sending message",opts
        msgBody = wc.formatMessage opts
      catch err
        log "message parameters invalid",err
        return cb(err)
      rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token=#{opts.accessToken}",
        msgBody
      ).once 'complete', (res) ->
        if res.errcode == 0
          log "send message ok"
          cb() 
        else
          log "failed to send message",(res.invaliduser or res.invalidparty or res.invalidtag or res.errmsg)
          cb(res.invaliduser or res.invalidparty or res.invalidtag or res.errmsg)
  
    tags: (opts,cb) ->
      rest.get("https://qyapi.weixin.qq.com/cgi-bin/tag/list?access_token=#{opts.accessToken}").once 'complete', (res) ->
        if res.errcode == 0
          list = ({id: t.tagid, name: t.tagname} for t in res.taglist)
          cb(null,list)
        else
          cb(res.errmsg)
    
    createTag: (opts,cb) ->
      rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/tag/create?access_token=#{opts.accessToken}",
        tagname: opts.name
      ).once 'complete', (res) ->
        if res.errcode == 0
          cb(null,{id: res.tagid, name: opts.name})
        else
          cb(res.errmsg)
  
    renameTag: (opts,cb) ->
      rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/tag/update?access_token=#{opts.accessToken}",
        tagid: opts.id
        tagname: opts.name
      ).once 'complete', (res) ->
        if res.errcode == 0 then cb() else cb(res.errmsg)
  
    deleteTag: (opts,cb) ->
      rest.get('https://qyapi.weixin.qq.com/cgi-bin/tag/delete',
        query: 
          access_token: opts.accessToken
          tagid: opts.id
      ).once 'complete', (res) ->
        if res.errcode == 0 then cb() else cb(res.errmsg)
  
    attachTag: (opts,cb) ->
      rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/tag/addtagusers?access_token=#{opts.accessToken}",
        userlist: if typeof opts.users == 'string' then [ opts.users ] else opts.users
        partylist: opts.departmentIds
        tagid: opts.tagId
      ).once 'complete', (res) ->
        if res.errcode == 0 then cb() else cb(res.errmsg)
  
    detachTag: (opts,cb) ->
      rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/tag/deltagusers?access_token=#{opts.accessToken}",
        userlist: if typeof opts.users == 'string' then [ opts.users ] else opts.users
        partylist: opts.departmentIds
        tagid: opts.tagId
      ).once 'complete', (res) ->
        if res.errcode == 0 then cb() else cb(res.errmsg)
  
    # create menu
    createMenu: (opts,callback) ->
      rest.postJson("https://qyapi.weixin.qq.com/cgi-bin/menu/create?access_token=#{opts.accessToken}&agentid=#{opts.appId}",
        button: opts.menu
      ).on 'complete', (result) ->
        if result.errcode != 0
          log "failed to create menu",result.errmsg
          callback result.errmsg
        else
          log "create menu  successful",result
          callback()
  
    usersByTag: (opts,cb) ->
      rest.get('https://qyapi.weixin.qq.com/cgi-bin/tag/get',
        query:
          access_token: opts.accessToken
          tagid: opts.id
      ).once 'complete', (res) ->
        if res.errcode == 0
          list = ({ id: u.userid,name: u.name} for u in res.userlist)
          cb(null,list)
        else 
          cb(res.errmsg)
  
    # clear menu
    removeMenu: (opts,callback) ->
      rest.get("https://qyapi.weixin.qq.com/cgi-bin/menu/delete?access_token=#{opts.accessToken}&agentid=#{opts.appId}").on 'complete', (result) ->
        if result.errcode != 0
          log "failed to clear menu",result.errmsg
          callback result.errmsg
        else
          log "remove menu  successful",result
          callback()
  
    # get menu
    getMenu: (opts,callback) ->
      rest.get("https://qyapi.weixin.qq.com/cgi-bin/menu/get",
        query:
          access_token: opts.accessToken
          agentid: opts.appId
      ).on 'complete', (result) ->
        if result.menu?.button?
          log "get menu  successful",result.menu.button
          callback(null,result.menu.button)        
        else
          log "failed to get menu",result.errmsg
          callback(result.errmsg)
  
    render: (view,locals,cb) ->
      file = path.join path.dirname(module.uri),"../views/wechat/#{view}.jade"
      jade.renderFile file,locals,cb

