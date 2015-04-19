'use strict';

var fs = require('fs');
var _ = require('lodash');
var gulp = require('gulp');
var $ = require('gulp-load-plugins')();
var expand = require('glob-expand');
var map = require('map-stream');
var XQLint = require('xqlint').XQLint;

var Config = require('./config');

gulp.task('lint:jsonlint', function(){
    return gulp.src(Config.paths.json)
        .pipe($.jsonlint())
        .pipe($.jsonlint.reporter())
        .pipe(map(function(file, cb) {
            if (!file.jsonlint.success) {
                process.exit(1);
            }
            cb(null, file);
        }));
});

gulp.task('lint:jslint', function(){
    return gulp.src(Config.paths.tasks)
        .pipe($.jshint())
        .pipe($.jshint.reporter())
        .pipe($.jshint.reporter('jshint-stylish'))
        .pipe($.jshint.reporter('fail'));
});

gulp.task('lint:xqlint', function(done){

    var files = _.chain(Config.paths.jsoniq)
        .reduce(function(result, path) {
                    return _.union(result, expand(path));
                }, [])
        .filter(function(path){
            return path.indexOf('UpdateReportSchema.jq') === -1;
        })
        .value();
    var hasMarker = false;
    files.forEach(function(file){
        var source = fs.readFileSync(file, 'utf-8');
        var xqlint = new XQLint(source, { styleCheck: false, fileName: file });
        var markers = xqlint.getMarkers();
        if(markers.length > 0) {
            hasMarker = true;
            var errors = _.filter(markers, function(marker){ return marker.type === 'error'; });
            var warnings = _.filter(markers, function(marker){ return marker.type === 'warning'; });
            var lines = source.split('\n');
            $.util.log($.util.colors.bold('\n' + file));
            errors.forEach(function(error){
                $.util.log('\t' + (error.pos.sl + 1) + ' |' + $.util.colors.grey(lines[error.pos.sl]));
                $.util.log('\t' + _.repeat(' ', (error.pos.sl + 1 + '').length + 1) + _.repeat(' ', error.pos.sc + 1) + $.util.colors.red('^ ' + error.message));
            });
            warnings.forEach(function(error){
                $.util.log('\t' + (error.pos.sl + 1) + ' |' + $.util.colors.grey(lines[error.pos.sl]));
                $.util.log('\t' + _.repeat(' ', (error.pos.sl + 1 + '').length + 1) + _.repeat(' ', error.pos.sc + 1) + $.util.colors.yellow('^ ' + error.message));
            });
        }
    });
    if(hasMarker) {
        done('XQlint finished with errors.');
    } else {
        done();
    }
});

gulp.task('lint', ['lint:jslint', 'lint:xqlint']);
