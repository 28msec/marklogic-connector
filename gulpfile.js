'use strict';

var gulp = require('gulp');
var runSequence = require('run-sequence');

require('./tasks/28');
require('./tasks/crypt');
require('./tasks/lint');

require('./tasks/config');

gulp.task('setup', ['config:load'], function(done) {
    runSequence('lint', '28:setup', done);
});

gulp.task('teardown', ['config:load'], function(done) {
    runSequence('28:teardown', done);
});
