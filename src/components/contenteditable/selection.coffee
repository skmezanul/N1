_ = require 'underscore'
{DOMUtils} = require 'nylas-exports'
ExportedSelection = require 'exported-selection'

# Convenience methods over the DOM's Selection object
# https://developer.mozilla.org/en-US/docs/Web/API/Selection
class Selection
  constructor: (@rawSelection, @scopeNode) ->
    @scopeNode ?= document.body
    @rawSelection ?= document.getSelection()

  setScope: (@scopeNode) ->

  select: (args...) ->
    if args.length is 0
      throw @_errBadUsage()
    else if args.length is 1
      if args[0] instanceof ExportedSelection
        @importSelection(args[0])
      else
        @selectAt(args[0])
    else if args.length is 2
      @selectFromTo(args...)
    else if args.length is 3
      throw @_errBadUsage()
    else if args.length is 4
      @selectFromToWithIndex(args...)
    else if args.length >= 5
      throw @_errBadUsage()

  selectAt: (at) ->
    nodeAt = @findNodeAt(at)
    @setBaseAndExtent(nodeAt, 0, nodeAt, (nodeAt.length ? 0))

  selectFromTo: (from, to) ->
    fromNode = @findNodeAt(from)
    toNode = @findNodeAt(to)
    @setBaseAndExtent(fromNode, 0, toNode, (toNode.length ? 0))

  selectFromToWithIndex: (from, fromIndex, to, toIndex) ->
    fromNode = @findNodeAt(from)
    toNode = @findNodeAt(to)
    if (not _.isNumber(fromIndex)) or (not _.isNumber(toIndex))
      throw @_errBadUsage()
    @setBaseAndExtent(fromNode, fromIndex, toNode, toIndex)

  exportSelection: -> new ExportedSelection(@rawSelection, @scopeNode)

  importSelection: (exportedSelection) ->
    newAnchorNode = DOMUtils.findSimilarNodes(@scopeNode, exportedSelection.anchorNode)[exportedSelection.anchorNodeIndex]

    newFocusNode = DOMUtils.findSimilarNodes(@scopeNode, exportedSelection.focusNode)[exportedSelection.focusNodeIndex]

    @setBaseAndExtent(newAnchorNode,
                      exportedSelection.anchorOffset,
                      newFocusNode,
                      exportedSelection.focusOffset)

  findNodeAt: (arg) ->
    if arg instanceof Node
      return arg
    else if _.isString(arg)
      return @scopeNode.querySelector(arg)
    else if _.isRegExp(arg)
      ## TODO
      DOMUtils.findNodeByRegex(@scopeNode, arg)
      return

  Object.defineProperty @prototype, "anchorNode",
    get: -> @rawSelection.anchorNode
    set: -> throw @_errNoSet("anchorNode")
  Object.defineProperty @prototype, "anchorOffset",
    get: -> @rawSelection.anchorOffset
    set: -> throw @_errNoSet("anchorOffset")
  Object.defineProperty @prototype, "focusNode",
    get: -> @rawSelection.focusNode
    set: -> throw @_errNoSet("focusNode")
  Object.defineProperty @prototype, "focusOffset",
    get: -> @rawSelection.focusOffset
    set: -> throw @_errNoSet("focusOffset")
  Object.defineProperty @prototype, "isCollapsed",
    get: -> @rawSelection.isCollapsed
    set: -> throw @_errNoSet("isCollapsed")
  Object.defineProperty @prototype, "rangeCount",
    get: -> @rawSelection.rangeCount
    set: -> throw @_errNoSet("rangeCount")

  setBaseAndExtent: (args...) -> @rawSelection.setBaseAndExtent(args...)
  getRangeAt: (args...) -> @rawSelection.getRangeAt(args...)
  collapse: (args...) -> @rawSelection.collapse(args...)
  extend: (args...) -> @rawSelection.extend(args...)
  modify: (args...) -> @rawSelection.modify(args...)
  collapseToStart: (args...) -> @rawSelection.collapseToStart(args...)
  collapseToEnd: (args...) -> @rawSelection.collapseToEnd(args...)
  selectAllChildren: (args...) -> @rawSelection.selectAllChildren(args...)
  addRange: (args...) -> @rawSelection.addRange(args...)
  removeRange: (args...) -> @rawSelection.removeRange(args...)
  removeAllRanges: (args...) -> @rawSelection.removeAllRanges(args...)
  deleteFromDocument: (args...) -> @rawSelection.deleteFromDocument(args...)
  toString: (args...) -> @rawSelection.toString(args...)
  containsNode: (args...) -> @rawSelection.containsNode(args...)

  _errBadUsage: -> new Error("Invalid arguments")
  _errNoSet: (property) -> new Error("Can't set #{property}")


module.exports = Selection
