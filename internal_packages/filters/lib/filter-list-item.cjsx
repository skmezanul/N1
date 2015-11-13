React = require 'react'
_ = require 'underscore'
Filter = require './filter'
RuleEditor = require './rule-editor'
{CategoryStore, Actions, Utils} = require 'nylas-exports'

class FilterListItem extends React.Component
  @displayName: 'FilterListItem'
  @propTypes:
    filter: React.PropTypes.object.isRequired

  constructor: ->
    @state =
      collapsed: false

  render: ->
    buttonStyles = paddingLeft: 15
    lineItemStyles =
      whiteSpace: "nowrap"
      overflow: "auto"

    <div className="filter-item">
      <div className="header" onClick={@_onToggleCollapsed}>
        <div className="pull-right action-button" onClick={@props.onDelete}>delete</div>
        <div className="title">{@props.filter.name}</div>
      </div>
      {@_renderDetails()}
    </div>

  _renderDetails: =>
    return false if @state.collapsed

    <div className="details">
      <span>If </span>
      <select value={@props.filter.ruleMode} onChange={@_onChangeRuleMode}>
        <option value='any'>Any</option>
        <option value='all'>All</option>
      </select>
      <span> of the following conditions are met:</span>
      <RuleEditor
        rules={@props.filter.rules}
        templates={Filter.RuleTemplates}
        onChange={ (rules) => Actions.updateFilter(@props.filter.id, {rules}) }
        className="well well-matchers"/>
      <span>Perform the following actions:</span>
      <RuleEditor
        rules={@props.filter.actions}
        templates={Filter.ActionTemplates}
        onChange={ (actions) => Actions.updateFilter(@props.filter.id, {actions}) }
        className="well well-actions"/>
    </div>

  _onChangeRuleMode: (event) =>
    Actions.updateFilter(@props.filter.id, {ruleMode: event.target.value})

  _onToggleCollapsed: =>
    @setState(collapsed: !@state.collapsed)

module.exports = FilterListItem
