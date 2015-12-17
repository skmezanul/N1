_ = require 'underscore'
{Utils, CategoryStore} = require 'nylas-exports'
ScenarioEditor = require './scenario-editor'
NylasObservables = require 'nylas-observables'

RuleMode =
  Any: 'any'
  All: 'all'

RuleComparator =
  contains: ({actual, desired}) -> actual.toLowerCase().indexOf(desired.toLowerCase()) isnt -1
  doesNotContain: ({actual, desired}) -> actual.toLowerCase().indexOf(desired.toLowerCase()) is -1
  beginsWith: ({actual, desired}) -> actual.toLowerCase().indexOf(desired.toLowerCase()) is 0
  endsWith: ({actual, desired}) -> actual.toLowerCase().lastIndexOf(desired.toLowerCase()) is actual.length - desired.length
  equals: ({actual, desired}) -> actual is desired

RuleComparatorNames =
  'contains': 'contains'
  'does not contain': 'doesNotContain'
  'begins with': 'beginsWith'
  'ends with': 'endsWith'
  'equals': 'equals'

BaseRuleTemplates = [
  new ScenarioEditor.Template.String('from', {name: 'From', valueComparators: RuleComparatorNames})
  new ScenarioEditor.Template.String('to', {name: 'To', valueComparators: RuleComparatorNames})
  new ScenarioEditor.Template.String('cc', {name: 'Cc', valueComparators: RuleComparatorNames})
  new ScenarioEditor.Template.String('bcc', {name: 'Bcc', valueComparators: RuleComparatorNames})
  new ScenarioEditor.Template.String('anyRecipient', {name: 'Any Recipient', valueComparators: RuleComparatorNames})
  new ScenarioEditor.Template.String('anyAttachmentName', {name: 'Any attachment name', valueComparators: RuleComparatorNames})
  new ScenarioEditor.Template.String('subject', {name: 'Subject', valueComparators: RuleComparatorNames})
  new ScenarioEditor.Template.String('body', {name: 'Body', valueComparators: RuleComparatorNames})
]

BaseActionTemplates = [
  new ScenarioEditor.Template.Base('markAsRead', {name: 'Mark as read'})
  new ScenarioEditor.Template.Base('star', {name: 'Star message'})
]

class Filter
  @RuleMode: RuleMode

  @RuleTemplatesForAccount: (account) ->
    return [] unless account
    return BaseRuleTemplates

  @ActionTemplatesForAccount: (account) ->
    return [] unless account
    actions = [].concat(BaseActionTemplates)

    if account.usesLabels()
      actions.push new ScenarioEditor.Template.Enum('applyCategory', {
        name: 'Apply Label'
        values: NylasObservables.Categories.forAccount(account).sort().map (cats) ->
          cats.map (cat) ->
            name: cat.displayName || cat.name
            value: cat.id
        })

    else
      actions.push new ScenarioEditor.Template.Enum('applyCategory', {
        name: 'Move Message'
        valueLabel: 'to mailbox:'
        values: NylasObservables.Categories.forAccount(account).sort().map (cats) ->
          cats.map (cat) ->
            name: cat.displayName || cat.name
            value: cat.id
        })

    actions

  constructor: (properties) ->
    defaults =
      id: Utils.generateTempId()
      name: "Untitled Filter"
      rules: [BaseRuleTemplates[0].createDefaultInstance()]
      ruleMode: RuleMode.All
      actions: [BaseActionTemplates[0].createDefaultInstance()]

    _.extend(@, defaults, properties)

    unless @accountId
      throw new Error("Filter::constructor you must provide an account id.")

    @

  matches: (message) ->
    if @ruleMode is RuleMode.All
      fn = _.every
    else
      fn = _.any

    fn @rules, (rule) => @_matchesRule(message, rule)

  _matchesRule: (message, rule) ->
    if rule.key is 'anyRecipient'
      value = [].concat(message.to, message.cc, message.bcc, message.from)
    else if rule.key is 'anyAttachmentName'
      value = message.files.map (f) -> f.filename
    else
      value = message[rule.key]

    if rule.key in ['to', 'cc', 'bcc', 'from', 'anyRecipient']
      value = value.map (c) -> c.email

    if rule.valueComparator
      matchFunction = RuleComparator[rule.valueComparator]
      if not matchFunction
        throw new Error("Filter::matches - unknown comparator: #{rule.valueComparator}")
    else
      matchFunction = RuleComparator['equals']

    if value instanceof Array
      return _.any value, (subvalue) -> matchFunction(actual: subvalue, desired: rule.value)
    else
      return matchFunction(actual: value, desired: rule.value)

  applyTo: (message, thread) ->
    tasks = []
    @_actions.forEach (action) ->
      if action.type is "applyCategory"
        tasks.push new ChangeFolderTask
          folder: action.value
          threads: [thread]

      else if action.type is "markAsRead"
        tasks.push new ChangeUnreadTask
          unread: false
          threads: [thread]

      else if action.type is "star"
        tasks.push new ChangeStarredTask
          starred: true
          threads: [thread]

    promises = tasks.map(TaskQueueStatusStore.waitForPerformLocal)
    tasks.forEach(Actions.queueTask)
    Promise.all(promises)

module.exports = Filter
