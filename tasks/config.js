'use strict';

var gulp = require('gulp');
var $ = require('gulp-load-plugins')();

var unencryptedConfigFile = 'config.json';
var encryptedConfigFile = unencryptedConfigFile + '.enc';

var config = {
    paths: {
        encryptedConfigFile: encryptedConfigFile,
        unencryptedConfigFile: unencryptedConfigFile,
        json: ['*.json'],
        tasks: ['gulpfile.js', 'tasks/**/*.js'],
        queries: 'queries',
        jsoniq: ['queries/**/*.xq', 'queries/**/*.jq']
    }
};

gulp.task('config:load', ['crypt:decrypt'], function(done){
    if(!_.isEmpty(config.credentials)){
        done();
        return;
    }

});

module.exports = config;
