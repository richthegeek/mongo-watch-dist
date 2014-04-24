Mongo = require 'mongodb'
MongoWatch = require 'mongo-watch'
redis = require 'redis'

makePaths = require './_makePaths'

module.exports = class Processor

	@STOPPED: 0
	@PAUSED: 1
	@RUNNING: 2

	constructor: (@collection, @options, @callback) ->
		@options.ops = [].concat(@options.ops or []).map(String)
		@options.paths = [].concat(@options.paths or []).map(String)
		@options.query or= (q) -> q
		@options.process or= -> true
		@options.onProcessed or= -> null

		if 'all' in @options.ops
			@options.ops.push 'insert', 'update', 'remove'

		@queue = 'mtran:events:' + [@collection.db.databaseName, @collection.collectionName].join('.')
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

		@redis.brpoplpush @queue, @queue.replace(':events:', ':processing:'), 0, (err, data) =>
			if err
				return @loop err

			if not data
				return setTimeout @loop.bind(@), 100

			times = {}
			startTime = new Date

			try
				item = JSON.parse data
			catch err
				return @loop err

			if item.operation not in @options.ops
				console.log 'Ignored op'
				return @loop()

			item.paths = makePaths item.data, item.path
			if @options.paths.length > 0 and not item.paths.some((path) => path in @options.paths)
				console.log 'Ignored path'
				return @loop()

			if not @options.process item
				console.log 'Not processed'
				return @loop()

			[type, id] = item.id
			fns =
				'ObjectID': Mongo.ObjectID.createFromHexString
				'String': (id) -> id.toString()
				'Number': (id) -> Number(id).valueOf()
			if fns[type]
				id = fns[type] id
			else if global[type]
				id = new global[type] id

			query = @options.query {_id: id}, item
			times.loadEvent = new Date

			getRow = @collection.findOne.bind @collection
			if item.operation is 'remove'
				getRow = (query, next) -> next null, {_id: query._id}
			
			getRow query, (err, input) =>
				if err
					return @loop err
				if not input
					console.log 'Not found'
					return @loop()

				extra =
					event: item
					query: query
					noop: (data) ->
						data.$unset ?= {}
						data.$unset.mtranNoop = 1
						return data

				times.loadRow = new Date
				@callback input, extra, (err, output) =>
					times.complete = +new Date
					for key, val of times
						times[key] = val - startTime
					times.full = new Date - item.timestamp

					@options.onProcessed {
						input: input,
						output: output,
						event: item,
						query: query,
						times: times
					}
					@loop err
