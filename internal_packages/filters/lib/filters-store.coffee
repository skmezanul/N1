NylasStore = require 'nylas-store'
_ = require 'underscore'
_s = require 'underscore.string'
{Actions,
 CategoryStore,
 AccountStore,
 ChangeLabelsTask,
 ChangeFolderTask,
 TaskFactory,
 ChangeStarredTask,
 ChangeUnreadTask,
 Utils} = require 'nylas-exports'
Filter = require './filter'

# The FiltersStore performs all business logic for filters: the single source
# of truth for any other code using filters, the gateway to persisting data
# for filters, the subscriber to Actions which affect filters, and the
# publisher for all React components which render filters.
class FiltersStore extends NylasStore

  # The store's instantiation is the best time during the store life cycle
  # to both set the store's initial state and also subscribe to Actions which
  # will be published elsewhere.
  constructor: ->

    # ...here, we're setting initial state...
    @_filters = @_loadFilters()

    # ...and here, we're subscribing to Actions which could be fired by React
    # components, other stores, or any other part of the application.
    @listenTo Actions.deleteFilter, @_onDeleteFilter
    @listenTo Actions.createFilter, @_onCreateFilter
    @listenTo Actions.updateFilter, @_onUpdateFilter
    @listenTo Actions.didPassivelyReceiveNewModels, @_onNewModels

  # This method is the application's single source of truth for filters.
  # All FiltersStore consumers will invoke it to get the canonical filters at
  # the present moment.
  filters: =>
    @_filters

  # The callback for Action.deleteFilter. This action's publishers will pass to
  # the callback a filter id for the filter to be deleted.
  _onDeleteFilter: (id) =>
    @_filters = @_filters.filter (f) -> f.id isnt id
    @_saveFilters()
    @trigger()

  _onCreateFilter: =>
    @_filters.push(new Filter())
    @_saveFilters()
    @trigger()

  _onUpdateFilter: (id, properties) =>
    filter = _.find @_filters, (f) -> id is f.id
    filter[key] = val for key, val of properties
    @_saveFilters()
    @trigger()

  # The callback for Action.didPassivelyReceiveNewModels, a global action which
  # is published every time the application receives new data from the server.
  _onNewModels: (incoming) =>

  # The filters are stored in the config.cson file.
  _loadFilters: =>
    atom.config.get('filters') ? []

  # Rewrite the filters to the config.cson file.
  _saveFilters: =>
    atom.config.set('filters', @_filters)

# A best practice is to export an instance of the FiltersStore, NOT the class!
module.exports = new FiltersStore()
