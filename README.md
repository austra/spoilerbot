# SpoilerBot

Sinatra app that provides Slack with a simple bot for displaying a random card from the latest Magic: The Gathering set. After configuring an Outgoing WebHook, typing spoiler will display a random card image from Gatherer.

## Preparation

SpoilerBot uses a Slack Outgoing WebHook integration for catching the `spoiler` request and passing it on to the application. You'll need to [add a new Outgoing WebHook](https://slack.com/services/new/outgoing-webhook) first so you'll have the `SLACK_TOKEN` available for deployment.

## Deployment

### Local

```
$ bundle install
$ export SLACK_TOKEN=...
$ foreman start
```

### Heroku

```
$ heroku create
$ heroku config:set SLACK_TOKEN=...
$ git push heroku master
```

## WebHook Settings

Once SpoilerBot is deployed, go back to your Outgoing Webhook page and configure the  Integration Settings to your needs. G

* Channel: `Any`
* Trigger Word: `spoiler`
* URL: `http://your-heroku-appname.herokuapp.com/spoiler` 
* Label: `spoilerbot`
