module.exports = makePaths = (obj, base = []) ->
	res = makePathInner obj, [], [].concat base
	# remove duplicates, turn paths into strings, remove nulls
	res.filter(
		(v, i) -> v not in res.slice(i+1)
	).map((path) ->
		path = path.join?('.') or path
		path.toString().replace(/^\.+/, '')
	).filter(Boolean)

makePathInner = (obj, res = [], arr = []) ->
	if typeof obj is 'object'
		pre = [].concat res
		for key, val of obj
			res = makePathInner val, res, arr.concat key

		# turn array paths into globbed paths
		if Array.isArray obj
			paths = res.filter((path) ->
				(path not in pre) and (path.some (val) -> not isNaN Number val)
			).reduce((obj, path) ->
				path = path.map (val) -> if (not isNaN Number val) then '*' else val
				obj[path.join '.'] = path
				return obj
			, {})
			res.push val for key, val of paths

	res.push arr
	return res