module.exports = makePaths = (obj, base = []) ->
	res = makePathInner obj, [], [].concat base

	# remove duplicates, turn paths into strings, remove nulls
	res = res.filter(Boolean).reduce((arr, path) ->
		path = path.join?('.') or path.toString()
		path = path.replace(/^\.+/, '').replace(/^\$([a-z]+)\.?/, '')
		arr.push path

		if path.match /\.[0-9]+(\.|$)/g
			path = path.replace(/\.[0-9]+(\.|$)/g, '.*$1')
			arr.push path

		return arr
	, []).reduce((arr, path) ->
		bits = path.split('.')
		while bits.length > 0
			arr.push bits.join('.')
			bits.pop()
		return arr
	, [])
	return res.filter (v, i) -> v and v not in ['*', '.'] and v not in res.slice(i+1)

makePathInner = (obj, res = [], arr = []) ->
	if typeof obj is 'object'
		for key, val of obj
			res = makePathInner val, res, arr.concat key.split('.')

	res.push arr
	return res