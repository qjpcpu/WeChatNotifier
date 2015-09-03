load = require('./test-loader')
expect = require 'expect.js'

describe 'WeChat', ->
  WeChat = undefined
  before (done) ->
    load ['../models/wechat'], (wechat) ->
      WeChat = wechat
      done()
  
  describe "#fetchAccessToken", ->
    it "should get access_token", (done) ->
      WeChat.fetchAccessToken (err,token,expiresIn) ->
        expect(err).to.be(null)
        expect(token.length).to.be.greaterThan 1
        WeChat.users token, (error,list) ->
          expect(list).to.be.an Array
          done()
