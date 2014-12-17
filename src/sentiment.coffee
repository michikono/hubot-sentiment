# Description:
#   This bot measures sentiment in all channels its in and tracks analytics; starts are reset each week
#
# Commands:
#   sentiment - lists sentiment stats (message contents NOT stored)
#   who's happy?
#   who's stressed?
#   where's the happiness?
#   where's the stress?
#
# Author:
#   Michi Kono
#   Will Barksdale
#
# Configuration:
#   HUBOT_SENTIMENT_BRAIN_INIT_TIMEOUT=N - wait for N milliseconds for brain data to load from redis. (default 10000)
# Notes:
#   Requires underscore and sentiment NPM modules
#
#   Tracks scores by current month. Collects sentiment on users [sentiment:week_digit:user] and
#   channels [sentiment:week_digit:channel] in format:
#
#    [{
#      name: user_or_channe_name
#      year: 'YYYY',
#      score_average: 0,
#      score_count: 0
#    }]
#
# Example:
#   [sentiment:12:user:michi] = {n:a:yyyy} where n is the number of records, and a is the average score of the n records
#   To add a new score: (n + 1), ((a * n) + 2.5 / (n+1)) => new averages
#
sentiment = require 'sentiment'
_ = require 'underscore'
INIT_TIMEOUT = (if process.env.HUBOT_REACT_INIT_TIMEOUT then parseInt(process.env.HUBOT_SENTIMENT_BRAIN_INIT_TIMEOUT) else 10000)

start = (robot) ->
  # helper method to get the week of the year in numeric form
  getWeekOfYear = (dateObj = new Date()) ->
    onejan = new Date(dateObj.getFullYear(), 0, 1)
    Math.ceil((((dateObj - onejan) / 86400000) + onejan.getDay() + 1) / 7)

  # helper to return 4 digit year
  getYear = (dateObj = new Date()) ->
    dateObj.getFullYear()

  #  Description:
  #    Get The top n records from weekNum. records are of type topType
  #  Params:
  #    ordering: (ascending|descending)
  #    topNumber: Number of records you want back
  #    topType: (channel|user)
  #    weekNum: 0-51
  #  Returns:
  #    [{
  #      username: name
  #      score: 0
  #    }]
  getTopForWeek = (ordering, topNumber, topType, weekNum) ->
    _.sortBy(getAllEntriesForWeek(topType, weekNum), (entry) ->
      (if ordering == 'ascending' then -1 else 1) * entry.score
    ).slice(0, topNumber)

  # Description:
  #  Gets all of the records of type recordType from weekNum
  # Params:
  #  recordType: (channel|user)
  #  weekNum: 0-51
  #  Returns:
  #    [{
  #      username: name
  #      score: 0
  #    }]
  getAllEntriesForWeek = (recordType, weekNum) ->
    (robot.brain[calculateKey(recordType, weekNum)] || {}).data || []


  # Description: returns keys
  #  Params:
  #   recordType: (channel|user)
  #   recordName: channel_name or user_name
  #   weekNum: 0-52
  #
  calculateKey = (recordType, weekNum) ->
    "sentiment:#{weekNum}:#{recordType}"

  # Description:
  #  Updates the record with the value of sentimentScore
  # Params:
  #  recordType: (channel|user)
  #  recordName: channel_name or user_name
  #  weekNum 0-52
  #  sentimentScore: AFINN Sentiment score
  updateEntry = (recordType, recordName, weekNum, sentimentScore) ->
    masterRecord = (robot.brain[calculateKey(recordType, weekNum)] || {}).data || []
    entry = (_.filter(masterRecord, (x) -> x.name == recordName) || [])[0]

    if !entry || !entry.name
      entry =
        name: recordName
      masterRecord.push entry
    if !entry.year
      entry.year = getYear()
      entry.score_average = 0
      entry.score_count = 0

    entry.score_average = 0 if !entry.score_average
    entry.score_count = 0 if !entry.score_count
    entry.score_average = ((entry.score_average * entry.score_count) + sentimentScore) / (entry.score_count + 1)
    entry.score_count = entry.score_count + 1

    robot.brain[calculateKey(recordType, weekNum)] = {data: masterRecord}

  # helper method to get sender of the message
  getUsername = (response) ->
    "@#{response.message.user.name}"

  # helper method to get channel of originating message
  getChannel = (response) ->
    if response.message.room == response.message.user.name
      "@#{response.message.room}"
    else
      "##{response.message.room}"

  isPrivateMessage = (response) ->
    return getUsername(response) == getChannel(response)

  # update sentiment of a record
  # Params:
  #   Response
  logSentiment = (response) ->
    # filter out slack emotes to their actual words
    analysis = sentiment response.message.text.replace(/:(.*?)[_.\-](.*?):/g, ' $1 $2 ')
    if response.message.text && analysis && analysis.score && !isPrivateMessage(response)
      updateEntry('user', getUsername(response), getWeekOfYear(), analysis.score)
      updateEntry('channel', getChannel(response), getWeekOfYear(), analysis.score)

  prettyPrintList = (entries, emptyMessage) ->
    output = ''
    entries = entries || []
    if entries.length
      for entry, i in entries
        output += "#{i + 1}: #{entry.name}\n"
    output || emptyMessage

  onlyNegative = (list) ->
    _.filter(list || [], (x) -> (x.score_average <= 0))

  onlyPositive = (list) ->
    _.filter(list || [], (x) -> (x.score_average > 0))

  robot.hear /.*/, (msg)->
    # match everything and log it
    if(!msg.message.text.match(/(who|where)( i|')s( the)? (happy|sad|sadness|stress|stressed|happiness|mad|angry|anger)\??/i))
      logSentiment(msg)

  happyPeoplePrompt = "Top happy people:\n"
  happyChannelPrompt = "\n" + "Top happy channels:\n"
  sadPeoplePrompt = "\n" + "Top stressed people:\n"
  sadChannelPrompt = "\n" + "Top stressed channels:\n"

  happyPeopleMessage = " - Nobody... Yet.\n"
  happyChannelMessage = " - Nowhere... Yet.\n"
  sadPeopleMessage = " - Nobody seems stressed!\n"
  sadChannelMessage = " - Everything is dandy!\n"

  getHappyPeople = (howMany) ->
    happyPeoplePrompt + prettyPrintList(onlyPositive(getTopForWeek('descending', howMany, 'user', getWeekOfYear())),
      happyPeopleMessage)
  getHappyChannels = (howMany) ->
    happyChannelPrompt + prettyPrintList(onlyPositive(getTopForWeek('descending', howMany, 'channel', getWeekOfYear())),
      happyChannelMessage)
  getSadPeople = (howMany) ->
    sadPeoplePrompt + prettyPrintList(onlyNegative(getTopForWeek('ascending', howMany, 'user', getWeekOfYear())),
      sadPeopleMessage)
  getSadChannels = (howMany) ->
    sadChannelPrompt + prettyPrintList(onlyNegative(getTopForWeek('ascending', howMany, 'channel', getWeekOfYear())),
      sadChannelMessage)

  robot.respond /sentiment/i, (msg) ->
    msg.send getHappyPeople(3) + getHappyChannels(3) + getSadPeople(3) + getSadChannels(3)

  robot.respond /who( i|')s happy\??/i, (msg) ->
    # responds in the current channel
    msg.send getHappyPeople(10)

  robot.respond /where( i|')s( the)? (happy|happiness)\??/i, (msg) ->
    # responds in the current channel
    msg.send getHappyChannels(10)

  robot.respond /who( i|')s (sad|stress(ed)?)\??/i, (msg) ->
    # responds in the current channel
    msg.send getSadPeople(10)

  robot.respond /where( i|')s( the)? (sadness|stress)\??/i, (msg) ->
    # responds in the current channel
    msg.send getSadChannels(10)

module.exports = (robot) ->
  loaded = _.once(->
    console.log "starting hubot-sentiment..."
    start robot
    return
  )
  if _.isEmpty(robot.brain.data) or _.isEmpty(robot.brain.data._private)
    robot.brain.once "loaded", loaded
    setTimeout loaded, INIT_TIMEOUT
  else
    loaded()
  return

