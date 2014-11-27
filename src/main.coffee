parser = require 'nomnom'
githubAPI = require 'github'
git = require 'gift'
prompt = require 'prompt'
path = require 'path'
fs = require 'fs'
spawn = require('child_process').spawn
Tail = require('tail').Tail

Config = require './lib/config'

###
	Config
###
APP_NAME = 'Hazpush Authorization (API)'
prompt.message = ''
prompt.delimiter = ''
checkAuth = ()->
	token = Config.get('github_token')
	unless token
		console.error('You have not authenticated yet with Github, can\'t continue')
		console.error('run `hazpush setup` before')
		process.exit(255)

	github.authenticate({
		type: 'oauth',
		token: token
	})

github = new githubAPI {
	version: '3.0.0',
	debug: false
}

die = (who='user')->
	code = who=='user' && 255 : 1;
	process.exit(code);

noop = ()->	return null;

########



setup = parser.command('setup')
setup.help('Setup your credentials for github access')
setup.callback (opts)->
	prompt.start()
	schema =
		properties: {
			host: {
				description: 'Which domain will I listen to?',
				required: true
			},
			port: {
				description: 'What will be the port?',
				default: 3000
			}
			username: {
				description: 'Enter your Github username'
				required: true
			},
			password: {
				description: 'Enter your Github password'
				required: true,
				hidden: true
			}
		}

	auth_github = true
	if Config.get('github_token')
		delete schema.properties.username
		delete schema.properties.password
		auth_github = false

	prompt.get schema, (err, res)->

		url = "http://#{res.host}:#{res.port}"
		console.log("Saving webhook url as #{url}")
		Config.set('host', res.host)
		Config.set('port', res.port)

		do_auth = (data, on_success)->
			github.authenticate(data)

			github.authorization.getAll {}, (err, response)->
				if err
					console.log(err)
					if err.message.match /OTP/
						getOTP =
							properties: {
								OTP: {
									description: "Enter your OTP",
									required: true
								}
							}
						prompt.get getOTP, (err, res)->
							if (err)
								die err
							else
								github.authorization.getAll {headers: {'X-GitHub-OTP': res.OTP}}, (err, res)->
									if err
										console.log(err)
									else
										on_success(res)

					else
						console.log "Could not login"
						console.log(err)
						die
				else
					console.log(response)
					on_success(response)

		authorization_details =
			scopes: ['write:repo_hook'],
			note: 'Hazpush Authorization',


		if auth_github
			auth_data = {
				type: 'basic',
				username: res.username,
				password: res.password
			}
			do_auth auth_data, (authorizations)->
				token = null
				for authorization in authorizations
					if authorization.app.name == APP_NAME
						token = authorization.token
						break;


				unless token
					github.authorization.create authorization_details, (err, res)->
						if (err)
							console.error('Could not get OAuth token', err);
							die()

						token = res.token
						Config.set('github_token', token)
						console.log("Authentication successfully stored")
				else
					Config.set('github_token', token)
					console.log("Authentication successfully stored")


add = parser.command 'add'
add.option 'repo', {
	abbr: 'r',
	help: 'The path to the repo',
	default: '.',
	required: true,
	metavar: 'PATH',
	position: 1
}
add.help 'Add a repository to the list'
add.callback (opts)->
	checkAuth()
	repo_path = path.resolve(opts.repo)

	unless fs.existsSync "#{repo_path}/.git"
		console.error("#{repo_path} is not a git repo (could not find .git within)")
		die()


	repo = git repo_path

	repo.config (err, cfg)->
		if err
			console.error("Could not open repo", err);
			die()

		origin = cfg.items['remote.origin.url']
		if !(origin.match(/github\.com/)) || !origin
			console.error("This repo does not seem to be published to github")
			die()

		gh_url = origin.split(/:/)[1].replace('.git', '').replace(/^\//, '')
		console.log("Trying to set hooks for #{gh_url}")

		[user, repo] = gh_url.split('/')
		secret = require('crypto').randomBytes(16).toString('hex')
		url = "http://#{Config.get('host')}:#{Config.get('port')}/pull/#{gh_url}"

		hook =
			user: user,
			repo: repo,
			name: 'web',
			config: {
				url: url,
				content_type: 'json',
				secret: secret
			}

		repos = Config.get('repos') || {}

		newInfo = {
			path: repo_path,
			secret: secret
		}


		github.repos.getHooks {user: hook.user, repo: hook.repo}, (err,hooks)->
			if err
				console.log(err)
				die()
			else
				hook_exists = false
				for h in hooks
					if h.config.url == url
						if repos.hasOwnProperty(gh_url)
							newInfo.id = h.id
							newInfo.secret = repos[gh_url].secret
							hook_exists = true
						else
							# Delete the hook, since we can't get the secret from GH
							github.repos.deleteHook({repo: repo, user: user, id: h.id}, noop)
						break;


			if hook_exists
				console.log("This repo already has the webhook, updating info...")
				repos[gh_url] = newInfo
				Config.set('repos', repos)
				console.log("Done")
			else
				console.log("Adding webhook to the repo...")
				github.repos.createHook hook, (err, res)->
					if (err)
						console.log(err)
					else
						repos[gh_url] = newInfo
						repos[gh_url].id = res.id
						Config.set('repos', repos)
						console.log("Done")


server = parser.command 'server'
server.option 'signal', {
	abbr: 's',
	help: '[start | stop | logs | tail]',
	required: true,
	metavar: 'PATH',
	position: 1
}
server.help 'Control the http daemon'
server.callback (opts)->
	checkAuth()

	validOpts = ['start', 'stop', 'logs', 'tail']
	if validOpts.indexOf(opts.signal) == -1
		console.log "Valid options for `server` are [#{validOpts.join(' | ')}]"
		die()

	logPath = "#{process.env['HOME']}/.hazpush.log"

	switch opts.signal
		when 'start'
			logOut = fs.openSync(logPath, 'a+');
			# repeated because ubuntu refuses to open the same FD twice or some shit like that
			logErr = fs.openSync(logPath, 'a+');
			opts =
				detached: true,
				cwd: __dirname
				stdio: ['ignore', logErr, logOut]

			port = Config.get('port')

			args = ["#{__dirname}/lib/http.js", port]
			proc = spawn('/usr/bin/node', args, opts)
			proc.unref()
			Config.set('running', proc.pid)
			console.log("Started hazpush Server on port #{port}. [pid #{proc.pid}]")
		when 'stop'
			pid = Config.get('running')
			if !pid
				console.log('Server is not running')
				die()

			console.log "Stopping server [pid #{pid}]"
			try
				process.kill(pid)
			catch err
				console.error(err)
				console.error("Server was not running or could not be killed.")
			Config.remove('running')
		when 'logs'
			log = fs.createReadStream(logPath)
			log.on 'data', (buff)-> console.log(buff.toString())
		when 'tail'
			tail = new Tail(logPath)
			tail.on 'line', console.log

parser.parse()