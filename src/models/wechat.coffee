define [
  'debug'
  'sha1'
  '../conf/config'
  ], (
  debug
  sha1
  config
) ->
  log = debug 'wechat'
  # validate query parameters: nonce & timestamp & signature
  validate: (params) ->
    signature = sha1 [config.wechat.token,params.timestamp,params.nonce].sort().join('')
    return true if signature == params.signature
    log 'validate WeChat source failed, source query parameters is:', params
    false
