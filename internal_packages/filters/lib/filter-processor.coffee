_ = require 'underscore'
{RuleMode, RuleTemplates} = require './filter-templates'
{Utils,
 Task,
 Label,
 Folder,
 Thread,
 Message,
 Actions,
 AccountStore,
 CategoryStore,
 ChangeUnreadTask,
 ChangeFolderTask,
 ChangeStarredTask,
 ChangeLabelsTask,
 DatabaseStore,
 TaskQueueStatusStore} = require 'nylas-exports'

class AccountReprocessJob
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


class FilterProcessor
  constructor: ->
    @_jobs = {}
    @_history = []

  history: =>
    @_history

  appendToHistory: (msg) =>
    @_history.splice(0, 0, msg)
    @_history.length = 200 if @_history.length > 200

  processMessages: (messages) =>
    return Promise.resolve() unless messages.length > 0

    # When messages arrive, we process all the messages in parallel, but one
    # filter at a time. This is important, because users can order filters which
    # may do and undo a change. Ie: "Star if from Ben, Unstar if subject is "Bla"
    FiltersStore = require './filters-store'
    Promise.each FiltersStore.filters(), (filter) =>
      matching = messages.filter (message) =>
        @_checkFilterForMessage(filter, message)

      Promise.map matching, (message) =>
        # We always pull the thread from the database, even though it may be in
        # `incoming.thread`, because filters may be modifying it as they run!
        DatabaseStore.find(Thread, message.threadId).then (thread) =>
          @_applyFilterToMessage(filter, message, thread)

  processAllMessages: (accountId) =>
    if @_jobs[accountId]
      @_jobs[accountId].cancel()

    @_jobs[accountId] = new AccountReprocessJob(accountId, @)
    @_jobs[accountId].start()


  _checkFilterForMessage: (filter, message) =>
    if filter.ruleMode is RuleMode.All
      fn = _.every
    else
      fn = _.any

    return false unless message.accountId is filter.accountId

    fn filter.rules, (rule) =>
      template = _.findWhere(RuleTemplates, {key: rule.templateKey})
      value = template.valueForMessage(message)
      template.evaluate(rule, value)

  _applyFilterToMessage: (filter, message, thread) =>

    functions =
      markAsImportant: (message, thread) ->
        DatabaseStore.findBy(Label, {
          name: 'important',
          accountId: thread.accountId
        }).then (important) ->
          new ChangeLabelsTask(labelsToAdd: [important], threads: [thread])

      moveToTrash: (message, thread) ->
        account = AccountStore.itemWithId(thread.accountId)
        CategoryClass = account.categoryClass()

        Promise.props(
          inbox: DatabaseStore.findBy(CategoryClass, { name: 'inbox', accountId: thread.accountId })
          trash: DatabaseStore.findBy(CategoryClass, { name: 'trash', accountId: thread.accountId })
        ).then ({inbox, trash}) ->
          new ChangeLabelsTask
            labelsToRemove: [inbox]
            labelsToAdd: [trash]
            threads: [thread]

      markAsRead: (message, thread, value) ->
        new ChangeUnreadTask(unread: false, threads: [thread])

      star: (message, thread, value) ->
        new ChangeStarredTask(starred: true, threads: [thread])

      applyLabel: (message, thread, value) ->
        new ChangeLabelsTask(labelsToAdd: [value], threads: [thread])

      changeFolder: (message, thread, value) ->
        new ChangeFolderTask(folder: value, threads: [thread])

    results = filter.actions.map (action) =>
      @appendToHistory "Applying #{filter.id} to #{message.id}..."
      functions[action.templateKey](message, thread, action.value)

    Promise.all(results).then (results) ->
      performLocalPromises = []

      tasks = results.filter (r) -> r instanceof Task
      tasks.forEach (task) ->
        performLocalPromises.push TaskQueueStatusStore.waitForPerformLocal(task)
        Actions.queueTask(task)

      Promise.all(performLocalPromises)

module.exports = FilterProcessor
