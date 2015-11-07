#!/usr/bin/env node

requirejs = require '../requirejs'

requirejs ['commander','async','conf/config','models/wechat','prettyjson','models/database','node-uuid','inquirer'], (program,async,config,WeChat,prettyjson,database,uuid,inquirer) ->
  program.version('0.0.1')
  program.command 'token <action>'
    .description 'credentials'
    .action  (act,appId,desc) ->
      database.connect()
      switch act
        when 'list'
          database.jsonRecords ((list) ->
            data = []
            for cls in list
              cls.key = cls.key.replace(/^credentials:/,'')
              data.push cls
            if data.length > 0
              console.log prettyjson.render(data)
            else
              console.log 'No tokens found!'
            process.exit(0)
          ), { prefix: 'credentials:'}
        when 'create'
          questions = [
            {
              type: 'list'
              name: 'agentId'
              message: "请选择使用的agentId:\n"
              choices: (ans) -> ("#{app.id}" for app in config.wechat.apps)
            }
            {
              type: 'input'
              name: 'name'
              message: "请输入接入微信的客户端名称:\n"
              validate: (term) -> if term?.length > 0 then true else "非法名称"
            }
            {
              type: 'list'
              name: 'role'
              message: "请选择权限类型:\n"
              choices: [
                { name: '(标准)允许发送消息,查看用户信息[适用于大部分情况]',value: 'notifier' }
                { name: '(浏览)仅能查看信息',value: 'viewer' }
                { name: '(管理员)完全权限',value: 'manager' }
                { name: '(高级发送)查看全部信息，发送消息，修改标签',value: 'complexNotifier' }
              ]
            }
          ]
          inquirer.prompt questions, (value) ->
            key = (new Buffer(uuid.v1())).toString('base64')
            value.id = uuid.v1()
            database.putJson "credentials:#{key}",value,(list) -> 
              console.log "创建token成功,信息如下:"
              console.log prettyjson.render({key: key,value: value})
              process.exit(0)
        when 'del'
          database.jsonRecords ((list) ->
            data = []
            for cls in list
              data.push { name: "#{cls.value.name}: #{cls.key.replace(/^credentials:/,'')}",value: cls.key }         
            questions = [
              {
                type: 'list'
                name: 'key'
                message: "请选择需要删除的token:\n"
                choices: data            
              }
            ]
            inquirer.prompt questions, (answer) ->
              database.del answer.key,(err) ->
                if err then console.error "删除失败" else console.log 'OK!'
                process.exit 0
          ), { prefix: 'credentials:'}
        when 'update'
          database.jsonRecords ((list) ->
            questions = [
              {
                type: 'list'
                name: 'key'
                message: "请选择需要更新的token:\n"
                choices: (se) ->
                  data = []
                  for cls in list
                    data.push { name: "#{cls.value.name}: #{cls.key.replace(/^credentials:/,'')}",value: cls.key }
                  data                  
              }
              {
                type: 'list'
                name: 'role'
                message: "请选择权限类型:\n"
                choices: [
                  { name: '(标准)允许发送消息,查看用户信息[适用于大部分情况]',value: 'notifier' }
                  { name: '(浏览)仅能查看信息',value: 'viewer' }
                  { name: '(管理员)完全权限',value: 'manager' }
                  { name: '(高级发送)查看全部信息，发送消息，修改标签',value: 'complexNotifier' }
                ]
              }  
              {
                type: 'input'
                name: 'name'
                message: "请输入接入微信的客户端名称:\n"
                validate: (term) -> if term?.length > 0 then true else "非法名称"
              }                          
            ]
            inquirer.prompt questions, (answer) ->
              database.getJson answer.key, (err,value) ->
                key = (new Buffer(uuid.v1())).toString('base64')
                value.name = answer.name
                value.role = answer.role
                arr = [
                  { type: 'del',key: answer.key }
                  { type: 'put',key: "credentials:#{key}",value: value,valueEncoding: 'json' }
                ]
                database.batch arr, (err) ->
                  unless err
                    console.log 'Update token OK'
                    console.log prettyjson.render({key: key,value: value})
                  else
                    console.log 'Update token failed'
                  process.exit 0
          ), { prefix: 'credentials:'}

  program.command 'menu <action>'
    .description 'build menu'
    .action  (act) ->
      switch act
        when 'show'
          async.waterfall [
            ((callback) ->
                WeChat.fetchAccessToken (err1,token,expire) ->
                  if err1 then callback(err1) else callback null,token
            )
            ((token,callback) ->
                WeChat.getMenu token, (err3,m) -> if err3 then callback(err3) else callback null,m
            )
          ], (err,result) ->
            if err 
              console.log err
            else
              console.log prettyjson.render(result)      
        when 'init'
          async.waterfall [
            ((callback) ->
                WeChat.fetchAccessToken (err1,token,expire) ->
                  if err1 then callback(err1) else callback null,token
            )
            ((token,callback) ->
                if config.wechat.menu
                  WeChat.createMenu token,config.wechat.menu, (err2) ->  callback null,token
                else
                  callback null,token
            )
          ], (err,result) ->
            if err 
              console.log err
            else
              console.log 'init menu OK'    
        when 'clear'
          async.waterfall [
            ((callback) ->
                WeChat.fetchAccessToken (err1,token,expire) ->
                  if err1 then callback(err1) else callback null,token
            )
            ((token,callback) ->
                WeChat.removeMenu token, (err2) ->  callback()
            )
          ], (err,result) ->
            if err 
              console.log err
            else
              console.log 'menu removed'    
        else console.log "no such menu action: #{act}"


  program.parse process.argv

