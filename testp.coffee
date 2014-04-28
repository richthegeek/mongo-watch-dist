async = require 'async'
mtran = require './index'

mongo = require 'mongodb'
mtran.attach mongo

mongo.MongoClient.connect 'mongodb://127.0.0.1:27017/test', (err, db) ->

	# this is a complete JOIN example, which maintains a link 
	# between users and posts in a user_posts collection.

	users = db.collection 'users'
	posts = db.collection 'posts'
	user_posts = db.collection 'user_posts'

	users.remove -> posts.remove -> user_posts.remove ->
		users.insert {_id: 'richard', name: 'Richard Lyon'}, ->
			posts.insert [
				{_id: 1, user_id: 'richard', title: 'My first post'}
				{_id: 2, user_id: 'richard', title: 'A redaction on that first post'}
			], ->

				map = ->
					output = _id: this._id, user: this, posts: []
					if this.user_id?
						output = _id: this.user_id, user: null, posts: [this]
					emit output._id, output

				reduce = (key, values) ->
					return values.reduce((out, row) ->
						out.user = row.user or out.user
						out.posts = out.posts.concat row.posts
						return out
					, {user: null, posts: []})

				posts.mapReduce map, reduce, {out: reduce: 'user_posts'}, ->
					users.mapReduce map, reduce, {out: reduce: 'user_posts'}, ->
						user_posts.findOne (err, row) ->
							console.log row

	# posts.watchAndProcess 'insert', {ops: 'insert'}, (post, extra, done) ->
	# 	copy = JSON.parse JSON.stringify post
	# 	delete copy.user_id
	# 	user_posts.update {_id: post.user_id}, {$push: posts: copy}, done

	# posts.watchAndProcess 'update', {ops: 'update'}, (post, extra, done) ->
	# 	user_posts.update {_id: post.user_id}, {$pull: {posts: {_id: post._id}}}, (err, updated) ->
	# 		return done err if err
	# 		user_posts.update {_id: post.user_id}, {$push: posts: post}, done
	
	# posts.watchAndProcess 'remove', {ops: 'remove'}, (post, extra, done) ->
	# 	user_posts.update {_id: post.user_id}, {$pull: {posts: {_id: post._id}}}, done

	# users.watchAndProcess 'modify', {ops: ['insert', 'update']}, (user, extra, done) ->
	# 	copy = JSON.parse JSON.stringify user
	# 	delete copy._id
	# 	user_posts.update {_id: user._id}, {$set: user: copy}, {upsert: true}, done
	
	# users.watchAndProcess 'remove', {ops: 'remove'}, (user, extra, done) ->
	# 	user_posts.remove {_id: user._id}, ->
	# 		posts.remove {user_id: user._id}, done

	# fns = []
	# fns.push (next) -> users.remove {}, -> posts.remove {}, -> user_posts.remove {}, next
	# fns.push (next) -> users.insert {_id: 'richard', name: 'Richard Lyon'}, next
	# fns.push (next) -> posts.insert {_id: 1, user_id: 'richard', title: 'My first post', content: 'Lorum ipsum dolor sit amet...'}, next
	# fns.push (next) -> user_posts.find().toArray next
	# fns.push (next) -> users.remove {_id: 'richard'}, next
	# fns.push (next) -> users.find().toArray next
	# fns.push (next) -> posts.find().toArray next
	# fns.push (next) -> user_posts.find().toArray next

	# iter = (fn, next) ->
	# 	setTimeout (() -> fn next), 10

	# async.mapSeries fns, iter, (err, res) ->
	# 	[rm, ui, pi, upa, ur, ua, pa, upa2] = res
	# 	console.log 'Before removal:', upa
	# 	console.log 'Afer removal:', (if ua.length + pa.length + upa2.length is 0 then 'collections empy' else {users: ua, posts: pa, joined: upa2})
