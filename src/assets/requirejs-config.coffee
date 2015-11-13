requirejs.config
  baseUrl: '/assets'
  paths:
    jquery: 'vendor/jquery/dist/jquery.min'
    qrcodejs: 'vendor/qrcode-js/qrcode'
    ctrls: 'scripts/controllers'
    models: 'scripts/models'
  shim: 
    qrcodejs: exports: 'QRCode'    
