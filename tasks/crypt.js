'use strict';

var fs = require('fs');
var gulp = require('gulp');
var $ = require('gulp-load-plugins')();
var _ = require('lodash');
var runSequence = require('run-sequence');

var Config = require('./config');

var file = Config.paths.unencryptedConfigFile;
var encryptedFile = Config.paths.encryptedConfigFile;
var tplParam = { file: file, encryptedFile: encryptedFile };

var msgs = {
    fileNotFound: _.template('<%= file %> is not found.')(tplParam),
    encyptedFileNotFound: _.template('<%= encryptedFile %> is not found.')(tplParam),
    alreadyExists: _.template('<%= file %> exists already, do nothing.')(tplParam),
    secretKeyNotSet: 'environment variable TRAVIS_SECRET_KEY is not set.'
};

var cmds = {
  encrypt: _.template('sh -c "openssl aes-256-cbc -k $TRAVIS_SECRET_KEY -in <%= file %> -out <%= encryptedFile %>"')(tplParam),
  decrypt: _.template('sh -c "openssl aes-256-cbc -k $TRAVIS_SECRET_KEY -in <%= encryptedFile %> -out <%= file %> -d"')(tplParam)
};

gulp.task('crypt:env-check', function(done){
  if(process.env.TRAVIS_SECRET_KEY === undefined) {
      done(msgs.secretKeyNotSet);
  }else {
      done();
  }
});

gulp.task('crypt:encrypt', ['crypt:env-check'], function(done){
  if(fs.existsSync(file)) {
      runSequence('crypt:encrypt-force', done);
  } else {
      done(msgs.fileNotFound);
  }
});

gulp.task('crypt:decrypt', ['crypt:env-check'], function(done){
    if(!fs.existsSync(file)) {
        if(fs.existsSync(encryptedFile)){
            runSequence('crypt:decrypt-force', done);
        } else {
            done(msgs.encyptedFileNotFound);
        }
    } else {
        $.util.log(msgs.alreadyExists);
        done();
    }
});

gulp.task('crypt:encrypt-force', ['crypt:env-check'], $.shell.task(cmds.encrypt));
gulp.task('crypt:decrypt-force', ['crypt:env-check'], $.shell.task(cmds.decrypt));
