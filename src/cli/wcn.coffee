#!/usr/bin/env node

requirejs = require '../requirejs'

requirejs ['commander','async','conf/config','models/wechat','prettyjson'], (program,async,config,WeChat,prettyjson) ->
  program.version('0.0.1')
  program.command 'menu'
    .description 'build menu'
    .action  ->
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
        ((token,callback) ->
            WeChat.getMenu token, (err3,m) -> if err3 then callback(err3) else callback null,m
        )
      ], (err,result) ->
        if err 
          console.log err
        else
          console.log prettyjson.render(result)

  program.parse process.argv

