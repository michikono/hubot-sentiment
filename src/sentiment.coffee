# Description:
#   This bot measures sentiment in all channels its in and tracks analytics; starts are reset each week
#
# Commands:
#   sentiment - lists sentiment stats (message contents NOT stored)
#   how are things? - just details about the current channel + you
#   who's happy?
#   who's stressed?
#   where's happiness?
#   where's stress?
#
# Author:
#   Michi Kono
#   Will Barksdale
#
# Notes:
#   Requires underscore and sentiment NPM modules
#
#   Tracks scores by current month. Collects sentiment on users [sentiment:week_digit:user] and
#   channels [sentiment:week_digit:channel] in format:
#
#     {
#       data: [{
#         name: user_or_channe_name
#         year: 'YYYY',
#         score_average: 0,
#         score_count: 0
#       }]
#     }
#
# Example:
#   [sentiment:12:user:michi] = {n:a:yyyy} where n is the number of records, and a is the average score of the n records
#   To add a new score: (n + 1), ((a * n) + 2.5 / (n+1)) => new averages
#
sentiment = require 'sentiment'
_ = require 'underscore'

module.exports = (robot) ->
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
    sorted = _.sortBy(getAllEntriesForWeek(topType, weekNum), (entry) -> parseFloat(entry.score))
    sorted = sorted.reverse() if ordering == 'ascending'
    sorted.slice(0, topNumber)

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
    (robot.brain.get(calculateKey(recordType, weekNum)) || {}).entry_data || []

  # Description: returns keys
  #  Params:
  #   recordType: (channel|user)
  #   recordName: channel_name or user_name
  #   weekNum: 0-52
  #
  calculateKey = (recordType, weekNum) ->
    "sentiment:#{weekNum}:#{recordType}"

  getMasterRecord = (recordType, recordName, weekNum) ->
    (robot.brain.get(calculateKey(recordType, weekNum)) || {}).entry_data || []

  getRecord = (recordType, recordName, weekNum) ->
    (_.filter(getMasterRecord(recordType, recordName, weekNum), (x) -> x.name == recordName) || [])[0]

  # Description:
  #  Updates the record with the value of sentimentScore
  # Params:
  #  recordType: (channel|user)
  #  recordName: channel_name or user_name
  #  weekNum 0-52
  #  sentimentScore: AFINN Sentiment score
  updateEntry = (recordType, recordName, weekNum, sentimentScore) ->
    masterRecord = getMasterRecord(recordType, recordName, weekNum)
    entry = getRecord(recordType, recordName, weekNum)

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
    entry.score_average = ((parseFloat(entry.score_average) * parseFloat(entry.score_count)) + sentimentScore) / parseFloat((entry.score_count) + 1)
    entry.score_count = parseFloat(entry.score_count) + 1

    robot.brain.set(calculateKey(recordType, weekNum), {entry_data: masterRecord})

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

  emoteScore = (score) ->
    score = parseFloat(score)
    return ":'("  if(score <= -3)
    return ":-((((" if(score <= -2)
    return ":-(" if(score <= -1)
    return ":-/" if(score <= -0.1)
    return ":-D!!!" if(score >= 3)
    return ":-D" if(score >= 2)
    return "8-)" if(score >= 1)
    return ":-)" if(score >= 0.1)
    return "THERE IS INSUFFICIENT DATA FOR A MEANINGFUL ANSWER."

  prettyPrintList = (entries, emptyMessage) ->
    output = ''
    entries = entries || []
    if entries.length
      for entry, i in entries
        # remove @ from @names to prevent notification spam
        if entries.length <= 1
          output += "#{entry.name.replace(/@/g, '')} = #{emoteScore(parseFloat(entry.score_average))}\n"
        else
          output += "#{i + 1}: #{entry.name.replace(/@/g, '')} = #{emoteScore(parseFloat(entry.score_average))}\n"
    output || emptyMessage

  onlyNegative = (list) ->
    _.filter(list || [], (x) -> parseFloat(x.score_average) <= 0)

  onlyPositive = (list) ->
    _.filter(list || [], (x) -> parseFloat(x.score_average) > 0)

  robot.hear /.*/, (msg)->
    # match everything and log it
    if(!msg.message.text.match(/(who|where)( i|')s( the)? (happy|sad|sadness|stress|stressed|happiness|mad|angry|anger)\??/i))
      logSentiment(msg)

  happyPeoplePrompt = "Top happy people:\n"
  happyChannelPrompt = "Top happy channels:\n"
  sadPeoplePrompt = "Top stressed people:\n"
  sadChannelPrompt = "Top stressed channels:\n"

  generalPersonalPrompt = "You: "
  generalChannelPrompt = "This channel: "

  happyPeopleMessage = " - Nobody... Yet.\n"
  happyChannelMessage = " - Nowhere... Yet.\n"
  sadPeopleMessage = " - Nobody seems stressed!\n"
  sadChannelMessage = " - Everything is dandy!\n"

  generalStatusMessage = "THERE IS INSUFFICIENT DATA FOR A MEANINGFUL ANSWER.\n"
  generalChannelMessage = "THERE IS INSUFFICIENT DATA FOR A MEANINGFUL ANSWER.\n"

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

  getMyStats = (who) ->
    generalPersonalPrompt + prettyPrintList( [getRecord('user', who, getWeekOfYear())], generalStatusMessage)

  getChannelStats = (where) ->
    generalChannelPrompt + prettyPrintList( [getRecord('channel', where, getWeekOfYear())], generalChannelMessage)


  robot.respond /how are things\??/i, (msg) ->
    msg.send getMyStats(getUsername(msg)) + "\n" + getChannelStats(getUsername(msg))

  robot.respond /sentiment/i, (msg) ->
    msg.send getHappyPeople(3) + "\n" + getHappyChannels(3) + "\n" + getSadPeople(3) + "\n" + getSadChannels(3)

  robot.respond /who[ is']* happy\??/i, (msg) ->
    # responds in the current channel
    msg.send getHappyPeople(10)

  robot.respond /where[ is']*( the)? (happy|happiness)\??/i, (msg) ->
    # responds in the current channel
    msg.send getHappyChannels(10)

  robot.respond /who[ is']* (sad|stress(ed)?)\??/i, (msg) ->
    # responds in the current channel
    msg.send getSadPeople(10)

  robot.respond /where[ is']*( the)? (sadness|stress)\??/i, (msg) ->
    # responds in the current channel
    msg.send getSadChannels(10)

  robot.respond /what[ is']* (sadness|stress)\??/i, (msg) ->
    # responds in the current channel
    msg.reply "Stress is too many meetings!"

  robot.respond /what[ is']* (happiness|happy)\??/i, (msg) ->
    # responds in the current channel
    msg.reply "Happiness is shipping code!"
