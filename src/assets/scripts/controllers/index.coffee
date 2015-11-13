requirejs [
  'qrcodejs'
  'jquery'
], (
  qrcodejs
  $
) ->
  $ ->
    console.log 'wechat notifier start'
    qrcodeText = $('#qrcode-value').val()
    qrcode = new QRCode 'login-qrcode',
      text: qrcodeText
      width: 256
      height: 256
      correctLevel : QRCode.CorrectLevel.H
    $('#qrcode-value').remove()
    $('#login-qrcode').attr('title','')
  
    refresher = 
      qrcode: qrcodeText
      count: 0
    checkLogin = ->
      refresher.count += 1
      if refresher.count > 60 and refresher.intervalId
        clearInterval refresher.intervalId
        refresher.intervalId = null
        refresher.count = 0
      $.post('/check_login',
        loginCode: refresher.qrcode
      , ((res) ->
        if res.errcode == 0
          clearInterval refresher.intervalId
          $('#info').text '登录成功'
          location.href = res.redirect_uri
      ),'json').fail (err) ->
        switch err.responseJSON.errcode
          when 5 then true
          when 3
            console.log 'qrcode expired'
            $('#info').text '二维码过期，刷新页面重新获取'
            clearInterval refresher.intervalId
          else console.log err.responseJSON
    refresher.intervalId = setInterval checkLogin, 5000
