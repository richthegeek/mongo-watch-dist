mtran = require './index'

mongo = require 'mongodb'
mtran.attach mongo

mongo.MongoClient.connect 'mongodb://127.0.0.1:27017/mtran', (err, db) ->

	coll = db.collection 'numbers'

	# coll.watch 'doubler'

	# mtran.ensureWatcher {}
	db.ensureWatcher {onDebug: console.log}

	# coll.insert {number: 1}, -> null
	# coll.update {}, {$set: number: 1}, {multi: true}, -> console.log arguments