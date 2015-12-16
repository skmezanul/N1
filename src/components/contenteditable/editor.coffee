# An extended interface of execCommand
#
# Muates the DOM and Selection in atomic and predictable ways.
#
# editor.select(/{{}}/).checkNode().wrapNode("code")
#
# codeTags.forEach (tag) ->
#   if testTag(tag) DOMUtils.unwrap(tag)
#
class Editor
  constructor: (@rootNode, @selection) ->
    @selection.setScope(@rootNode)

  select: (args...) ->
    @selection.select(args...)
    return @

  wrapNode: ->
    ## TODO
    return @

  normalize: ->
    @rootNode.normalize()
    return @

  backColor: (color) -> @_ec("backColor", false, color)
  bold: -> @_ec("bold", false)
  contentReadOnly: -> @_notImplemented()
  copy: -> @_ec("copy", false)
  createLink: (uri) -> @_ec("createLink", false, uri)
  cut: -> @_ec("cut", false)
  decreaseFontSize: -> @_ec("decreaseFontSize", false)
  delete: -> @_ec("delete", false)
  enableInlineTableEditing: -> @_notImplemented()
  enableObjectResizing: -> @_notImplemented()
  fontName: (fontName) -> @_ec("fontName", false, fontName)
  fontSize: (fontSize) -> @_ec("fontSize", false, fontSize)
  foreColor: (color) -> @_ec("foreColor", false, color)
  formatBlock: (tagName) -> @_ec("formatBlock", false, tagName)
  forwardDelete: -> @_ec("forwardDelete", false)
  heading: (tagName) -> @_ec("heading", false, tagName)
  hiliteColor: (color) -> @_ec("hiliteColor", false, color)
  increaseFontSize: -> @_ec("increaseFontSize", false)
  indent: -> @_ec("indent", false)
  insertBrOnReturn: -> @_notImplemented()
  insertHorizontalRule: -> @_ec("insertHorizontalRule", false)
  insertHTML: (html) -> @_ec("insertHTML", false, html)
  insertImage: (uri) -> @_ec("insertImage", false, uri)
  insertOrderedList: -> @_ec("insertOrderedList", false)
  insertUnorderedList: -> @_ec("insertUnorderedList", false)
  insertParagraph: -> @_ec("insertParagraph", false)
  insertText: (text) -> @_ec("insertText", false, text)
  italic: -> @_ec("italic", false)
  justifyCenter: -> @_ec("justifyCenter", false)
  justifyFull: -> @_ec("justifyFull", false)
  justifyLeft: -> @_ec("justifyLeft", false)
  justifyRight: -> @_ec("justifyRight", false)
  outdent: -> @_ec("outdent", false)
  paste: -> @_ec("paste", false)
  redo: -> @_ec("redo", false)
  removeFormat: -> @_ec("removeFormat", false)
  selectAll: -> @_ec("selectAll", false)
  strikeThrough: -> @_ec("strikeThrough", false)
  subscript: -> @_ec("subscript", false)
  superscript: -> @_ec("superscript", false)
  underline: -> @_ec("underline", false)
  undo: -> @_ec("undo", false)
  unlink: -> @_ec("unlink", false)
  useCSS: -> @_notImplemented()
  styleWithCSS: (style) -> @_ec("styleWithCSS", false, style)

  _ec: (args...) -> document.execCommand(args...); return @
  _notImplemented: -> throw new Error("Not implemented")

module.exports = Editor
