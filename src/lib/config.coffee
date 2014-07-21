fs = require 'fs'
path = require 'path'

HAZPUSHRC = "#{process.env['HOME']}/.hazpushrc"

load = ()->
	try
		data = JSON.parse(fs.readFileSync(HAZPUSHRC))
	catch err
		data = {}
	return data

data = load()
	
save = ()->
	fs.writeFile HAZPUSHRC, JSON.stringify(data), (err)->
		if err
			console.error('Could not save config to disk', err);



Config =
	reload: false
	get: (key)->
		data = load() if Config.reload
		data[key]
	set: (key, value)->
		data[key] = value
		save()
	remove: (key)->
		delete data[key]
		save()
	watch: ()->
		Config.reload=true

module.exports = Config