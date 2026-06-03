--$MODULE
local Parser = require "./Parser"
local GitFxns = require "./GitFxns"
local Types = require "./Types"

return {
	run = function(src: string)
		local success, result: Types.GitParserData? = pcall(function()
			return Parser.parse(src) :: Types.GitParserData
		end)

		if not success then
			warn(`(git) Operation failed. \n ------------------- \n {result}`)
			return
		end

		task.defer(function()
			if result.config then
				GitFxns.gitConfigGlobal(result.config)
			end
			if result.push then
				GitFxns.gitPush(result.push)
			end
			if result.pull then
				GitFxns.gitPull(result.pull)
			end
			warn(`(git) Operation completed.`)
		end)
	end,
}