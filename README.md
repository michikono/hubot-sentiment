# Description

A hubot-slack (v3.0+) script that runs sentiment analysis of chatrooms its in.

# To install

Go to your bot's root directory and run:

    npm install sentiment --save
    npm install underscore --save

Copy `scripts/sentiment.coffee` to your slack bot's `scripts/` folder.

# To use

* PM the bot `sentiment`
* `[botname] sentiment`

# Note

* The bot does not log chats
* The bot needs brain to work (https://github.com/github/hubot/blob/master/src/brain.coffee)
* The bot uses slack's RTM API so older versions of hubot-slack will NOT work with this bot
