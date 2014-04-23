module.exports =
	attach: (mongo) ->
		fns = require './client'
		for key, fn of fns when 'function' is typeof fn
			mongo.Collection::[key] = fn

		mongo.Collection::process = (options, callback) ->
			fn = require './processor'
			new fn @, options, callback

		mongo.ensureWatcher = mongo.Db::ensureWatcher = mongo.Collection::ensureWatcher = require './watcher'