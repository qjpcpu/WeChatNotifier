#!/usr/bin/env node

requirejs = require '../requirejs'

requirejs ['commander','async','conf/config','models/wechat','prettyjson','models/database','node-uuid'], (program,async,config,WeChat,prettyjson,database,uuid) ->
  program.version('0.0.1')
  program.command 'token <action> [appId] [desc]'
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
            console.log prettyjson.render(data)
            process.exit(0)
          ), { prefix: 'credentials:'}
        when 'create'
          unless appId
            console.error 'no appId found'
            console.error 'Usage: wcn token create appId name'
            process.exit 1
          unless desc
            console.error 'no name'
            console.error 'Usage: wcn token create appId name'
            process.exit 1

          key = (new Buffer(uuid.v1())).toString('base64')
          value = { agentId: appId,name: desc }
          database.putJson "credentials:#{key}",value,(list) -> 
            console.log "Create record:"
            console.log prettyjson.render({key: key,value: value})
            process.exit(0)
        when 'del'
          unless appId
            console.error "no key found"
            process.exit 1
          key = appId
          database.del "credentials:#{key}",(err) ->
            if err then console.error "删除失败" else console.log 'OK!'
            process.exit 0


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

