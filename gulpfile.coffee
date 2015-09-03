gulp = require 'gulp'
coffee = require 'gulp-coffee'
gls = require('gulp-live-server')
rename = require("gulp-rename")
runSequence = require('run-sequence')
del = require 'del'
mocha = require 'gulp-mocha'

gulp.task 'default', (cb) ->
  console.log 'nothing in default'
  cb()

gulp.task 'clean', ->
  del [
    'bin'
    'models'
    'routes'
    'conf'
    'test'
    '*.js'
  ]

# build coffee script to javascript
gulp.task 'coffee', ->
  gulp.src(['src/**/*.coffee'])
    .pipe coffee()
    .pipe rename((path) -> path.extname = '' if path.basename == 'www')
    .pipe gulp.dest('.')

# deploy config files 
gulp.task 'config', ->
  gulp.src('src/**/*.cson').pipe gulp.dest('.')

# build all coffee & config files
gulp.task 'build', ->
   runSequence 'clean',['config','coffee']

# start serve
gulp.task 'serve', ->
  gulp.watch ['src/config/*.cson'], ['config']
  gulp.watch ['src/**/*.coffee'], ['coffee']
  server = gls.new 'bin/www'
  server.start()
  gulp.watch ['./**/*.js'], (file) ->
    server.notify.apply server, [file]

# run test task
gulp.task 'test', ['coffee'],  ->
  gulp.src('test/*.js', {read: false})
    .pipe(mocha({reporter: 'nyan'}))

