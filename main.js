// Generated by CoffeeScript 1.7.1
(function() {
  var APP_NAME, Config, Tail, add, checkAuth, die, fs, git, github, githubAPI, noop, parser, path, prompt, server, setup, spawn;

  parser = require('nomnom');

  githubAPI = require('github');

  git = require('gift');

  prompt = require('prompt');

  path = require('path');

  fs = require('fs');

  spawn = require('child_process').spawn;

  Tail = require('tail').Tail;

  Config = require('./lib/config');


  /*
  	Config
   */

  APP_NAME = 'Hazpush Authorization (API)';

  prompt.message = '';

  prompt.delimiter = '';

  checkAuth = function() {
    var token;
    token = Config.get('github_token');
    if (!token) {
      console.error('You have not authenticated yet with Github, can\'t continue');
      console.error('run `hazpush setup` before');
      process.exit(255);
    }
    return github.authenticate({
      type: 'oauth',
      token: token
    });
  };

  github = new githubAPI({
    version: '3.0.0',
    debug: false
  });

  die = function(who) {
    var code;
    if (who == null) {
      who = 'user';
    }
    code = who === 'user' && {
      255: 1
    };
    return process.exit(code);
  };

  noop = function() {
    return null;
  };

  setup = parser.command('setup');

  setup.help('Setup your credentials for github access');

  setup.callback(function(opts) {
    var auth_github, schema;
    prompt.start();
    schema = {
      properties: {
        host: {
          description: 'Which domain will I listen to?',
          required: true
        },
        port: {
          description: 'What will be the port?',
          "default": 3000
        },
        username: {
          description: 'Enter your Github username',
          required: true
        },
        password: {
          description: 'Enter your Github password',
          required: true,
          hidden: true
        }
      }
    };
    auth_github = true;
    if (Config.get('github_token')) {
      delete schema.properties.username;
      delete schema.properties.password;
      auth_github = false;
    }
    return prompt.get(schema, function(err, res) {
      var authorization_details, url;
      url = "http://" + res.host + ":" + res.port;
      console.log("Saving webhook url as " + url);
      Config.set('host', res.host);
      Config.set('port', res.port);
      if (auth_github) {
        github.authenticate({
          type: 'basic',
          username: res.username,
          password: res.password
        });
        authorization_details = {
          scopes: ['write:repo_hook'],
          note: 'Hazpush Authorization'
        };
        return github.authorization.getAll({}, function(err, authorizations) {
          var authorization, token, _i, _len;
          if (err) {
            console.error('Could not login', err);
            die();
          }
          token = null;
          for (_i = 0, _len = authorizations.length; _i < _len; _i++) {
            authorization = authorizations[_i];
            if (authorization.app.name === APP_NAME) {
              token = authorization.token;
              break;
            }
          }
          if (!token) {
            return github.authorization.create(authorization_details, function(err, res) {
              if (err) {
                console.error('Could not get OAuth token', err);
                die();
              }
              token = res.token;
              Config.set('github_token', token);
              return console.log("Authentication successfully stored");
            });
          } else {
            Config.set('github_token', token);
            return console.log("Authentication successfully stored");
          }
        });
      }
    });
  });

  add = parser.command('add');

  add.option('repo', {
    abbr: 'r',
    help: 'The path to the repo',
    "default": '.',
    required: true,
    metavar: 'PATH',
    position: 1
  });

  add.help('Add a repository to the list');

  add.callback(function(opts) {
    var repo, repo_path;
    checkAuth();
    repo_path = path.resolve(opts.repo);
    if (!fs.existsSync("" + repo_path + "/.git")) {
      console.error("" + repo_path + " is not a git repo (could not find .git within)");
      die();
    }
    repo = git(repo_path);
    return repo.config(function(err, cfg) {
      var gh_url, hook, newInfo, origin, repos, secret, url, user, _ref;
      if (err) {
        console.error("Could not open repo", err);
        die();
      }
      origin = cfg['remote.origin.url'];
      if (!(origin = ~/github\.com/)) {
        console.error("This repo does not seem to be published to github");
        die();
      }
      gh_url = origin.split(/:/)[1].replace('.git', '');
      console.log("Trying to set hooks for " + gh_url);
      _ref = gh_url.split('/'), user = _ref[0], repo = _ref[1];
      secret = require('crypto').randomBytes(16).toString('hex');
      url = "http://" + (Config.get('host')) + ":" + (Config.get('port')) + "/pull/" + gh_url;
      hook = {
        user: user,
        repo: repo,
        name: 'web',
        config: {
          url: url,
          content_type: 'json',
          secret: secret
        }
      };
      repos = Config.get('repos') || {};
      newInfo = {
        path: repo_path,
        secret: secret
      };
      return github.repos.getHooks({
        user: hook.user,
        repo: hook.repo
      }, function(err, hooks) {
        var h, hook_exists, _i, _len;
        if (err) {
          console.log(err);
          die();
        } else {
          hook_exists = false;
          for (_i = 0, _len = hooks.length; _i < _len; _i++) {
            h = hooks[_i];
            if (h.config.url === url) {
              if (repos.hasOwnProperty(gh_url)) {
                newInfo.id = h.id;
                newInfo.secret = repos[gh_url].secret;
                hook_exists = true;
              } else {
                github.repos.deleteHook({
                  repo: repo,
                  user: user,
                  id: h.id
                }, noop);
              }
              break;
            }
          }
        }
        if (hook_exists) {
          console.log("This repo already has the webhook, updating info...");
          repos[gh_url] = newInfo;
          Config.set('repos', repos);
          return console.log("Done");
        } else {
          console.log("Adding webhook to the repo...");
          return github.repos.createHook(hook, function(err, res) {
            if (err) {
              return console.log(err);
            } else {
              repos[gh_url] = newInfo;
              repos[gh_url].id = res.id;
              Config.set('repos', repos);
              return console.log("Done");
            }
          });
        }
      });
    });
  });

  server = parser.command('server');

  server.option('signal', {
    abbr: 's',
    help: '[start | stop | logs | tail]',
    required: true,
    metavar: 'PATH',
    position: 1
  });

  server.help('Control the http daemon');

  server.callback(function(opts) {
    var args, err, log, logFD, logPath, pid, port, proc, tail, validOpts;
    checkAuth();
    validOpts = ['start', 'stop', 'logs', 'tail'];
    if (validOpts.indexOf(opts.signal) === -1) {
      console.log("Valid options for `server` are [" + (validOpts.join(' | ')) + "]");
      die();
    }
    logPath = "" + process.env['HOME'] + "/.hazpush.log";
    switch (opts.signal) {
      case 'start':
        logFD = fs.openSync(logPath, 'a+');
        opts = {
          detached: true,
          cwd: __dirname,
          stdio: [logFD, logFD, logFD]
        };
        port = Config.get('port');
        args = ["" + __dirname + "/lib/http.js", port];
        proc = spawn('node', args, opts);
        proc.unref();
        Config.set('running', proc.pid);
        return console.log("Started hazpush Server on port " + port + ". [pid " + proc.pid + "]");
      case 'stop':
        pid = Config.get('running');
        if (!pid) {
          console.log('Server is not running');
          die();
        }
        console.log("Stopping server [pid " + pid + "]");
        try {
          process.kill(pid);
        } catch (_error) {
          err = _error;
          console.error(err);
          console.error("Server was not running or could not be killed.");
        }
        return Config.remove('running');
      case 'logs':
        log = fs.createReadStream(logPath);
        return log.on('data', function(buff) {
          return console.log(buff.toString());
        });
      case 'tail':
        tail = new Tail(logPath);
        return tail.on('line', console.log);
    }
  });

  parser.parse();

}).call(this);
