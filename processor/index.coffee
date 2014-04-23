Mongo = require 'mongodb'
MongoWatch = require 'mongo-watch'
redis = require 'redis'

makePaths = require './_makePaths'

module.exports = class Processor

	@STOPPED: 0
	@PAUSED: 1
	@RUNNING: 2

	constructor: (@collection, @options, @callback) ->
		@queue = 'mtran:events:' + [@collection.db.databaseName, @collection.collectionName].join '.'
		@redis = redis.createClient()
		@loop()
		@resume()

	resume: ->
		@state = Processor.RUNNING

	pause: ->
		@state = Processor.PAUSED

	stop: ->
		@state = Processor.STOPPED

	loop: (err) ->
		if err
			throw err

		if @state is Processor.PAUSED
			return process.nextTick @loop.bind @

		if @state is Processor.STOPPED
			return null

		@redis.brpop @queue, 0, (err, resp) =>
			if err
				return @loop err

			if not resp
				return setTimeout @loop.bind(@), 100

			[queue, data] = resp

			try
				item = JSON.parse data
			catch err
				return @loop err

			if not @options[item.operation]
				return @loop()

			paths = makePaths item.data, item.path
			allowed = [].concat @options.paths or []
			if allowed.length > 0
				if not paths.some((path) -> path in allowed)
					return @loop()
		
			[type, id] = item.id
			if type is 'ObjectID'
				id = Mongo.ObjectID.createFromHexString id
			else if global[type]
				id = new global[type] id

			query = @options.query or {}
			query._id = id

			@collection.findOne query, (err, input) =>
				if err
					return @loop err
				if not input
					return @loop()

				@callback input, (err, output) =>
					end = +new Date
					console.log 'Latency:', end - item.timestamp + 'ms'
					@loop err
