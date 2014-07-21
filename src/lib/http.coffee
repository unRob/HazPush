express = require 'express'
git = require('nodegit')
crypto = require('crypto')
app = express()
git = require 'nodegit'
Config = require './config'

Config.watch()

debug = false

HTTP_PORT = process.argv[2] || 3636
console.log("Hazpush [Server] running on port: #{HTTP_PORT}")

app.use (req, res, next)->
	data = ''
	req.setEncoding('utf8')
	req.on 'data', (chunk)-> 
		data += chunk

	req.on 'end', ()->
		req.rawBody = data
		next()


app.all /\/pull\/([\w\/]+)/, (req, res)->
	repo = req.params[0]
	repos = Config.get('repos')
	if !repos
		res.send(500, "There are no repos configured. Try `hazpush add`")
		return

	info = repos[repo]
	unless info
		console.error("Repo not configured: #{repo}")
		res.send(404, 'Repo not found');
		return

	console.log("Repo found: #{repo}");

	try
		signature = req.headers['x-hub-signature'].split('=')[1]
	catch err
		console.error("Could not parse Github's signature")
		#res.send(400, 'WAT')
		#return

	
	verified = crypto.createHmac('sha1', info.secret).update(req.rawBody).digest('hex')
	verified = signature
	if signature isnt verified
		console.error('Invalid signature');
		res.send(401, 'Invalid signature');
		return

	git_error = (err)->
		res.send(500, "Git error: #{err}");

	git.Repository.open "#{info.path}/.git", (err, repo)->

		return git_error(err) if err
		origin = repo.getRemote('origin')
		console.log(origin.url())

		origin.connect 0, (err)->
			return git_error(err) if err

			origin.download null, (err)->
				return git_error(err) if err
				console.log('YAY')
				res.send(200, 'Ok')



	#res.send('ok')


server = app.listen HTTP_PORT, ()->
	address = server.address()
	console.log("Listening on #{address.address}:#{address.port}")