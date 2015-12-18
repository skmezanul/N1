NylasStore = require 'nylas-store'
_ = require 'underscore'
Rx = require 'rx-lite'
DatabaseStore = require './database-store'
Utils = require '../models/utils'
Actions = require '../actions'

{RuleMode, RuleTemplates, ActionTemplates} = require './mail-filters-templates'

FiltersJSONBlobKey = "MailFiltersV1"

class MailFiltersStore extends NylasStore
  constructor: ->
    query = DatabaseStore.findJSONBlob(FiltersJSONBlobKey)
    @_subscription = Rx.Observable.fromQuery(query).subscribe (filters) =>
      @_filters = filters ? []
      @trigger()

    @listenTo Actions.addFilter, @_onAddFilter
    @listenTo Actions.deleteFilter, @_onDeleteFilter
    @listenTo Actions.updateFilter, @_onUpdateFilter

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


module.exports = new MailFiltersStore()
