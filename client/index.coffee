Mongo = require 'mongodb'

getRedisClient = ->
	if @client?
		return @client
	
	redis = require 'redis'
	@client = redis.createClient()

Mongo.Collection::watch = (name, options = {}) ->
	# simply add a watch configuration to Redis and notify of a config change
	name = [@db.databaseName, @collectionName, name].join '.'
	client = getRedisClient()
	client.hset 'mtran:watchers', name, JSON.stringify options
	client.publish 'mtran:watchers', '+' + name

Mongo.Collection::unwatch = (name) ->
	# remove watch config from redis and notify of config change
	name = [@db.databaseName, @collectionName, name].join '.'
	client = @getRedisClient()
	client.hdel 'mtran:watchers', name
	client.publish 'mtran:watchers', '-' + name
