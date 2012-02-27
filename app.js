(function() {
  var app, auth, config, configFile, crypto, express, fs, git, validator;

  fs = require('fs');

  express = require('express');

  validator = require('validator').sanitize;

  crypto = require('crypto');

  app = express.createServer();

  configFile = process.argv[2];

  config = JSON.parse(fs.readFileSync(configFile, 'utf8'));

  git = require('./git').create(config.git_dir);

  console.log(git);

  app.configure(function() {
    return app.use(app.router);
  });

  auth = function(app, req, next) {
    var expected, signature, signer, url, verbo;
    app.res.header('X-Powered-by', 'HazPush/1.0b');
    signature = req.req.headers['x-auth'];
    if (!(signature != null)) {
      return app.res.json({
        error: "Auth FAIL!"
      }, 401);
    }
    signer = crypto.createHmac('sha256', config.key);
    verbo = app.method;
    url = req.req.url;
    expected = signer.update("" + app.method + "::" + req.req.url).digest('hex');
    if (signature !== expected) {
      console.log("" + signature + " != " + expected);
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
      var header;
      header = 200;
      if ('error' in result === true) header = 409;
      return res.json(result, header);
    });
  });

  app.get(/^\/switch\/?([^\/+])/, function(req, res) {
    return res.json('Hello! I am Lindsay Lohan!');
  });

  app.listen(3000);

}).call(this);
