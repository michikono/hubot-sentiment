# Description

A hubot-slack (v3.0+) script that runs sentiment analysis of chatrooms its in.

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
* The bot uses slack's RTM API so older versions of hubot-slack will NOT work with this bot
