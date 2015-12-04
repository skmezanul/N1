React = require 'react'
_ = require 'underscore'
Filter = require './filter'
FiltersStore = require './filters-store'
RuleEditorRow = require './rule-editor-row'
{CategoryStore, Actions, Utils} = require 'nylas-exports'
{RetinaImg, Flexbox} = require 'nylas-component-kit'


class RuleEditor extends React.Component
  @displayName: 'RuleEditor'
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
        key={idx}
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
