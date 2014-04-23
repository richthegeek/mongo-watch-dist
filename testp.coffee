mtran = require './index'

mongo = require 'mongodb'
mtran.attach mongo

mongo.MongoClient.connect 'mongodb://127.0.0.1:27017/test', (err, db) ->

	coll = db.collection 'numbers'

	opts =
		ops: ['insert', 'update']
		paths: ['numbers']
		onProcessed: ({times}) ->
			console.log times

	coll.process opts, (row, extra, done) ->
		average = row.numbers.reduce((a, b) -> Number(a) + Number(b)) / row.numbers.length
		coll.update {_id: row._id}, {$set: {average}}, done

	opts =
		ops: ['update']
		paths: ['average']
		onProcessed: ({times}) ->
			console.log times
	coll.process opts, (row, extra, done) ->
		coll.update {_id: row._id}, {$set: {average: row.average.toString()}}, done
