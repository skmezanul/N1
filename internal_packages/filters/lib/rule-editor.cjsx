React = require 'react'
_ = require 'underscore'
Filter = require './filter'
FiltersStore = require './filters-store'
RuleEditor = require './rule-editor'
{CategoryStore, Actions, Utils} = require 'nylas-exports'
{RetinaImg, Flexbox} = require 'nylas-component-kit'

class RuleEditorRow extends React.Component
  @displayName: 'RuleEditorRow'
  @propTypes:
    rule: React.PropTypes.object
    onChange: React.PropTypes.func
    onInsert: React.PropTypes.func
    onRemove: React.PropTypes.func
    templates: React.PropTypes.array

  constructor: (@props) ->

  render: =>
    <Flexbox direction="row" className="well-row">
      {@_renderTemplateSelect()}
      {@_renderComparator()}
      {@_renderValue()}
      <div style={flex: 1}></div>
      {@_renderActions()}
    </Flexbox>

  _renderTemplateSelect: =>
    options = @props.templates.map ({key, name}) =>
      <option value={key}>{name}</option>
    <select value={@props.rule.key} onChange={@_onChangeTemplate}>
      {options}
    </select>

  _renderComparator: =>
    if @props.rule.valueType is 'enum'
      <span>{@_currentTemplate().comparatorLabel || " in "}</span>

    else if @props.rule.valueType is 'string'
      <select value={@props.rule.comparator} onChange={@_onChangeComparator}>
        <option value='contains'>contains</option>
        <option value='doesNotContain'>does not contain</option>
        <option value='beginsWith'>begins with</option>
        <option value='endsWith'>ends with</option>
        <option value='equals'>is equal to</option>
      </select>

    else
      <span></span>

  _renderValue: =>
    if @props.rule.valueType is 'enum'
      <select value={@props.rule.value} onChange={@_onChangeValue}>
        { @_currentTemplate().values.map ({value, name}) =>
          <option value={value}>{name}</option>
        }
      </select>

    else if @props.rule.valueType is 'string'
      <input type="string" value={@props.rule.value} onChange={@_onChangeValue}/>

    else
      <span></span>

  _renderActions: =>
    <div className="actions">
      <div className="btn" onClick={@props.onRemove}>-</div>
      <div className="btn" onClick={@props.onInsert}>+</div>
    </div>

  _currentTemplate: =>
    template = _.find @props.templates, (t) => t.key is @props.rule.key

  _onChangeValue: (event) =>
    rule = _.clone(@props.rule)
    rule.value = event.target.value
    @props.onChange(rule)

  _onChangeComparator: (event) =>
    rule = _.clone(@props.rule)
    rule.comparator = event.target.value
    @props.onChange(rule)

  _onChangeTemplate: (event) =>
    templateKey = event.target.value
    template = _.find @props.templates, (t) -> t.key is templateKey
    rule = _.clone(@props.rule)

    if rule.valueType isnt template.valueType
      rule.value = null
      rule.comparator = null
    rule.valueType = template.valueType
    rule.key = template.key
    @props.onChange(rule)


class RuleEditor extends React.Component
  @displayName: 'FilterListItem'
  @propTypes:
    rules: React.PropTypes.array
    className: React.PropTypes.string
    onChange: React.PropTypes.func
    templates: React.PropTypes.array

  constructor: (@props) ->
    @state =
      collapsed: true

  render: =>
    <div className={@props.className}>
    { (@props.rules || []).map (rule, idx) =>
      <RuleEditorRow
        rule={rule}
        templates={@props.templates}
        onRemove={ => @_onRemoveRule(idx) }
        onInsert={ => @_onInsertRule(idx) }
        onChange={ (rule) => @_onChangeRowValue(rule, idx) } />
    }
    </div>

  _performChange: (block) =>
    rules = JSON.parse(JSON.stringify(@props.rules))
    block(rules)
    @props.onChange(rules)

  _onRemoveRule: (idx) =>
    @_performChange (rules) =>
      return if rules.length is 1
      rules.splice(idx, 1)

  _onInsertRule: (idx) =>
    @_performChange (rules) =>
      {key, type} = @props.templates[0]
      rules.push({key, type})

  _onChangeRowValue: (newRule, idx) =>
    @_performChange (rules) =>
      rules[idx] = newRule

module.exports = RuleEditor
