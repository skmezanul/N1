NylasStore = require 'nylas-store'
_ = require 'underscore'
_s = require 'underscore.string'
{Actions} = require 'nylas-exports'
Filter = require './filter'

class FiltersStore extends NylasStore

  constructor: ->
    @_filters = @_loadFilters()

    @_saveFiltersDebounced = _.debounce(@_saveFilters, 100)

    @listenTo Actions.addFilter, @_onAddFilter
    @listenTo Actions.deleteFilter, @_onDeleteFilter
    @listenTo Actions.updateFilter, @_onUpdateFilter
    @listenTo Actions.didPassivelyReceiveNewModels, @_onNewModels

  filters: =>
    @_filters

  filtersForAccountId: (accountId) =>
    @_filters.filter (f) => f.accountId is accountId

  _onDeleteFilter: (id) =>
    @_filters = @_filters.filter (f) -> f.id isnt id
    @_saveFiltersDebounced()
    @trigger()

  _onAddFilter: (properties) =>
    @_filters.push(new Filter(properties))
    @_saveFiltersDebounced()
    @trigger()

  _onUpdateFilter: (id, properties) =>
    existing = _.find @_filters, (f) -> id is f.id
    existing[key] = val for key, val of properties
    @_saveFiltersDebounced()
    @trigger()

  _onNewModels: (incoming) =>
    incomingMessages = incoming.message
    return unless incomingMessages.length > 0

    # When messages arrive, we process all the messages in parallel, but one
    # filter at a time. This is important, because users can order filters which
    # may do and undo a change. Ie: "Star if from Ben, Unstar if subject is "Bla"

    Promise.each @_filters, (filter) ->
      matchingMessages = incomingMessages.filter(filter.matches)
      Promise.map matchingMessages, (message) ->
        # We always pull the thread from the database, even though it may be in
        # `incoming.thread`, because filters may be modifying it as they run!
        DatabaseStore.find(Thread, message.threadId).then (thread) ->
          return filter.applyTo(message, thread)

  _loadFilters: =>
    atom.config.get('filters') ? []

  _saveFilters: =>
    atom.config.set('filters', @_filters)


module.exports = new FiltersStore()
