React = require 'react'
_ = require 'underscore'
Rx = require 'rx-lite'
ScenarioEditor = require './scenario-editor'
{CategoryStore, Actions, Utils} = require 'nylas-exports'
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
    @_subscription?.dispose()
    @_subscription = null

  _setupValuesSubscription: (props = @props) =>
    @_subscription?.dispose()
    @_subscription = null
    if props.options instanceof Rx.Observable
      @_subscription = props.options.subscribe (options) =>
        @setState({options})
    else
      @setState(options: props.options)

  render: =>
    options = @state.options

    <select value={@props.value} onChange={@props.onChange}>
      { @state.options.map ({value, name}) =>
        <option key={value} value={value}>{name}</option>
      }
    </select>

class ScenarioEditorRow extends React.Component
  @displayName: 'ScenarioEditorRow'
  @propTypes:
    rule: React.PropTypes.object.isRequired
    removable: React.PropTypes.bool
    templates: React.PropTypes.array.isRequired
    onChange: React.PropTypes.func
    onInsert: React.PropTypes.func
    onRemove: React.PropTypes.func

  constructor: (@props) ->

  render: =>
    template = _.findWhere(@props.templates, {key: @props.rule.key})
    unless template
      return <span> Could not find template for rule key: {@props.rule.key}</span>

    <Flexbox direction="row" className="well-row">
      <span>
        {@_renderTemplateSelect(template)}
        {@_renderComparator(template)}
        <span>{template.valueLabel}</span>
        {@_renderValue(template)}
      </span>
      <div style={flex: 1}></div>
      {@_renderActions()}
    </Flexbox>

  _renderTemplateSelect: (template) =>
    options = @props.templates.map ({key, name}) =>
      <option value={key} key={key}>{name}</option>
    <select value={@props.rule.key} onChange={@_onChangeTemplate}>
      {options}
    </select>

  _renderComparator: (template) =>
    if template.valueComparators
      <select value={@props.rule.valueComparator} onChange={@_onChangeComparator}>
        { _.map template.valueComparators, (k, v) => <option value={k}>{v}</option> }
      </select>
    else
      false

  _renderValue: (template) =>
    if template.valueType is 'enum'
      <SourceSelect value={@props.rule.value} onChange={@_onChangeValue} options={template.values} />

    else if template.valueType is 'string'
      <input type="string" value={@props.rule.value} onChange={@_onChangeValue}/>

    else
      false

  _renderActions: =>
    <div className="actions">
      { if @props.removable then <div className="btn" onClick={@props.onRemove}>-</div> }
      <div className="btn" onClick={@props.onInsert}>+</div>
    </div>

  _onChangeValue: (event) =>
    rule = _.clone(@props.rule)
    rule.value = event.target.value
    @props.onChange(rule)

  _onChangeComparator: (event) =>
    rule = _.clone(@props.rule)
    rule.valueComparator = event.target.value
    @props.onChange(rule)

  _onChangeTemplate: (event) =>
    rule = _.clone(@props.rule)

    existingTemplate = _.findWhere(@props.templates, key: rule.key)
    newTemplate = _.findWhere(@props.templates, key: event.target.value)

    rule = newTemplate.coerceInstance(rule)

    @props.onChange(rule)

module.exports = ScenarioEditorRow
