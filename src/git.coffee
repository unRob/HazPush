fs = require 'fs'
exec = require('child_process').exec
validator = require('validator').sanitize

Git = (dir) ->
	@submodules = false
	try
		@git_dir = fs.realpathSync dir
		process.chdir @git_dir
		console.log process.cwd()
		
		config = fs.readFileSync "#{@git_dir}/.git/config", 'utf8'
		@submodules = true if config.match /^\[submodule "[\w\d]+"\]/m
		
		
	catch error
		console.log 'error: '+error
		process.exit(1)
		
	return this

Git.create = (dir)->
	new Git dir


Git.prototype.status = (callback) ->
	status = exec "/usr/bin/env git status -s", (error, stdout, stderr) ->
		clean = validator(stdout).trim()
		
		cambios = []
		cambios = clean.split '\n' if clean.length isnt 0 
		callback cambios


Git.prototype.pull = (callback, repo='origin', branch='master') ->
	exec "/usr/bin/env git submodule update" if @submodules is true
	
	this.status (cambios)->
		if cambios.length>0
			callback {"error": true, "because": "Branch '#{branch}' has unstaged changes.", "changes": cambios}
		else
			status = exec "/usr/bin/env git pull #{repo} #{branch} 2>&1", (error, stdout, stderr) ->
				ret = validator(stdout).trim().split "\n"
				if ret.pop() is 'Already up-to-date.'
					callback {"error": true, "because": "Branch '#{branch}' is already up to date."}
				else
					lines = ret.slice 2
					update = validator(lines.shift()).trim()
					strategy = validator(lines.shift()).trim()
					summary = validator(lines.pop()).trim()
					changes = [];
					console.log("update: #{update}");
					for line of lines
						changes.push validator(line).trim()
						
					callback {"update":update, "strategy":strategy, "summary":summary, "changes":changes}
	

module.exports = Git