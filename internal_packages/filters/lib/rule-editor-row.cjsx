React = require 'react'
_ = require 'underscore'
Filter = require './filter'
FiltersStore = require './filters-store'
RuleEditor = require './rule-editor'
{CategoryStore, Actions, Utils} = require 'nylas-exports'
{Source} = require 'nylas-chainables'
{RetinaImg, Flexbox} = require 'nylas-component-kit'

class SourceSelect extends React.Component
  @displayName: 'SourceSelect'
  @propTypes:
    value: React.PropTypes.string
    onChange: React.PropTypes.func.isRequired
    options: React.PropTypes.object.isRequired

  constructor: (@props) ->
    @state =
      options: []

  componentDidMount: =>
    @_setupValuesSubscription()

  componentWillReceiveProps: (nextProps) =>
    @_setupValuesSubscription(nextProps)

  componentWillUnmount: =>
    @_unsubscribe?()

  _setupValuesSubscription: (props = @props) =>
    @_unsubscribe?()
    if @props.options instanceof Source
      @_unsubscribe = @props.options.listen =>
        @setState(options: @props.options.result())
      @setState(options: @props.options.result())
    else
      @setState(options: @props.options)

  render: =>
    options = @state.options

    <select value={@props.value} onChange={@props.onChange}>
      { @state.options.map ({value, name}) =>
        <option value={value}>{name}</option>
      }
    </select>

class RuleEditorRow extends React.Component
  @displayName: 'RuleEditorRow'
  @propTypes:
    rule: React.PropTypes.object.isRequired
    onChange: React.PropTypes.func
    onInsert: React.PropTypes.func
    onRemove: React.PropTypes.func
    templates: React.PropTypes.array

  constructor: (@props) ->

  render: =>
    <Flexbox direction="row" className="well-row">
      <span>
        {@_renderTemplateSelect()}
        {@_renderComparator()}
        {@_renderValue()}
      </span>
      <div style={flex: 1}></div>
      {@_renderActions()}
    </Flexbox>

  _renderTemplateSelect: =>
    options = @props.templates.map ({key, name}) =>
      <option value={key} key={key}>{name}</option>
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
      <SourceSelect value={@props.rule.value} onChange={@_onChangeValue} options={@_currentTemplate().values} />

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
    if not template
      console.error("Could not find template for rule key: #{@props.rule.key}")
    template

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

module.exports = RuleEditorRow
