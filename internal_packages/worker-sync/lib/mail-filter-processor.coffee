_ = require 'underscore'
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
 MailFiltersStore,
 MailFiltersTemplates,
 TaskQueueStatusStore} = require 'nylas-exports'

{RuleMode, RuleTemplates} = MailFiltersTemplates
MailFilterReprocessJob = require './mail-filter-reprocess-job'

class FilterProcessor
  constructor: ->
    @_jobs = {}
    @_history = []

    Actions.reprocessFiltersForAccountId.listen(@processAllMessages)

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
    Promise.each MailFiltersStore.filters(), (filter) =>
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

    @_jobs[accountId] = new MailFilterReprocessJob(accountId, @)
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
