mtran = require './index'

mongo = require 'mongodb'
mtran.attach mongo

mongo.MongoClient.connect 'mongodb://127.0.0.1:27017/test', (err, db) ->

	coll = db.collection 'numbers'

	opts =
		set: true
		unset: false
		paths: ['numbers']
		query: {numbers: {$exists: true}}

	coll.process opts, (row, done) ->
		average = row.numbers.reduce((a, b) -> Number(a) + Number(b)) / row.numbers.length
		coll.update {_id: row._id}, {$set: {average}}, done
