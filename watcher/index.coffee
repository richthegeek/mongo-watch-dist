module.exports = (options = {}) ->
	redis = require 'redis'
	client = redis.createClient()

	if master = @serverConfig?._state?.master
		options.host = master.host
		options.port = master.port

	# force these two optons
	options.convertObjectIDs = false
	options.format = 'raw'

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
				# this special unset allows bypassing these events. nice and simple.
				if event.o?.$unset?.mtranNoop?
					return watcher.debug 'Skip event due to mtranNoop'

				if event.o2?
					id = event.o2._id
				else
					id = event.o._id
					delete event.o._id

				type = Object::toString.call(id).slice(8, -1)
				type = (if type is 'Object' then id.constructor.name else type)

				opmap =
					i: 'insert'
					u: 'update'
					d: 'remove'

				ev =
					id: [type, id].map String
					timestamp: event.ts.high_ * 1000
					operation: opmap[event.op]
					data: event.o

				client.lpush ('mtran:events:' + event.ns), JSON.stringify(ev), ->
					watcher.debug 'OpLog > Redis latency: ' + (new Date - ev.timestamp) + 'ms'
