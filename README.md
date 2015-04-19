#JSONiq Connector for MarkLogic

##Installation
Use the [28 cli](https://github.com/28msec/28) to setup your MarkLogic data source and deploy your queries.

Sign up and create an account at http://hq.28.io/account/register.
A video tutorial that shows the 28 cli in action is available [here](https://youtu.be/NILlys4h7Fs?t=53s).
Getting started instructions are also available [here](https://github.com/28msec/28/blob/master/getting-started.md).

Here's an example of data source configuration file:
```json
[{
    "category": "MarkLogic",
    "name": "my-datasource",
    "credentials": {
        "username": "test",
        "password": "foobar",
        "hostname": "localhost",
        "port": 8003
    }
}]
```

To attach the data source to your project:
```bash
$28 datasources set my-project -c datasources.json
```

##Development
```bash
$ npm install gulp -g
$ npm install
```

To decrypt the deployment information use `TRAVIS_SECRET_KEY` environnement variable.
```bash
$export TRAVIS_SECRET_KEY=<secret>
```

To deploy the queries and test the queries:
```bash
$ gulp setup --build-id=test
```

To remove a deployment once you are done:
```bash
$ gulp teardown --build-id=test
```
