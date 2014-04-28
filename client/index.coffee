getRedisClient = ->
	if @client?
		return @client
	
	redis = require 'redis'
	@client = redis.createClient()

module.exports.watch = (name, options) ->
	if name.toString() is '[object Object]'
		options = name
		name = null

	name or= 'all'
	options or= {}

	options.name = name
	options.ops = [].concat options.ops or []

	if options.ops.length is 0 or 'all' in options.ops
		options.ops.push 'insert', 'update', 'remove'

	options.paths = [].concat options.paths or []
	options.ns = @db.databaseName + '.' + @collectionName

	if options.path
		options.paths.push options.path
		delete options.path

	# simply add a watch configuration to Redis and notify of a config change
	key = [@db.databaseName, @collectionName, name].join '.'
	client = getRedisClient()
	client.hset 'mtran:watchers', key, JSON.stringify options
	client.publish 'mtran:watchers', '+' + key

	return @

module.exports.unwatch = (name) ->
	# remove watch config from redis and notify of config change
	key = [@db.databaseName, @collectionName, name].join '.'
	client = @getRedisClient()
	client.hdel 'mtran:watchers', key
	client.publish 'mtran:watchers', '-' + key

	return @