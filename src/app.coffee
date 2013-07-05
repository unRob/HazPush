fs = require 'fs'
express = require 'express'
validator = require('validator').sanitize
crypto = require('crypto')
exec = require('child_process').exec
util = require 'util'


app = express()
configFile = process.argv[2]
config = JSON.parse fs.readFileSync configFile, 'utf8'
git = require('./git').create config.git_dir


app.configure ()->
	app.use app.router;

auth = (req, res, next) ->
	res.header 'X-Powered-by', 'HazPush/1.0b'
	config.blocks = config.blocks || []
	
	if config.github
		Netmask = require('netmask').Netmask
		blocks = ['204.232.175.64/27', '192.30.252.0/22'].concat config.blocks
		thisIP = req.ip
		util.log("GH request from: #{thisIP}");

		for index, block of blocks
			b = new Netmask(block);
			if b.contains thisIP
				util.log('FFFFFOUND');
				return next()
		
		res.send(403, {error: "Auth FAIL!"})
		return false;
	
	
	signature = req.get 'x-auth'
	if !signature?
		return res.json(403, {error: "Auth FAIL!"})
	
	signer = crypto.createHmac('sha256', new Buffer config.key, 'utf8')
	verbo = app.method
	url = req.url
	expected = signer.update("#{req.method}::#{req.url}").digest 'hex'
	if signature isnt expected
		util.log "#{signature} != #{expected}"
		return res.json(403, {error: "Auth FAIL!"})
		
	next()

app.get '/status', auth, (req, res) ->
	git.status (cambios) ->
		res.json(cambios)


app.all '/pull', auth, (req, res) ->
	git.pull (result) ->
		header = 200
		header = 409 if 'error' of result is true

		util.log 'Pull';

		if config.hooks && config.hooks.pull
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