gulp = require 'gulp'
coffee = require 'gulp-coffee'
gls = require('gulp-live-server')
rename = require("gulp-rename")
runSequence = require('run-sequence')
del = require 'del'

gulp.task 'default', (cb) ->
  console.log 'nothing in default'
  cb()

gulp.task 'clean', ->
  del [
    'bin'
    'models'
    'routes'
    'conf'
    '*.js'
  ]

gulp.task 'coffee', ->
  gulp.src(['src/**/*.coffee'])
    .pipe coffee()
    .pipe rename((path) -> path.extname = '' if path.basename == 'www')
    .pipe gulp.dest('.')

gulp.task 'config', ->
  gulp.src('src/**/*.cson', {Read: false}).pipe gulp.dest('.')

gulp.task 'build', ->
   runSequence 'clean',['config','coffee']

gulp.task 'serve', ->
  gulp.watch ['src/config/*.cson'], ['config']
  gulp.watch ['src/**/*.coffee'], ['coffee']
  server = gls.new 'bin/www'
  server.start()
  gulp.watch ['./**/*.js'], (file) ->
    server.notify.apply server, [file]