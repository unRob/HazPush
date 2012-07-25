(function() {
  var app, auth, config, configFile, crypto, exec, express, fs, git, puerto, util, validator;

  fs = require('fs');

  express = require('express');

  validator = require('validator').sanitize;

  crypto = require('crypto');

  exec = require('child_process').exec;

  util = require('util');

  app = express.createServer();

  configFile = process.argv[2];

  config = JSON.parse(fs.readFileSync(configFile, 'utf8'));

  git = require('./git').create(config.git_dir);

  app.configure(function() {
    return app.use(app.router);
  });

  auth = function(app, req, next) {
    var expected, signature, signer, url, verbo, _ref;
    app.res.header('X-Powered-by', 'HazPush/1.0b');
    if (config.github) {
      if ((_ref = req.connection.remoteAddress) === '207.97.227.253' || _ref === '50.57.128.197' || _ref === '108.171.174.178') {
        return next();
      } else {
        return app.res.json({
          error: "Auth FAIL!"
        }, 401);
      }
    }
    signature = req.req.headers['x-auth'];
    if (!(signature != null)) {
      return app.res.json({
        error: "Auth FAIL!"
      }, 401);
    }
    signer = crypto.createHmac('sha256', new Buffer(config.key, 'utf8'));
    verbo = app.method;
    url = req.req.url;
    expected = signer.update("" + app.method + "::" + req.req.url).digest('hex');
    if (signature !== expected) {
      util.log("" + signature + " != " + expected);
      return app.res.json({
        error: "Auth FAIL!"
      }, 401);
    }
    return next();
  };

  app.get('/status', auth, function(req, res) {
    return git.status(function(cambios) {
      return res.json(cambios);
    });
  });

  app.get('/pull', auth, function(req, res) {
    return git.pull(function(result) {
      var header, hook, _i, _len, _ref;
      header = 200;
      if ('error' in result === true) header = 409;
      if (config.hooks.pull) {
        util.log("Calling pull hooks");
        _ref = config.hooks.pull;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          hook = _ref[_i];
          util.log(hook);
          exec(hook, function(error, stdout, stderr) {
            return util.log(stdout || 'Comando ejecutado');
          });
        }
      }
      return res.json(result, header);
    });
  });

  app.get(/^\/switch\/?([^\/+])/, function(req, res) {
    return res.json('Hello! I am Lindsay Lohan!');
  });

  puerto = config.port || 3000;

  app.listen(puerto);

}).call(this);
