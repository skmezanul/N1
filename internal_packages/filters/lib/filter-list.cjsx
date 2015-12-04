React = require 'react'
_ = require 'underscore'
Filter = require './filter'
FiltersStore = require './filters-store'
RuleEditor = require './rule-editor'
{Actions, AccountStore} = require 'nylas-exports'
{Flexbox, EditableList} = require 'nylas-component-kit'

class FilterList extends React.Component
  @displayName: 'FilterList'
  @containerStyles:
    height:'100%'

  @propTypes:
    accountId: React.PropTypes.string.isRequired

  constructor: (@props) ->
    @state = _.extend @_getStateFromStores(),
      selectedFilter: null

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push FiltersStore.listen @_onFiltersChange

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  componentWillReceiveProps: (newProps) =>
    @setState(@_getStateFromStores(newProps))

  render: =>
    <div className="container-filters">
      <section>
        <h2>
          <button className="btn" style={float:'right'} onClick={@_onCreateFilter}>
            Run on existing mail
          </button>
          Mail Rules
        </h2>
        <p>{@state.account?.emailAddress}</p>

        <Flexbox>
          {@_renderList()}
          {@_renderDetail()}
        </Flexbox>
      </section>
    </div>

  _renderList: =>
    <EditableList
       className="filter-list"
      onCreateItem={@_onCreateFilter}
      onDeleteItem={@_onDeleteFilter}
      onItemEdited={@_onFilterNameEdited}
      initialState={selected: @state.selectedFilter}
      onItemSelected={@_onSelectFilter}>
      { @state.filters.map (filter) =>
          filter.name
      }
    </EditableList>

  _renderDetail: =>
    filter = @state.selectedFilter

    if filter
      <div className="filter-detail">
        <span>If </span>
        <select value={filter.ruleMode} onChange={@_onFilterRuleModeEdited}>
          <option value='any'>Any</option>
          <option value='all'>All</option>
        </select>
        <span> of the following conditions are met:</span>
        <RuleEditor
          rules={filter.rules}
          templates={Filter.RuleTemplatesForAccount(@state.account)}
          onChange={ (rules) => Actions.updateFilter(filter.id, {rules}) }
          className="well well-matchers"/>
        <span>Perform the following actions:</span>
        <RuleEditor
          rules={filter.actions}
          templates={Filter.ActionTemplatesForAccount(@state.account)}
          onChange={ (actions) => Actions.updateFilter(filter.id, {actions}) }
          className="well well-actions"/>
      </div>

    else
      <div>Create a filter or select one to get started</div>

  _onCreateFilter: (filter) =>
    Actions.createFilter()

  _onSelectFilter: (name, idx) =>
    @setState(selectedFilter: @state.filters[idx])

  _onDeleteFilter: (name, idx) =>
    Actions.deleteFilter(@state.filters[idx].id)

  _onFilterNameEdited: (newName, oldName, idx) =>
    Actions.updateFilter(@state.filters[idx].id, {name: newName})

  _onFilterRuleModeEdited: (event) =>
    Actions.updateFilter(@state.selectedFilter.id, {ruleMode: event.target.value})

  _getStateFromStores: (props = @props) =>
    filters: FiltersStore.filters()
    account: _.find AccountStore.items(), (a) -> a.id is props.accountId

  _onFiltersChange: =>
    @setState @_getStateFromStores()

module.exports = FilterList
