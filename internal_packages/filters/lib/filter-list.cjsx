React = require 'react'
_ = require 'underscore'
Filter = require './filter'
FilterListItem = require './filter-list-item'
FiltersStore = require './filters-store'
{Actions} = require 'nylas-exports'
{Flexbox, ScrollRegion} = require 'nylas-component-kit'

class FilterList extends React.Component
  @displayName: 'FilterList'
  @containerStyles:
    height:'100%'

  constructor: ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push FiltersStore.listen @_onFiltersChange

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  render: =>
    <Flexbox className="container-filters" style={height:'100%'} direction="column">
      <ScrollRegion style={flex:1, order: 0}>
        {@_renderFilterItems()}
      </ScrollRegion>
      <div style={order:1} className="footer">
        <button className="btn" onClick={@_onCreateFilter}>
          Add filter
        </button>
        <button className="btn" onClick={@_onCreateFilter}>
          Run on existing mail
        </button>
      </div>
    </Flexbox>

  _renderFilterItems: =>
    @state.filters.map (filter) =>
      <FilterListItem key={filter.id}
                      filter={filter}
                      onDelete={ => @_onDeleteFilter(filter)} />

  _onCreateFilter: (filter) =>
    Actions.createFilter()

  _onDeleteFilter: (filter) =>
    Actions.deleteFilter(filter.id)

  _getStateFromStores: =>
    filters: FiltersStore.filters()

  _onFiltersChange: =>
    @setState @_getStateFromStores()

module.exports = FilterList
