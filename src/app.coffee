fs = require 'fs'
express = require 'express'
validator = require('validator').sanitize
crypto = require('crypto')
exec = require('child_process').exec
util = require 'util'


app = express.createServer()
configFile = process.argv[2]
config = JSON.parse fs.readFileSync configFile, 'utf8'
git = require('./git').create config.git_dir


app.configure ()->
	app.use app.router;

auth = (app, req, next) ->
	app.res.header 'X-Powered-by', 'HazPush/1.0b'
	
	if config.github
		if req.connection.remoteAddress in ['207.97.227.253', '50.57.128.197', '108.171.174.178']
			return next()
		else
			return app.res.json({error: "Auth FAIL!"}, 401)
	
	signature = req.req.headers['x-auth']
	if !signature?
		return app.res.json({error: "Auth FAIL!"}, 401)
	
	signer = crypto.createHmac('sha256', new Buffer config.key, 'utf8')
	verbo = app.method
	url = req.req.url
	expected = signer.update("#{app.method}::#{req.req.url}").digest 'hex'
	if signature isnt expected
		util.log "#{signature} != #{expected}"
		return app.res.json({error: "Auth FAIL!"}, 401)
		
	next()

app.get '/status', auth, (req, res) ->
	git.status (cambios) ->
		res.json(cambios)


app.all '/pull', auth, (req, res) ->
	git.pull (result) ->
		header = 200
		header = 409 if 'error' of result is true
		if config.hooks.pull
			util.log "Calling pull hooks"
			for hook in config.hooks.pull
				util.log hook
				exec hook, (error, stdout, stderr) ->
					util.log stdout||'Comando ejecutado'
				
		res.json(result, header)
	
	
app.get /^\/switch\/?([^\/+])/, (req, res) ->
	res.json('Hello! I am Lindsay Lohan!')
		
puerto = config.port || 3000;	
app.listen puerto