(function() {
  var Git, exec, fs, validator;

  fs = require('fs');

  exec = require('child_process').exec;

  validator = require('validator').sanitize;

  Git = function(dir) {
    var config;
    this.submodules = false;
    try {
      this.git_dir = fs.realpathSync(dir);
      process.chdir(this.git_dir);
      console.log(process.cwd());
      config = fs.readFileSync("" + this.git_dir + "/.git/config", 'utf8');
      if (config.match(/^\[submodule "[\w\d]+"\]/m)) this.submodules = true;
    } catch (error) {
      console.log('error: ' + error);
      process.exit(1);
    }
    return this;
  };

  Git.create = function(dir) {
    return new Git(dir);
  };

  Git.prototype.status = function(callback) {
    var status;
    return status = exec("/usr/bin/env git status -s", function(error, stdout, stderr) {
      var cambios, clean;
      clean = validator(stdout).trim();
      cambios = [];
      if (clean.length !== 0) cambios = clean.split('\n');
      return callback(cambios);
    });
  };

  Git.prototype.pull = function(callback, repo, branch) {
    if (repo == null) repo = 'origin';
    if (branch == null) branch = 'master';
    if (this.submodules === true) exec("/usr/bin/env git submodule update");
    return this.status(function(cambios) {
      var status;
      console.log(cambios);
      if (cambios.length > 0) {
        return callback({
          "error": true,
          "because": "Branch '" + branch + "' has unstaged changes.",
          "changes": cambios
        });
      } else {
        return status = exec("/usr/bin/env git pull " + repo + " " + branch, function(error, stdout, stderr) {
          var ret;
          ret = validator(stdout).trim();
          if (ret === 'Already up-to-date.') {
            return callback({
              "error": true,
              "because": "Branch '" + branch + "' is already up to date."
            });
          } else {
            return callback(stdout);
          }
        });
      }
    });
  };

  module.exports = Git;

}).call(this);
