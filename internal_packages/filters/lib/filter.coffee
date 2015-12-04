_ = require 'underscore'
{Utils, CategoryStore} = require 'nylas-exports'
NylasObservables = require 'nylas-observables'

class Filter
  @ValueType:
    Enum: 'enum'
    String: 'string'

  @Comparators:
    contains: (actual, desired) -> actual.toLowerCase().indexOf(desired.toLowerCase()) isnt -1
    doesNotContain: (actual, desired) -> actual.toLowerCase().indexOf(desired.toLowerCase()) is -1
    beginsWith: (actual, desired) -> actual.toLowerCase().indexOf(desired.toLowerCase()) is 0
    endsWith: (actual, desired) -> actual.toLowerCase().lastIndexOf(desired.toLowerCase()) is actual.length - desired.length
    equals: (actual, desired) -> actual is desired

  @RuleTemplatesForAccount: (account) =>
    return [] unless account

    [{
      name: 'From'
      key: 'from'
      valueType: Filter.ValueType.String
    },{
      name: 'To'
      key: 'to'
      valueType: Filter.ValueType.String
    },{
      name: 'Cc'
      key: 'cc'
      valueType: Filter.ValueType.String
    },{
      name: 'Bcc'
      key: 'bcc'
      valueType: Filter.ValueType.String
    },{
      name: 'Any Recipient'
      key: 'anyRecipient'
      valueType: Filter.ValueType.String
    },{
      name: 'Subject'
      key: 'subject'
      valueType: Filter.ValueType.String
    },{
      name: 'Any attachment name'
      key: 'anyAttachmentName'
      valueType: Filter.ValueType.String
    },{
      name: 'body'
      key: 'body'
      valueType: Filter.ValueType.String
    }]

  @ActionTemplatesForAccount: (account) =>
    return [] unless account

    actions = [{
      name: 'Mark as read'
      key: 'markAsRead'
      valueType: 'none'
    },{
      name: 'Star message'
      key: 'star'
      valueType: 'none'
    }]

    if account.usesLabels()
      actions.push
        name: 'Apply Label'
        key: 'applyCategory'
        comparatorLabel: ':'
        valueType: Filter.ValueType.Enum
        values: NylasObservables.Categories.forAccount(account).map (cat) ->
            name: cat.displayName || cat.name
            value: cat.id
    else
      actions.push
        name: 'Move Message'
        key: 'applyCategory'
        comparatorLabel: 'to mailbox:'
        valueType: Filter.ValueType.Enum
        values: NylasObservables.Categories.forAccount(account).map (cat) ->
            name: cat.displayName || cat.name
            value: cat.id

    actions

  constructor: ->
    @id = Utils.generateTempId()
    @name = "Untitled Filter"
    @rules = [{key: 'to', comparator: 'contains', value: '', type: Filter.ValueType.String}]
    @actions = [{key: 'applyCategory', value: null}]

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
      if action.type is "applyCategory"
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
