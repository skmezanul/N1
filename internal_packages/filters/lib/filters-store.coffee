NylasStore = require 'nylas-store'
_ = require 'underscore'
_s = require 'underscore.string'
Rx = require 'rx-lite'
{Actions, DatabaseStore, Utils} = require 'nylas-exports'

{RuleMode, RuleTemplates, ActionTemplates} = require './filter-templates'
FilterProcessor = require './filter-processor'
FiltersJSONBlobKey = "MailFiltersV1"

class FiltersStore extends NylasStore
  constructor: ->
    query = DatabaseStore.findJSONBlob(FiltersJSONBlobKey)
    @_subscription = Rx.Observable.fromQuery(query).subscribe (filters) =>
      @_filters = filters ? []
      @trigger()

    @listenTo Actions.addFilter, @_onAddFilter
    @listenTo Actions.deleteFilter, @_onDeleteFilter
    @listenTo Actions.updateFilter, @_onUpdateFilter

    if NylasEnv.isWorkWindow()
      @_processor = new FilterProcessor()
      @listenTo Actions.reprocessFiltersForAccountId, (accountId) =>
        @_processor.processAllMessages(accountId)
      @listenTo Actions.didPassivelyReceiveNewModels, (incoming) =>
        @_processor.processMessages(incoming['message'] ? [])

  filters: =>
    @_filters

  filtersForAccountId: (accountId) =>
    @_filters.filter (f) => f.accountId is accountId

  _onDeleteFilter: (id) =>
    @_filters = @_filters.filter (f) -> f.id isnt id
    @_saveFilters()
    @trigger()

  _onAddFilter: (properties) =>
    defaults =
      id: Utils.generateTempId()
      name: "Untitled Filter"
      ruleMode: RuleMode.All
      rules: [RuleTemplates[0].createDefaultInstance()]
      actions: [ActionTemplates[0].createDefaultInstance()]

    unless properties.accountId
      throw new Error("Filter::constructor you must provide an account id.")

    @_filters.push(_.extend(defaults, properties))
    @_saveFilters()
    @trigger()

  _onUpdateFilter: (id, properties) =>
    existing = _.find @_filters, (f) -> id is f.id
    existing[key] = val for key, val of properties
    @_saveFilters()
    @trigger()

  _saveFilters: =>
    @_saveFiltersDebounced ?= _.debounce =>
      DatabaseStore.inTransaction (t) =>
        t.persistJSONBlob(FiltersJSONBlobKey, @_filters)
    ,1000
    @_saveFiltersDebounced()


module.exports = new FiltersStore()
