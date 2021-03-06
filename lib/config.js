// Generated by CoffeeScript 1.10.0
(function() {
  var Config, HAZPUSHRC, data, fs, load, path, save;

  fs = require('fs');

  path = require('path');

  HAZPUSHRC = process.env['HOME'] + "/.hazpushrc";

  load = function() {
    var data, err, error;
    try {
      data = JSON.parse(fs.readFileSync(HAZPUSHRC));
    } catch (error) {
      err = error;
      data = {};
    }
    return data;
  };

  data = load();

  save = function() {
    return fs.writeFile(HAZPUSHRC, JSON.stringify(data), function(err) {
      if (err) {
        return console.error('Could not save config to disk', err);
      }
    });
  };

  Config = {
    reload: false,
    get: function(key) {
      if (Config.reload) {
        data = load();
      }
      return data[key];
    },
    set: function(key, value) {
      data[key] = value;
      return save();
    },
    remove: function(key) {
      delete data[key];
      return save();
    },
    watch: function() {
      return Config.reload = true;
    }
  };

  module.exports = Config;

}).call(this);
