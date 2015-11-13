_ = require 'underscore'
{Utils} = require 'nylas-exports'

class Filter
  @Comparators:
    contains: (actual, desired) -> actual.toLowerCase().indexOf(desired.toLowerCase()) isnt -1
    doesNotContain: (actual, desired) -> actual.toLowerCase().indexOf(desired.toLowerCase()) is -1
    beginsWith: (actual, desired) -> actual.toLowerCase().indexOf(desired.toLowerCase()) is 0
    endsWith: (actual, desired) -> actual.toLowerCase().lastIndexOf(desired.toLowerCase()) is actual.length - desired.length
    equals: (actual, desired) -> actual is desired

  @ActionTemplates: [{
    name: 'Move Message'
    key: 'moveMessage'
    comparatorLabel: 'to mailbox:'
    valueType: 'enum'
    values: CategoryStore.getCategories().map (category) =>
      name: category.displayName
      value: category.id
  },{
    name: 'Mark as read'
    key: 'markAsRead'
    valueType: 'none'
  },{
    name: 'Star message'
    key: 'star'
    valueType: 'none'
  }]

  @RuleTemplates: [{
    name: 'From'
    key: 'from'
    valueType: 'string'
  },{
    name: 'To'
    key: 'to'
    valueType: 'string'
  },{
    name: 'Cc'
    key: 'cc'
    valueType: 'string'
  },{
    name: 'Bcc'
    key: 'bcc'
    valueType: 'string'
  },{
    name: 'Any Recipient'
    key: 'anyRecipient'
    valueType: 'string'
  },{
    name: 'Subject'
    key: 'subject'
    valueType: 'string'
  },{
    name: 'Any attachment name'
    key: 'anyAttachmentName'
    valueType: 'string'
  },{
    name: 'body'
    key: 'body'
    valueType: 'string'
  }]

  constructor: ->
    @id = Utils.generateTempId()
    @name = "Untitled Filter"
    @rules = [{key: 'to', comparator: 'contains', value: '', type: 'string'}]
    @actions = [{key: 'moveMessage', value: null}]

  matches: (message, thread) ->
    _.every @rules, (rule) ->
      if rule.key is 'anyRecipient'
        value = [].concat(message.to, message.cc, message.bcc, message.from)
      if rule.key is 'anyAttachmentName'
        value = message.files.map (f) -> f.name
      else
        value = message[rule.key]

      matchFunction = (actual, desired) -> actual is desired
      if rule.comparator
        matchFunction = @Comparators[rule.comparator]

      if value instanceof Array
        for subvalue in value
          return true if matchFunction(subvalue, rule.value)
      else
        return true if matchFunction(subvalue, rule.value)

      false

  applyTo: (message, thread) ->
    return unless @matches(message, thread)

    @_actions.forEach (action) ->
      if action.type is "moveMessage"
        folder = _.find CategoryStore.getUserCategories(), (c) ->
          c.id is val
        task = new ChangeFolderTask
          folder: folder
          threads: [thread]
        Actions.queueTask(task)

      else if action.type is "markAsRead" and val is true
        task = new ChangeUnreadTask
          unread: false
          threads: [thread]
        Actions.queueTask(task)

      else if action.type is "archive" and val is true
        task = TaskFactory.taskForArchiving({threads: [thread]})
        Actions.queueTask(task)

      else if action.type is "star" and val is true
        task = new ChangeStarredTask
          starred: true
          threads: [thread]
        Actions.queueTask(task)

      else if action.type is "delete" and val is true
        task = TaskFactory.taskForMovingToTrash({threads: [thread]})
        Actions.queueTask(task)

module.exports = Filter
