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
        done()

  context 'have valid access token', ->
    accessToken = null
    before (done) ->
      WeChat.fetchAccessToken (err,token,expiresIn) ->
        accessToken = token
        done()

    describe '#users', ->
      it 'should get users list', (done) ->
        WeChat.users accessToken, (error,list) ->
          expect(list).to.be.an Array
          if list.length
            WeChat.usersInfo accessToken,list, (err,info) ->
              expect(info).to.be.an Array
              done()
          else
            done()

    describe '#aliasUser', ->
      it 'should get users list', (done) ->
        WeChat.users accessToken, (error,list) ->
          expect(list).to.be.an Array
          if list.length
            WeChat.usersInfo accessToken,list, (err,info) ->
              if info.filter((e) -> e.remark == '').length
                id = info.filter((e) -> e.remark == '')[0].openid
                WeChat.aliasUser accessToken,{openid: id,remark: "alias"}, (err1) ->
                  expect(err1?).to.eql false
                  done()
              else
                done()
          else
            done()

    describe '#groups', ->
      it 'should get groups list', (done) ->
        WeChat.groups accessToken, (error,groups) ->
          expect(groups).to.be.an Array
          expect(groups.length).to.greaterThan 1
          done()

    #describe '#modify group', ->
    #  it 'should CURD group', (done) ->
    #    groupName = 'test-group'
    #    WeChat.createGroup accessToken,groupName, (err1,res1) ->
    #      expect(res1).to.have.key 'id'
    #      expect(res1.name).to.eql groupName
    #      WeChat.updateGroup accessToken,{id: res1.id, name: "#{groupName}-new"}, (err2,res2) ->
    #        expect(res2.name).to.eql "#{groupName}-new"
    #        expect(res2.id).to.eql res1.id
    #        WeChat.removeGroup accessToken,res2.id, (err3,res3) ->
    #          expect(err3?).to.be false
    #          done()

    describe '#sendTplMessage', ->
      it 'should send tpl message', (done) ->
        opts = 
          to: ['oizcTuIqfPGb-T62hhG2bbtMCxGQ']
          type: 'eventHander'
          data:
            title: 'title'
            event_id: 'event-id'
            desc: 'event occur'
            state: 'handling'
            timestamp: '2015-05-22'
            info: 'wait for a while'
        WeChat.sendTplMessage accessToken,opts, (error,msg) ->
          expect(msg?).to.eql true
          done()
