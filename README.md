# Description

A hubot script that runs sentiment analysis of chatrooms its in. Generates output when you say `hubot sentiment`:

    Top happy people:
    1: juld = :-D!!!
    2: frank = :-D
    3: eric = :-)
    
    Top happy channels:
    1: #hubot = :-D
    2: #hackers = :-)
    3: #lunch = :-)
    
    Most stressed people:
    1: bubs = :-/
    2: michi = :-/
    3: ungs = :-/
    
    Most stressed channels:
    1: #internal = :-/
    2: #builds = :-/


# To install

Go to your bot's root directory and run:

    npm install hubot-sentiment --save
    
Add it to your `external-scripts.json`: 

    [
      "hubot-sentiment"
    ]


# To use

1. Invite the bot to rooms 
2. Let people chat
3. PM the bot: `sentiment` or publicly message: `[botname] sentiment`

# Note

* Scores reset weekly
* The bot does not log chats
* The bot needs brain to work (https://github.com/github/hubot/blob/master/src/brain.coffee)
* (For Slack) The bot uses Slack's RTM API so older versions (<3.0) of hubot-slack will NOT work with this bot
