_ = require 'underscore'
{DatabaseStore, Message, Thread} = require 'nylas-exports'
LongRunningJob = require './long-running-job'

class MailFilterReprocessJob extends LongRunningJob
  constructor: (@accountId, @processor) ->
    @_processed = 0
    @_total = Infinity
    @_cancelled = false

  start: ->
    @offset = 0
    DatabaseStore.count(Message).where({accountId: @accountId}).then (count) =>
      return if @_cancelled
      @_total = count
      @_fetchNextPage()

  cancel: ->
    @_cancelled = true

  _fetchNextPage: =>
    return if @_cancelled

    # Fetching threads first, and then getting their messages allows us to use
    # The same indexes as the thread list / message list in the app
    query = DatabaseStore
      .findAll(Thread, {accountId: @accountId})
      .order(Thread.attributes.lastMessageReceivedTimestamp.descending())
      .offset(@offset)
      .limit(50)

    query.then (threads) =>
      return if @_cancelled
      DatabaseStore.findAll(Message, threadId: _.pluck(threads, 'id')).then (messages) =>
        return if @_cancelled

        @processor.processMessages(messages).finally =>
          @_processed += messages.length
          console.log("AccountReprocessJob #{@_processed} / #{@_total}")
          @offset += threads.length
          if threads.length > 0
            setTimeout(@_fetchNextPage, 500)

module.exports = MailFilterReprocessJob
