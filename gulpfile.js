'use strict';

var gulp = require('gulp');
var runSequence = require('run-sequence');

require('./tasks/config');
require('./tasks/28');
require('./tasks/crypt');
require('./tasks/lint');

gulp.task('setup', ['crypt:decrypt'], function(done) {
    runSequence('lint', '28:setup', done);
});

gulp.task('teardown', ['crypt:decrypt'], function(done) {
    runSequence('28:teardown', done);
});
