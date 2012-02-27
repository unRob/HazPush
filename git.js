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
      if (cambios.length > 0) {
        return callback({
          "error": true,
          "because": "Branch '" + branch + "' has unstaged changes.",
          "changes": cambios
        });
      } else {
        return status = exec("/usr/bin/env git pull " + repo + " " + branch + " 2>&1", function(error, stdout, stderr) {
          var changes, line, lines, ret, strategy, summary, update;
          ret = validator(stdout).trim().split("\n");
          if (ret.pop() === 'Already up-to-date.') {
            return callback({
              "error": true,
              "because": "Branch '" + branch + "' is already up to date."
            });
          } else {
            lines = ret.slice(2);
            update = validator(lines.shift()).trim();
            strategy = validator(lines.shift()).trim();
            summary = validator(lines.pop()).trim();
            changes = [];
            console.log("update: " + update);
            for (line in lines) {
              changes.push(validator(line).trim());
            }
            return callback({
              "update": update,
              "strategy": strategy,
              "summary": summary,
              "changes": changes
            });
          }
        });
      }
    });
  };

  module.exports = Git;

}).call(this);
