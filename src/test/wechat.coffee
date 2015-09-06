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
          done()

    describe '#groups', ->
      it 'should get groups list', (done) ->
        WeChat.groups accessToken, (error,groups) ->
          expect(groups).to.be.an Array
          expect(groups.length).to.greaterThan 1
          done()

    describe '#modify group', ->
      it 'should CU group', (done) ->
        groupName = 'test-group'
        WeChat.createGroup accessToken,groupName, (err1,res1) ->
          expect(res1).to.have.key 'id'
          expect(res1.name).to.eql groupName
          WeChat.updateGroup accessToken,{id: res1.id, name: "#{groupName}-new"}, (err2,res2) ->
            console.log res2
            expect(res2.name).to.eql "#{groupName}-new"
            done()

