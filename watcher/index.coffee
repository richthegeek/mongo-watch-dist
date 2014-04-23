module.exports = (options = {}) ->
	redis = require 'redis'
	client = redis.createClient()

	if master = @serverConfig?._state?.master
		options.host = master.host
		options.port = master.port

	# force these two optons
	options.convertObjectIDs = false
	options.format = 'normal'

	# ensure this works 
	options.heartbeat = Number(options.heartbeat) or 0
	options.heartbeat = Math.min 100, options.heartbeat

	do ensureWatcher = ->
		# set the key if it doesnt exist. If that works, start watching and begin the check-cycle
		# the time has a min value on it because redis seems to have slight delays on expiries and such.
		client.set ['mtran:watcher', process.pid, 'PX', Math.max(options.heartbeat, 500), 'NX'], (err, set) ->
			if err
				# todo: in an ideal world this would not throw
				throw err
			if not set
				# if we couldnt set it, loop back round to try again in a while
				return setTimeout ensureWatcher, options.hearbeat
			
			# MongoWatch = require 'mongo-watch'
			# waiting for PR merges
			MongoWatch = require '/home/richard/www/git/mongo-watch'
			watcher = new MongoWatch options
			watcher.debug 'Promoting to watcher'

			demote = ->
				watcher.debug 'Demoting from watcher'
				# try'd because watching on all causes issues
				try watcher.stop()
				setTimeout ensureWatcher, options.heartbeat

			# checking to ensure this watcher is still the only one
			setInterval (() ->
				# ensure we are still the watcher
				client.get 'mtran:watcher', (err, pid) ->
					demote() if pid isnt '0' and pid isnt process.pid.toString()
				# update the expiry, demoting if it failed
				client.pexpire 'mtran:watcher', (options.heartbeat + 100), (err, res) ->
					demote() if res is 0
			), options.heartbeat

			# post all events to the redis list in a normalised format
			watcher.watch 'all', (event) ->
				ns = event.namespace
				event.timestamp = event.timestamp.getTime()
				for op in event.oplist
					do (op) ->
						ev = {}
						ev[key] = val for key, val of event when key not in ['oplist', 'operationId']
						ev[key] = val for key, val of op

						type = Object::toString.call(ev.id).slice(8, -1)
						type = (if type is 'Object' then ev.id.constructor.name else type)
						ev.id = [type, ev.id].map String

						client.lpush ('mtran:events:' + ns), JSON.stringify(ev), ->
							watcher.debug 'OpLog > Redis latency: ' + (new Date - ev.timestamp) + 'ms'
