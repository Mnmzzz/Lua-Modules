---
-- @Liquipedia
-- wiki=commons
-- page=Module:PrizePool/Award/Custom
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local Arguments = require('Module:Arguments')
local Lua = require('Module:Lua')

local AwardPrizePool = Lua.import('Module:PrizePool/Award', {requireDevIfEnabled = true})

local CustomAwardPrizePool = {}

-- Template entry point
function CustomAwardPrizePool.run(frame)
	local awardsPrizePool = AwardPrizePool(Arguments.getArgs(frame))

	awardsPrizePool:setConfigDefault('prizeSummary', false)
	awardsPrizePool:setConfigDefault('syncPlayers', true)

	return awardsPrizePool:create():build()
end

return CustomAwardPrizePool
