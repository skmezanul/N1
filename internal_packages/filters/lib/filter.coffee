_ = require 'underscore'
{Utils,
 CategoryStore,
 Actions,
 ChangeUnreadTask,
 ChangeFolderTask,
 ChangeStarredTask,
 ChangeLabelsTask,

 TaskQueueStatusStore} = require 'nylas-exports'
NylasObservables = require 'nylas-observables'

ScenarioEditor = require './scenario-editor'
{Template} = ScenarioEditor

RuleMode =
  Any: 'any'
  All: 'all'

RuleTemplates = [
  new Template('from', Template.Type.String, {
    name: 'From',
    valueForMessage: (message) ->
      _.pluck(message.from, 'email')
  })

  new Template('to', Template.Type.String, {
    name: 'To',
    valueForMessage: (message) ->
      _.pluck(message.to, 'email')
  })

  new Template('cc', Template.Type.String, {
    name: 'Cc',
    valueForMessage: (message) ->
      _.pluck(message.cc, 'email')
  })

  new Template('bcc', Template.Type.String, {
    name: 'Bcc',
    valueForMessage: (message) ->
      _.pluck(message.bcc, 'email')
  })

  new Template('anyRecipient', Template.Type.String, {
    name: 'Any Recipient',
    valueForMessage: (message) ->
      recipients = [].concat(message.to, message.cc, message.bcc, message.from)
      _.pluck(recipients, 'email')
  })

  new Template('anyAttachmentName', Template.Type.String, {
    name: 'Any attachment name',
    valueForMessage: (message) ->
      _.pluck(message.files, 'filename')
  })

  new Template('subject', Template.Type.String, {
    name: 'Subject',
    valueForMessage: (message) ->
      message.subject
  })

  new Template('body', Template.Type.String, {
    name: 'Body',
    valueForMessage: (message) ->
      message.body
  })
]

ActionTemplates = [
  new Template('markAsRead', Template.Type.None, {name: 'Mark as read'})
  new Template('star', Template.Type.None, {name: 'Star message'})
]


class Filter
  @RuleMode: RuleMode

  @RuleTemplatesForAccount: (account) ->
    return [] unless account
    return RuleTemplates

  @ActionTemplatesForAccount: (account) ->
    return [] unless account

    templates = [].concat(ActionTemplates)

    CategoryNamesObservable = NylasObservables.Categories
      .forAccount(account)
      .sort()
      .map (cats) ->
        cats.map (cat) ->
          name: cat.displayName || cat.name
          value: cat.id

    if account.usesLabels()
      templates.push new Template('applyLabel', Template.Type.Enum, {
        name: 'Apply Label'
        values: CategoryNamesObservable
      })

    else
      templates.push new Template('changeFolder', Template.Type.Enum, {
        name: 'Move Message'
        valueLabel: 'to mailbox:'
        values: CategoryNamesObservable
      })

    templates

  constructor: (properties) ->
    defaults =
      id: Utils.generateTempId()
      accountId: undefined
      name: "Untitled Filter"
      ruleMode: RuleMode.All
      rules: [RuleTemplates[0].createDefaultInstance()]
      actions: [ActionTemplates[0].createDefaultInstance()]

    _.extend(@, defaults, properties)

    unless @accountId
      throw new Error("Filter::constructor you must provide an account id.")

    @

  matches: (message) ->
    if @ruleMode is RuleMode.All
      fn = _.every
    else
      fn = _.any

    fn @rules, (rule) =>
      template = _.findWhere(RuleTemplates, {key: rule.templateKey})
      value = template.valueForMessage(message)
      template.evaluate(rule, value)

  applyTo: (message, thread) ->
    tasks = []

    functions =
      markAsRead: (message, thread, value) ->
        new ChangeUnreadTask(unread: false, threads: [thread])
      star: (message, thread, value) ->
        new ChangeStarredTask(starred: true, threads: [thread])
      applyLabel: (message, thread, value) ->
        new ChangeLabelsTask(labelsToAdd: [value], threads: [thread])
      changeFolder: (message, thread, value) ->
        new ChangeFolderTask(folder: value, threads: [thread])

    @actions.forEach (action) ->
      task = functions[action.templateKey](message, thread, action)
      tasks.push(task) if task

    promises = tasks.map(TaskQueueStatusStore.waitForPerformLocal)
    tasks.forEach(Actions.queueTask)
    Promise.all(promises)

module.exports = Filter
