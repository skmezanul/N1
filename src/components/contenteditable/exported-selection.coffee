{DOMUtils} = require 'nylas-exports'

# A saved out selection object
class ExportedSelection
  constructor: (@rawSelection, @scopeNode) ->
    @anchorNode = @rawSelection.anchorNode.cloneNode(true)
    @anchorOffset = @rawSelection.anchorOffset
    @anchorNodeIndex = DOMUtils.getNodeIndex(@scopeNode, @rawSelection.anchorNode)
    @focusNode = @rawSelection.focusNode.cloneNode(true)
    @focusOffset = @rawSelection.focusOffset
    @focusNodeIndex = DOMUtils.getNodeIndex(@scopeNode, @rawSelection.focusNode)
    @isCollapsed = @rawSelection.isCollapsed

module.exports = ExportedSelection
