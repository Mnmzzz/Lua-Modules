---
-- @Liquipedia
-- wiki=counterstrike
-- page=Module:Infobox/Team/Custom
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local Array = require('Module:Array')
local Class = require('Module:Class')
local Lua = require('Module:Lua')
local Table = require('Module:Table')
local Template = require('Module:Template')
local Variables = require('Module:Variables')

local Game = Lua.import('Module:Game', {requireDevIfEnabled = true})
local Injector = Lua.import('Module:Infobox/Widget/Injector', {requireDevIfEnabled = true})
local Team = Lua.import('Module:Infobox/Team', {requireDevIfEnabled = true})

local Widgets = require('Module:Infobox/Widget/All')
local Cell = Widgets.Cell

local CustomTeam = Class.new()
local CustomInjector = Class.new(Injector)

local _team
local _games

function CustomTeam.run(frame)
	local team = Team(frame)

	team.createWidgetInjector = CustomTeam.createWidgetInjector
	team.createBottomContent = CustomTeam.createBottomContent
	team.addToLpdb = CustomTeam.addToLpdb
	team.getWikiCategories = CustomTeam.getWikiCategories

	_team = team
	_games = Array.filter(Game.listGames({ordered = true}), function (gameIdentifier)
			return team.args[gameIdentifier]
		end)

	return team:createInfobox()
end

function CustomTeam:createWidgetInjector()
	return CustomInjector()
end

function CustomInjector:parse(id, widgets)
	if id == 'staff' then
		return {
			Cell{name = 'Founders',	content = {_team.args.founders}},
			Cell{name = 'CEO', content = {_team.args.ceo}},
			Cell{name = 'Gaming Director', content = {_team.args['gaming director']}},
			widgets[4], -- Manager
			widgets[5], -- Captain
			Cell{name = 'In-Game Leader', content = {_team.args.igl}},
			widgets[1], -- Coaches
			Cell{name = 'Analysts', content = {_team.args.analysts}},
		}
	elseif id == 'earningscell' then
		widgets[1].name = 'Approx. Total Winnings'
	end
	return widgets
end

function CustomInjector:addCustomCells(widgets)
	return {
		Cell {
			name = 'Games',
			content = Array.map(_games, function (gameIdentifier)
					return Game.text{game = gameIdentifier}
				end)
		}
	}
end

function CustomTeam:createBottomContent()
	if not _team.args.disbanded and mw.ext.TeamTemplate.teamexists(_team.pagename) then
		local teamPage = mw.ext.TeamTemplate.teampage(_team.pagename)

		return Template.expandTemplate(
			mw.getCurrentFrame(),
			'Upcoming and ongoing matches of',
			{team = _team.lpdbname or teamPage}
		) .. Template.expandTemplate(
			mw.getCurrentFrame(),
			'Upcoming and ongoing tournaments of',
			{team = _team.lpdbname or teamPage}
		)
	end
end

function CustomTeam:addToLpdb(lpdbData, args)
	lpdbData.region = Variables.varDefault('region', '')

	return lpdbData
end

function CustomTeam:getWikiCategories(args)
	local categories = {}

	Array.forEach(_games, function (gameIdentifier)
			local prefix = Game.categoryPrefix{game = gameIdentifier} or Game.name{game = gameIdentifier}
			table.insert(categories, prefix .. ' Teams')
		end)

	if Table.isEmpty(_games) then
		table.insert(categories, 'Gameless Teams')
	end

	if args.teamcardimage then
		table.insert(categories, 'Teams using TeamCardImage')
	end

	if not args.region then
		table.insert(categories, 'Teams without a region')
	end

	if args.nationalteam then
		table.insert(categories, 'National Teams')
	end

	return categories
end

return CustomTeam
