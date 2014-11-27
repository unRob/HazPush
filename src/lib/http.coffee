express = require 'express'
git = require 'gift'
crypto = require 'crypto'
app = express()
Config = require './config'

Config.watch()

debug = false

HTTP_PORT = process.argv[2] || 3636

pad = (str)->
	str = str.toString()
	while str.length < 2
		str = "0#{str}"
	str

MyDate = ()->
	d = new Date()
	date = [d.getFullYear(), d.getMonth()+1, d.getDate()].map pad
	time = [d.getHours(), d.getMinutes(), d.getSeconds()].map pad
	str = "#{date.join('-')} #{time.join(':')}"


Log = (type, msg)->
	if !msg
		msg = type
		type = 'info'

	method = switch type
		when 'info' then console.log
		when 'warn' then console.warn
		when 'error' then console.error
		else console.log

	method "[#{type.toUpperCase()}] #{MyDate()} - #{msg}"


Log("Hazpush Server running on port: #{HTTP_PORT}")

app.use (req, res, next)->
	data = ''
	req.setEncoding('utf8')
	req.on 'data', (chunk)->
		data += chunk

	req.on 'end', ()->
		req.rawBody = data
		next()


app.all /\/pull\/([\w-\/]+)/, (req, res)->
	repo = req.params[0]
	repos = Config.get('repos')
	if !repos
		msg = "There are no repos configured. Try `hazpush add`"
		Log('error', msg)
		res.status(500).send(msg)
		return

	info = repos[repo]
	unless info
		Log('error', "Repo not configured: #{repo}")
		res.status(404).send('Repo not found');
		return

	Log("Pull requested for #{repo}");

	try
		signature = req.headers['x-hub-signature'].split('=')[1]
	catch err
		Log('error', "Could not parse Github's signature")
		res.status(401).send('Invalid Signature')
		return

	verified = crypto.createHmac('sha1', info.secret).update(new Buffer(req.rawBody)).digest('hex')
	if signature isnt verified
		Log('error', "Invalid signature, got: <#{signature}>, expected: <#{verified}>");
		res.status(401).send('Invalid signature');
		return


	git_error = (err)->
		Log 'error', "Git error: #{err}"
		return res.status(500).send("Git error: #{err}");

	git_repo = git(info.path)

	git_repo.status (err, status)->
		return git_error(err) if err

		if status.clean isnt true
			error =
				error: "Can't pull, unstaged changes"
				changes: status.files
			Log('warn', error.error)
			return res.json(409, error)

		git_repo.pull (err)->
			return git_error(err) if err
			Log "Pulled"
			res.status(200).send('Pulled');


server = app.listen HTTP_PORT, ()->
	address = server.address()
	Log("Listening on #{address.address}:#{address.port}")