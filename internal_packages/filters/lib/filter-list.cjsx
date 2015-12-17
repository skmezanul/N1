React = require 'react'
_ = require 'underscore'
{ActionTemplatesForAccount, RuleTemplatesForAccount} = require './filter-templates'
FiltersStore = require './filters-store'
ScenarioEditor = require './scenario-editor'
{Actions, AccountStore} = require 'nylas-exports'
{Flexbox, EditableList} = require 'nylas-component-kit'

class FilterList extends React.Component
  @displayName: 'FilterList'
  @containerStyles:
    height:'100%'

  @propTypes:
    accountId: React.PropTypes.string.isRequired

  constructor: (@props) ->
    @state = @stateForAccount(@props.accountId)

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push FiltersStore.listen @_onFiltersChanged

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  componentWillReceiveProps: (newProps) =>
    newState = @stateForAccount(newProps.accountId)
    newState.selectedFilter = _.find newState.filters, (f) =>
      f.id is @state.selectedFilter?.id
    @setState(newState)

  stateForAccount: (accountId) =>
    account = AccountStore.itemWithId(accountId)
    return {
      filters: FiltersStore.filtersForAccountId(accountId)
      actionTemplates: ActionTemplatesForAccount(account)
      ruleTemplates: RuleTemplatesForAccount(account)
      account: account
    }

  render: =>
    <div className="container-filters">
      <section>
        <h2>
          <button className="btn" style={float:'right'} onClick={@_onReprocessFilters}>
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
      items={@state.filters}
      itemContent={ (filter) -> filter.name }
      onCreateItem={@_onAddFilter}
      onDeleteItem={@_onDeleteFilter}
      onItemEdited={@_onFilterNameEdited}
      selected={@state.selectedFilter}
      onSelectItem={@_onSelectFilter} />

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
        <ScenarioEditor
          rules={filter.rules}
          templates={@state.ruleTemplates}
          onChange={ (rules) => Actions.updateFilter(filter.id, {rules}) }
          className="well well-matchers"/>
        <span>Perform the following actions:</span>
        <ScenarioEditor
          rules={filter.actions}
          templates={@state.actionTemplates}
          onChange={ (actions) => Actions.updateFilter(filter.id, {actions}) }
          className="well well-actions"/>
      </div>

    else
      <div className="filter-detail">
        <div className="no-selection">Create a filter or select one to get started</div>
      </div>

  _onReprocessFilters: =>
    Actions.reprocessFiltersForAccountId(@state.account.id)

  _onAddFilter: =>
    Actions.addFilter({accountId: @state.account.id})

  _onSelectFilter: (name, idx) =>
    @setState(selectedFilter: @state.filters[idx])

  _onDeleteFilter: (name, idx) =>
    Actions.deleteFilter(@state.filters[idx].id)

  _onFilterNameEdited: (newName, oldName, idx) =>
    Actions.updateFilter(@state.filters[idx].id, {name: newName})

  _onFilterRuleModeEdited: (event) =>
    Actions.updateFilter(@state.selectedFilter.id, {ruleMode: event.target.value})

  _onFiltersChanged: =>
    @setState(filters: FiltersStore.filtersForAccountId(@props.accountId))


module.exports = FilterList
