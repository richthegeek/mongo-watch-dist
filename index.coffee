module.exports =
	attach: (mongo) ->
		fns = require './client'
		for key, fn of fns when 'function' is typeof fn
			mongo.Collection::[key] = fn

		mongo.Collection::process = (name, options, callback) ->
			fn = require './processor'
			new fn @, name, options, callback

		mongo.Collection::watchAndProcess = (name, options, callback) ->
			watchOpts = {}
			for key in ['ops', 'paths'] when options[key]?
				watchOpts[key] = options[key]

			@watch name, watchOpts
			@process name, options, callback

		mongo.ensureWatcher = mongo.Db::ensureWatcher = mongo.Collection::ensureWatcher = require './watcher'