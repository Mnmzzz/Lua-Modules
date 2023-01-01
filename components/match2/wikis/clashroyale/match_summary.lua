---
-- @Liquipedia
-- wiki=clashroyale
-- page=Module:MatchSummary
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local CustomMatchSummary = {}

local Abbreviation = require('Module:Abbreviation')
local CardIcon = require('Module:CardIcon')
local Logic = require('Module:Logic')
local Lua = require('Module:Lua')
local Table = require('Module:Table')
local VodLink = require('Module:VodLink')

local DisplayHelper = Lua.import('Module:MatchGroup/Display/Helper', {requireDevIfEnabled = true})
local MatchGroupUtil = Lua.import('Module:MatchGroup/Util', {requireDevIfEnabled = true})
local MatchSummary = Lua.import('Module:MatchSummary/Base', {requireDevIfEnabled = true})

local OpponentDisplay = require('Module:OpponentLibraries').OpponentDisplay

local NUM_CARDS_PER_PLAYER = 8
local CARD_COLOR_1 = 'blue'
local CARD_COLOR_2 = 'red'
local DEFAULT_CARD = 'transparent'
local GREEN_CHECK = '[[File:GreenCheck.png|14x14px|link=]]'
local NO_CHECK = '[[File:NoCheck.png|link=]]'
-- Normal links, from input/lpdb
local LINK_DATA = {
	preview = {icon = 'File:Preview Icon32.png', text = 'Preview'},
	lrthread = {icon = 'File:LiveReport32.png', text = 'Live Report Thread'},
	interview = {icon = 'File:Interview32.png', text = 'Interview'},
	recap = {icon = 'File:Reviews32.png', text = 'Recap'},
	vod = {icon = 'File:VOD Icon.png', text = 'Watch VOD'},
}
LINK_DATA.review = LINK_DATA.recap
LINK_DATA.preview2 = LINK_DATA.preview
LINK_DATA.interview2 = LINK_DATA.interview

local EPOCH_TIME = '1970-01-01 00:00:00'
local EPOCH_TIME_EXTENDED = '1970-01-01T00:00:00+00:00'

function CustomMatchSummary.getByMatchId(args)
	local match = MatchGroupUtil.fetchMatchForBracketDisplay(args.bracketId, args.matchId)

	local matchSummary = MatchSummary():init('360px')
	matchSummary.root:css('flex-wrap', 'unset')

	matchSummary:header(CustomMatchSummary._createHeader(match))
				:body(CustomMatchSummary._createBody(match, args.matchId))

	if match.comment then
		local comment = MatchSummary.Comment():content(match.comment)
		matchSummary:comment(comment)
	end

	local vods = {}
	for index, game in ipairs(match.games) do
		if not Logic.isEmpty(game.vod) then
			vods[index] = game.vod
		end
	end
	match.links.vod = match.vod

	if not Table.isEmpty(vods) or not Table.isEmpty(match.links) then
		local footer = MatchSummary.Footer()

		-- Match Vod + other links
		local buildLink = function (link, icon, text)
			return '[['..icon..'|link='..link..'|15px|'..text..']]'
		end

		for linkType, link in pairs(match.links) do
			if not LINK_DATA[linkType] then
				mw.log('Unknown link: ' .. linkType)
			else
				footer:addElement(buildLink(link, LINK_DATA[linkType].icon, LINK_DATA[linkType].text))
			end
		end

		-- Game Vods
		for index, vod in pairs(vods) do
			footer:addElement(VodLink.display{
				gamenum = index,
				vod = vod,
				source = vod.url
			})
		end

		matchSummary:footer(footer)
	end

	return matchSummary:create()
end

function CustomMatchSummary._createHeader(match)
	local header = MatchSummary.Header()

	header:leftOpponent(header:createOpponent(match.opponents[1], 'left', 'bracket'))
		:leftScore(header:createScore(match.opponents[1]))
		:rightScore(header:createScore(match.opponents[2]))
		:rightOpponent(header:createOpponent(match.opponents[2], 'right', 'bracket'))

	return header
end

function CustomMatchSummary._createBody(match, matchId)
	local body = MatchSummary.Body()

	if match.dateIsExact or (match.date ~= EPOCH_TIME_EXTENDED and match.date ~= EPOCH_TIME) then
		-- dateIsExact means we have both date and time. Show countdown
		-- if match is not epoch=0, we have a date, so display the date
		body:addRow(MatchSummary.Row():addElement(
			DisplayHelper.MatchCountdownBlock(match)
		))
	end

	if match.extradata.hasteamopponent then
		return CustomMatchSummary._createTeamMatchBody(body, match, matchId)
	end

	-- Iterate each map
	for gameIndex, game in ipairs(match.games) do
		body:addRow(CustomMatchSummary._createGame(game, gameIndex, match.date))
	end

	local extradata = match.extradata
	if Table.isNotEmpty(extradata.t1bans) or Table.isNotEmpty(extradata.t2bans) then
		body:addRow(CustomMatchSummary._banRow(extradata.t1bans, extradata.t2bans, match.date))
	end

	return body
end

function CustomMatchSummary._createGame(game, gameIndex, date)
	local row = MatchSummary.Row()

	-- Add game header
	if not Logic.isEmpty(game.header) then
		row:addElement(mw.html.create('div')
			:wikitext(game.header)
			:css('margin', 'auto')
			:css('font-weight', 'bold')
		)
		row:addElement(MatchSummary.Break():create())
	end

	local cardData = {{}, {}}
	for participantKey, participantData in Table.iter.spairs(game.participants or {}) do
		local opponentIndex = tonumber(mw.text.split(participantKey, '_')[1])
		local cards = participantData.cards or {}
		for _ = #cards + 1, NUM_CARDS_PER_PLAYER do
			table.insert(cards, DEFAULT_CARD)
		end
		table.insert(cardData[opponentIndex], cards)
	end

	row:addClass('brkts-popup-body-game')
		:css('font-size', '80%')
		:css('padding', '4px')
		:css('min-height', '32px')

	row:addElement(CustomMatchSummary._opponentCardsDisplay{
		data = cardData[1],
		flip = true,
		date = date,
	})
	row:addElement(CustomMatchSummary._createCheckMark(game.winner == 1))
	row:addElement(mw.html.create('div')
		:addClass('brkts-popup-body-element-vertical-centered')
		:wikitext('Game ' .. gameIndex)
	)
	row:addElement(CustomMatchSummary._createCheckMark(game.winner == 2))
	row:addElement(CustomMatchSummary._opponentCardsDisplay{
		data = cardData[2],
		flip = false,
		date = date,
	})

	-- Add Comment
	if not Logic.isEmpty(game.comment) then
		row:addElement(MatchSummary.Break():create())
		row:addElement(mw.html.create('div')
			:wikitext(game.comment)
			:css('margin', 'auto')
		)
	end

	return row
end

function CustomMatchSummary._banRow(t1bans, t2bans, date)
	local maxAmountOfBans = math.max(#t1bans, #t2bans)
	for banIndex = 1, maxAmountOfBans do
		t1bans[banIndex] = t1bans[banIndex] or DEFAULT_CARD
		t2bans[banIndex] = t2bans[banIndex] or DEFAULT_CARD
	end

	local banRow = MatchSummary.Row()

	banRow:addClass('brkts-popup-body-game')
		:css('font-size', '80%')
		:css('padding', '4px')
		:css('min-height', '32px')

	banRow:addElement(mw.html.create('div')
		:wikitext('Bans')
		:css('margin', 'auto')
		:css('font-weight', 'bold')
	)
	banRow:addElement(MatchSummary.Break():create())

	banRow:addElement(CustomMatchSummary._opponentCardsDisplay{
		data = {t1bans},
		flip = true,
		date = date,
	})
	banRow:addElement(mw.html.create('div')
		:addClass('brkts-popup-body-element-vertical-centered')
		:wikitext('Bans')
	)
	banRow:addElement(CustomMatchSummary._opponentCardsDisplay{
		data = {t2bans},
		flip = false,
		date = date,
	})

	return banRow
end

function CustomMatchSummary._createTeamMatchBody(body, match, matchId)
	local subMatches = match.extradata.submatches
	for _, game in ipairs(match.games) do
		local subMatch = subMatches[game.subgroup]
		if not subMatch.games then
			subMatch.games = {}
		end

		table.insert(subMatch.games, game)
	end

	for subMatchIndex, subMatch in ipairs(subMatches) do
		local players = CustomMatchSummary._fetchPlayersForSubmatch(subMatchIndex, subMatch, match)
		body:addRow(CustomMatchSummary._createSubMatch(
			players,
			subMatchIndex,
			subMatch,
			match.extradata
		))
	end

	if match.extradata.hasbigmatch then
		local matchPageLinkRow = MatchSummary.Row()
		matchPageLinkRow:addElement(mw.html.create('div')
			:addClass('brkts-popup-comment')
			:wikitext('[[Match:ID_' .. matchId .. '|More details on the match page]]')
		)
		body:addRow(matchPageLinkRow)
	end

	return body
end

function CustomMatchSummary._fetchPlayersForSubmatch(subMatchIndex, subMatch, match)
	local players = {{}, {}, hash = {{}, {}}}

	CustomMatchSummary._extractPlayersFromGame(players, subMatch.games[1], match)

	if match.extradata['subgroup' .. subMatchIndex .. 'iskoth'] then
		for gameIndex = 2, #subMatch.games do
			CustomMatchSummary._extractPlayersFromGame(players, subMatch.games[gameIndex], match)
		end
	end

	return players
end

function CustomMatchSummary._extractPlayersFromGame(players, game, match)
	for participantKey, participant in Table.iter.spairs(game.participants or {}) do
		participantKey = mw.text.split(participantKey, '_')
		local opponentIndex = tonumber(participantKey[1])
		local match2playerIndex = tonumber(participantKey[2])

		local player = match.opponents[opponentIndex].players[match2playerIndex]

		if not player then
			player = {
				displayName = participant.displayname,
				pageName = participant.name,
			}
		end

		-- make sure we only display each player once
		if not players.hash[opponentIndex][player.pageName] then
			players.hash[opponentIndex][player.pageName] = true
			table.insert(players[opponentIndex], player)
		end
	end

	return players
end

function CustomMatchSummary._createSubMatch(players, subMatchIndex, subMatch, extradata)
	local row = MatchSummary.Row()

	row:addClass('brkts-popup-body-game')
		:css('min-height', '32px')

	-- Add submatch header
	if not Logic.isEmpty(extradata['subgroup' .. subMatchIndex .. 'header']) then
		row:addElement(mw.html.create('div')
			:wikitext(extradata['subgroup' .. subMatchIndex .. 'header'])
			:css('margin', 'auto')
			:css('font-weight', 'bold')
		)
		row:addElement(MatchSummary.Break():create())
	end

	-- players left side
	row:addElement(mw.html.create('div')
		:addClass(subMatch.winner == 1 and 'bg-win' or nil)
		:css('align-items', 'center')
		:css('border-radius', '0 12px 12px 0')
		:css('padding', '2px 8px')
		:css('text-align', 'right')
		:css('width', '40%')
		:node(OpponentDisplay.PlayerBlockOpponent{
			opponent = {players = players[1]},
			overflow = 'ellipsis',
			showLink = true,
			flip = true,
		})
	)

	-- scores and in case of koth also info that it is koth
	local scoreElement = table.concat(subMatch.scores, ' - ')
	if extradata['subgroup' .. subMatchIndex .. 'iskoth'] then
		scoreElement = mw.html.create('div')
			:node(mw.html.create('div'):wikitext(scoreElement))
			:node(mw.html.create('div')
				:css('font-size', '85%')
				:wikitext(Abbreviation.make('KotH', 'King of the Hill submatch'))
			)
	end

	row:addElement(mw.html.create('div')
		:addClass('brkts-popup-body-element-vertical-centered')
		:node(scoreElement)
	)

	-- players right side
	row:addElement(mw.html.create('div')
		:addClass(subMatch.winner == 2 and 'bg-win' or nil)
		:css('align-items', 'center')
		:css('border-radius', '12px 0 0 12px')
		:css('padding', '2px 8px')
		:css('text-align', 'left')
		:css('width', '40%')
		:node(OpponentDisplay.PlayerBlockOpponent{
			opponent = {players = players[2]},
			overflow = 'ellipsis',
			showLink = true,
			flip = false,
		})
	)

	return row
end

function CustomMatchSummary._createCheckMark(isWinner)
	local container = mw.html.create('div')
		:addClass('brkts-popup-body-element-vertical-centered')
		:css('line-height', '17px')
		:css('margin-left', '1%')
		:css('margin-right', '1%')

	if Logic.readBool(isWinner) then
		container:node(GREEN_CHECK)
	else
		container:node(NO_CHECK)
	end

	return container
end

function CustomMatchSummary._opponentCardsDisplay(args)
	local cardDataSets = args.data
	local flip = args.flip
	local date = args.date

	local color = flip and CARD_COLOR_2 or CARD_COLOR_1
	local wrapper = mw.html.create('div')

	for _, cardData in ipairs(cardDataSets) do
		local cardDisplays = {}
		for _, card in ipairs(cardData) do
			table.insert(cardDisplays, mw.html.create('div')
				:addClass('brkts-popup-side-color-' .. color)
				:addClass('brkts-champion-icon')
				:css('float', flip and 'right' or 'left')
				:node(CardIcon._getImage{card, date = date})
			)
		end

		local display

		for cardIndex, card in ipairs(cardDisplays) do
			-- break the card rows into fragments of 4 cards each
			if cardIndex % 4 == 1 then
				wrapper:node(display)
				display = mw.html.create('div')
					:addClass('brkts-popup-body-element-thumbs')
			end

			display:node(card)
		end

		wrapper:node(display)
	end

	return wrapper
end

return CustomMatchSummary
