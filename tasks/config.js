'use strict';

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

module.exports = config;
