{ComposerExtension} = require 'nylas-exports'
request = require 'request'

class AvailabilityComposerExtension extends ComposerExtension

  # When subclassing the ComposerExtension, you can add your own custom logic
  # to execute before a draft is sent in the @finalizeSessionBeforeSending
  # method. Here, we're registering the events before we send the draft.
  @finalizeSessionBeforeSending: (session) ->
    new Promise (resolve, reject) ->
      body = session.draft().body
      participants = session.draft().participants()
      sender = session.draft().from
      matches = (/data-quick-schedule="(.*)?" style/).exec body
      if matches?
        json = atob(matches[1])
        data = JSON.parse(json)
        data.attendees = []
        data.attendees = participants.map (p) ->
          name: p.name, email: p.email, isSender: p.isMe()
        serverUrl = "https://quickschedule.herokuapp.com/register-events"
        request.post {url: serverUrl, body: JSON.stringify(data)}, (error, resp, data) =>
          console.log(error,resp,data)
          if error then reject(error)
          else resolve(data)
      else resolve()


module.exports = AvailabilityComposerExtension
