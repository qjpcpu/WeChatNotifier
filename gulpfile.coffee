gulp = require 'gulp'
coffee = require 'gulp-coffee'
gls = require('gulp-live-server')
rename = require("gulp-rename")
runSequence = require('run-sequence')
del = require 'del'
mocha = require 'gulp-mocha'
chmod = require 'gulp-chmod'
insert = require 'gulp-insert'
fs = require 'fs'

gulp.task 'default', (cb) ->
  console.log 'nothing in default'
  cb()

gulp.task 'clean', ->
  del [
    'bin'
    'models'
    'routes'
    'conf/*.js'
    'test'
    'cli'
    '*.js'
  ]

# build coffee script to javascript
gulp.task 'coffee', ->
  gulp.src(['src/**/*.coffee'])
    .pipe coffee()
    .pipe rename((path) -> path.extname = '' if path.basename == 'www')
    .pipe gulp.dest('.')

# deploy config files 
gulp.task 'config', (cb) ->
  if fs.existsSync('conf/config.cson')
    gulp.src('conf/*.cson').pipe gulp.dest('./data/config-backup')
  else
    gulp.src('src/**/*.cson').pipe gulp.dest('.')

gulp.task 'cli', ['coffee'], (cb) ->
  gulp.src('cli/wcn.js')
    .pipe rename((path) -> path.extname = '')
    .pipe insert.prepend("#!/usr/bin/env node\n")
    .pipe chmod({owner: {execute: true}})
    .pipe gulp.dest 'cli/'
    .on 'end', ->
      del('cli/wcn.js').then -> cb()
  null

gulp.task 'assets', ->
  gulp.src('src/assets/**/*').pipe gulp.dest('public')

# build all coffee & config files
gulp.task 'build', (cb) ->
   runSequence 'clean',['config','cli','coffee','assets'], cb

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

