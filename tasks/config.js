'use strict';

var fs = require('fs');
var _ = require('lodash');
var $ = require('gulp-load-plugins')();
var gulp = require('gulp');
var minimist = require('minimist');

var unencryptedConfigFile = 'config.json';
var encryptedConfigFile = unencryptedConfigFile + '.enc';

var knownOptions = {
    string: [ 'build-id' ]
};

var args = minimist(process.argv.slice(2), knownOptions);
var buildId = args['build-id'];
if(buildId === undefined || buildId === ''){
    var msg = 'no buildId available. ' + $.util.colors.red('Command line argument --build-id missing.');
    $.util.log(msg);
    throw new $.util.PluginError(__filename, msg);
}

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

gulp.task('config:load', ['crypt:decrypt'], function(){
    if(!_.isEmpty(config.credentials)){
        return;
    }
    config.credentials = JSON.parse(fs.readFileSync(config.paths.unencryptedConfigFile, 'utf-8'));
    config.projectName = 'ml-' + buildId;

    $.util.log('Portal: ' + $.util.colors.green(config.credentials['28'].portal));
    $.util.log('Project: ' + $.util.colors.green(config.projectName));

    config.$28 = new (require('28').$28)(config.credentials['28'].portal);
});

module.exports = config;
