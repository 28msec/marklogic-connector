'use strict';

var Q = require('q');
var expand = require('glob-expand');

var gulp = require('gulp');
var $ = require('gulp-load-plugins')();

var VFS = require('28').VFS;
var _ = require('lodash');
var minimist = require('minimist');
var runSequence = require('run-sequence');

var Config = require('./config');

var credentials;

var Options = {
    OVERWRITE_ALWAYS: 0,
    OVERWRITE_NEVER: 1,
    OVERWRITE_ASK: 2,
    OVERWRITE_IF_NEWER: 3
};

var castToJson = function(obj){
    var result = obj;
    if(_.isString(obj)){
        try {
            result = JSON.parse(obj);
        } catch (e) {

        }
    }
    return result;
};

var throwError = function (error) {
    var message = JSON.stringify(error);
    if(error.stack || error.filename){
        message = error.toString();
        $.util.log(error.stack);
        $.util.log(error.filename);
    } else if(_.isString(error.message)){
        message = error.message;
    }
    if(error.body){
        var body = castToJson(error.body);
        message = _.isObject(body) ? JSON.stringify(body, null, '\t') : body;
        if((_.isObject(body) && body.context) || (_.isArray(body) && body[0].context)){
            $.util.log(message);
            message = 'Compilation error';
        }
    }

    // truncate error message if too long
    if(message.length > 500){
        message = message.substring(0, 500) + ' ... (truncated)';
    }
    throw new $.util.PluginError(__filename, message);
};

var summarizeTestError = function(error){
    var hasError = false;
    if(error.body) {
        var body = castToJson(error.body);
        if (_.isObject(body) && _.isArray(body.items) && body.items.length > 0) {
            body = castToJson(body.items[0]);
        }
        if (_.isObject(body) && body.content) {
            body = castToJson(body.content);
        }
        /*jshint camelcase:false */
        if (_.isObject(body) && !body.request_id) {
            _.each(body, function(testResult, testName){
                if (_.isObject(testResult) && testResult.url) {
                    hasError = true;
                    $.util.log(testName.red + ': ' + testResult.url);
                    if (_.isObject(testResult.expectedFactTable) && testResult.expectedFactTable.error === true) {
                        // http error (e.g. 404)
                        $.util.log(testName.red + ': ' + JSON.stringify(testResult.expectedFactTable, null, '\t'));
                    }
                    _.each(testResult.factTableDiff, function(diff){
                        if (diff.expectedNumberOfFacts) {
                            $.util.log(testName.red + ': ' + JSON.stringify(diff, null, '\t'));
                        }
                    });
                }
            });
        }
        if (hasError) {
            return new Error('some test queries failed');
        }
    }
    return error;
};

var getDatasourceId = function(datasource){
    if(_.isObject(datasource)){
        return datasource.category + ':' + datasource.name;
    }
};

var login = function(email, password){
    $.util.log('Logging in as ' + email);
    return Config.$28.login(email, password).then(function(response){
        $.util.log('Logged in.');
        credentials = response.body;
        return credentials;
    });
};

var removeProject = function(projectName, isIdempotent){
    /*jshint camelcase:false */
    var defered = Q.defer();
    if(!Config.isOnProduction) {
        var token = credentials.access_token;
        $.util.log('Deleting project ' + projectName);
        Config.$28.deleteProject(projectName, token).then(function () {
            $.util.log('Project deleted.');
            defered.resolve(credentials);
        }).catch(function (error) {
            if (!isIdempotent) {
                defered.reject(error);
            } else {
                defered.resolve(credentials);
            }
        });
    } else {
        $.util.log('Skipping project deletion for production: ' + projectName);
        defered.resolve(credentials);
    }
    return defered.promise;
};

var createProject = function(projectName){
    /*jshint camelcase:false */
    var defered = Q.defer();
    if(!Config.isOnProduction) {
        var token = credentials.access_token;
        $.util.log('Creating project ' + projectName);
        Config.$28.createProject(projectName, token).then(function (response) {
            $.util.log('Project  ' + projectName + ' created.');
            /*jshint camelcase:false */
            credentials.project_tokens['project_' + projectName] = response.body.projectToken;
            defered.resolve(credentials);
        }).catch(function (error) {
            $.util.log('Project creation failed: ' + error);
            defered.reject(error);
        });
    } else {
        $.util.log('Skipping project creation on production: ' + projectName);
        defered.resolve(credentials);
    }
    return defered.promise;
};

var upgradeProject = function(projectName){
    /*jshint camelcase:false */
    var deferred = Q.defer();
    var token = credentials.access_token;
    $.util.log('Upgrading project ' + projectName);
    Config.$28.upgradeProject(projectName, token)
    .then(function () {
        $.util.log('Project ' + projectName + ' upgraded.');
        deferred.resolve(credentials);
    }).catch(function (error) {
        $.util.log('Upgrading Project failed: ' + error);
        deferred.reject(error);
    });
    return deferred.promise;
};

var createOrUpgradeProject = function(project){
    if(project.exists){
        return upgradeProject(project.name);
    } else {
        return createProject(project.name);
    }
};

var existsProject = function(projectName){
    /*jshint camelcase:false */
    var deferred = Q.defer();
    var project = {
        name: projectName
    };
    $.util.log('Checking project ' + projectName);
    Config.$28.existsProject(projectName)
    .then(function () {
        $.util.log('project ' + projectName + ' exists already');
        project.exists = true;
        deferred.resolve(project);
    })
    .catch(function (data) {
        if(data.response.statusCode === 404){
            $.util.log('project ' + projectName + ' does not exist.');
            project.exists = false;
            deferred.resolve(project);
        } else {
            $.util.log('Checking Project failed: ' + data);
            deferred.reject(data);
        }
    });
    return deferred.promise;
};

var ignoreQueriesFunction = function(list){
    return list;
};

var upload = function(projectName){
    /*jshint camelcase:false */
    var projectToken = credentials.project_tokens['project_' + projectName];
    if(!projectToken) {
        throw new Error('project not found ' + projectName);
    }
    var projectPath = Config.paths.queries;
    var overwrite = Options.OVERWRITE_ALWAYS;
    var deleteOrphaned = true;
    var simulate = false;
    $.util.log('Uploading queries.');
    return Config.$28.upload(projectName, projectToken, projectPath, overwrite, deleteOrphaned, simulate, ignoreQueriesFunction).then(function(){
        $.util.log('Queries uploaded.');
        return credentials;
    });
};

var runQueriesInParallel = function(projectName, queriesToRun) {
    var promises = [];
    var QueriesAPI = Config.$28.api.Queries(projectName);
    /*jshint camelcase:false */
    var projectToken = credentials.project_tokens['project_' + projectName];
    _.each(queriesToRun, function(nextQuery){
        promises.push(
            QueriesAPI.executeQuery({
                accept: 'application/28.io+json',
                queryPath: nextQuery,
                format: '',
                token: projectToken
            }).then(function (data) {
                $.util.log($.util.colors.green('✓ ') + nextQuery + ' returned with status code: ' + data.response.statusCode);
                return credentials;
            }).catch(function (error) {
                var requestUri = error.response.request.uri;
                var isTestQuery = (requestUri.pathname.lastIndexOf('/v1/_queries/public/test', 0) === 0);
                var href = isTestQuery ? requestUri.host + requestUri.pathname.substring('/v1/_queries/public'.length) : requestUri.host + requestUri.pathname;
                $.util.log($.util.colors.red('✗ ') + href + ' returned with status code: ' + $.util.colors.red(error.response.statusCode));
                error = isTestQuery ? summarizeTestError(error) : error;
                throw error;
            })
        );
    });
    return Q.all(promises);
};

var runQueries = function(projectName, sequenceOfQueriesToRun) {
    return _.chain(sequenceOfQueriesToRun)
        .map(function(queriesToRun) {
            // create chunks of queries to be executed in parallel
            if (_.isString(queriesToRun)) {
                return expand(queriesToRun);
            } else if (_.isArray(queriesToRun)){
                return _.chain(queriesToRun)
                    .map(function(queriesGlob){
                        return expand(queriesGlob);
                    })
                    .flatten()
                    .value();
            }
        })
        .map(function(queriesToRunArray){
            // substring to relative query path
            return _.map(queriesToRunArray, function(query) {
                return query.substring(Config.paths.queries.length + 1);
            });
        })
        .reduce(function(previousPromise, nextQueriesArray){
            // execute them in chunks
            return previousPromise.then(function() {
                return runQueriesInParallel(projectName, nextQueriesArray);
            });
        }, Q.resolve())
        .value();
};

var createDatasource = function(projectName, datasource){
    var defered = Q.defer();
    $.util.log('Creating datasource ' + getDatasourceId(datasource));
    var difault = datasource.default ? datasource.default : false;
    /*jshint camelcase:false */
    var projectToken = credentials.project_tokens['project_' + projectName];
    Config.$28.createDatasource(projectName, datasource.category, datasource.name, projectToken, difault, JSON.stringify(datasource.credentials))
    .then(function () {
        $.util.log(getDatasourceId(datasource) + ' created');
        defered.resolve(credentials);
    })
    .catch(function (error) {
        $.util.log('datasource creation failed: ' + getDatasourceId(datasource));
        defered.reject(error);
    });
    return defered.promise;
};

var updateDatasource = function(projectName, datasource){
    var defered = Q.defer();
    $.util.log('Updating datasource ' + getDatasourceId(datasource));
    var difault = datasource.default ? datasource.default : false;
    /*jshint camelcase:false */
    var projectToken = credentials.project_tokens['project_' + projectName];
    Config.$28.updateDatasource(projectName, datasource.name, datasource.category, datasource.name, projectToken, difault, JSON.stringify(datasource.credentials))
    .then(function(){
        $.util.log(getDatasourceId(datasource) + ' updated');
        defered.resolve(credentials);
    })
    .catch(function (error) {
        $.util.log('Updating datasource failed: ' + getDatasourceId(datasource));
        defered.reject(error);
    });
    return defered.promise;
};

var listDatasources = function(projectName){
    var deferred = Q.defer();
    /*jshint camelcase:false */
    var projectToken = credentials.project_tokens['project_' + projectName];
    Config.$28.listDatasources(projectName, projectToken)
        .then(function(data){
            var datasources = data.body;
            if(_.isString(datasources)){
                datasources = JSON.parse(datasources);
            }
            deferred.resolve(datasources);
        })
        .catch(function (error) {
            $.util.log('listing datasources failed: ' + projectName);
            deferred.reject(error);
        });
    return deferred.promise;
};

var createOrUpdateDatasources = function(existingDataSources){
    var promises = [];
    Config.credentials['28'].datasources.forEach(function(datasource){
        var existing = _.find(existingDataSources, function(ds){ return getDatasourceId(ds) === getDatasourceId(datasource); });
        if (existing) {
            promises.push(updateDatasource(Config.projectName, datasource).catch(throwError));
        } else {
            promises.push(createDatasource(Config.projectName, datasource).catch(throwError));
        }
    });
    return Q.all(promises);
};

gulp.task('28:login', ['config:load'], function(){
    return login(Config.credentials['28'].email, Config.credentials['28'].password).catch(throwError);
});

gulp.task('28:create-project', function(){
    return existsProject(Config.projectName)
        .then(createOrUpgradeProject)
        .catch(throwError);
});

gulp.task('28:remove-project', function(){
    return removeProject(Config.projectName, true).catch(throwError);
});

gulp.task('28:upload', function(){
    return upload(Config.projectName).catch(throwError);
});

gulp.task('28:setup-datasources', function(){
    return listDatasources(Config.projectName)
        .then(createOrUpdateDatasources)
        .catch(throwError);
});

gulp.task('28:init', function(){
    return runQueries(Config.projectName, Config.paths.initQueries).catch(throwError);
});

gulp.task('28:setup', ['28:login'], function(done){
    runSequence('28:remove-project', '28:create-project', ['28:setup-datasources', '28:upload'], '28:init', '28:test', done);
});

gulp.task('28:teardown', function(done){
    runSequence('28:login', '28:remove-project', done);
});

gulp.task('28:test', function(){
    return runQueries(Config.projectName, Config.paths.apiTestQueries).catch(throwError);
});

gulp.task('28:trace', ['28:login'], function(done){
    var knownOptions = {
        string: [ 'path' ]
    };
    var args = minimist(process.argv.slice(2), knownOptions);
    var path = args.path;
    if(!path) {
        throw new $.util.PluginError(__filename, 'Specify --path option.');
    }
    var projectName = Config.projectName;
    /*jshint camelcase:false */
    var projectToken = credentials.project_tokens['project_' + projectName];
    var url = 'http://' + projectName + '.28.io' + '/v1/_queries';
    var request = require('request');
    path = path.indexOf('?') === -1 ? (path + '?') : path;
    url += path + '&trace&_token=' + encodeURIComponent(projectToken);
    request({
        uri: url,
        method: 'POST'
    }, function(error, response, body){
        if(error) {
            throw new $.util.PluginError(__filename, error);
        }
        $.util.log($.util.colors.gray(body));
        var traceFile = response.headers['x-28msec-trace'];
        setTimeout(function(){
            request({
                uri: traceFile,
                method: 'GET'
            }, function(error, response, body){
                if(body) {
                    $.util.log($.util.colors.green(body));
                } else {
                    $.util.log($.util.colors.green('No trace.'));
                }
                done();
            });
        }, 1000);
    });
});

module.exports = {
    watchJSONiqQueries: function(){
        //Initialize the VFS
        /*jshint camelcase:false */
        var projectName = Config.projectName;
        var projectToken = credentials.project_tokens['project_' + projectName];
        var upath = require('upath');
        var projectPath = upath.resolve(Config.paths.queries);
        var vfs = new VFS(Config.$28.api, projectName, projectToken, projectPath);

        //Do the Watch
        gulp.watch(Config.paths.jsoniq, {}, function(event){
            //Get relative query path
            var query = event.path.substring(projectPath.length + 1);
            query = upath.normalize(query);
            $.util.log(query + ' has ' + event.type);

            //Upload
            if(event.type === 'added' || event.type === 'changed') {
                $.util.log($.util.colors.grey('Uploading ' + query));
                vfs.writeRemoteQuery(query, true).then(function(result){
                    //Show compilation errors
                    if(result && result.message) {
                        $.util.log($.util.colors.red(result.message));
                    }
                    $.util.log($.util.colors.green(query + ' uploaded'));
                }).catch(function(error){
                    throwError(error);
                });

            //Delete
            } else if(event.type === 'deleted') {
                $.util.log($.util.colors.grey('Removing ' + query));
                vfs.deleteRemoteQuery(query).then(function(){
                    $.util.log($.util.colors.green(query + ' removed'));
                }).catch(function(error){
                    throwError(error);
                });
            }
        });
    }
};
