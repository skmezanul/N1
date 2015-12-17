NylasStore = require 'nylas-store'
_ = require 'underscore'
_s = require 'underscore.string'
Rx = require 'rx-lite'
{Actions, DatabaseStore} = require 'nylas-exports'

FilterProcessor = require './filter-processor'

JSONBlobKey = "MailFiltersV1"

class FiltersStore extends NylasStore

  constructor: ->
    @_saveFiltersDebounced = _.debounce(@_saveFilters, 100)

    query = DatabaseStore.findJSONBlob(JSONBlobKey)
    @_subscription = Rx.Observable.fromQuery(query).subscribe (filters) =>
      @_filters = filters ? []
      @trigger()

    @listenTo Actions.addFilter, @_onAddFilter
    @listenTo Actions.deleteFilter, @_onDeleteFilter
    @listenTo Actions.updateFilter, @_onUpdateFilter

    if NylasEnv.isWorkWindow()
      @_processor = new FilterProcessor()
      @listenTo Actions.didPassivelyReceiveNewModels, (incoming) =>
        @_processor.processMessages(incoming['message'] ? [])

  filters: =>
    @_filters

  filtersForAccountId: (accountId) =>
    @_filters.filter (f) => f.accountId is accountId

  _onDeleteFilter: (id) =>
    @_filters = @_filters.filter (f) -> f.id isnt id
    @_saveFiltersDebounced()
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
    @_saveFiltersDebounced()
    @trigger()

  _onUpdateFilter: (id, properties) =>
    existing = _.find @_filters, (f) -> id is f.id
    existing[key] = val for key, val of properties
    @_saveFiltersDebounced()
    @trigger()

  _saveFilters: =>
    DatabaseStore.persistJSONBlob(JSONBlobKey, @_filters)


module.exports = new FiltersStore()
