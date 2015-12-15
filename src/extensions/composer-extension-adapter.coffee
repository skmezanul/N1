_ = require 'underscore'
{deprecate} = require '../deprecate-utils'
DOMUtils = require '../dom-utils'

ComposerExtensionAdapter = (extension) ->

  if extension.onInput?
    origInput = extension.onInput
    extension.onContentChanged = (editor, mutations) ->
      origInput(editor.editableNode)

    extension.onInput = deprecate(
      "DraftStoreExtension.onInput",
      "ComposerExtension.onContentChanged",
      extension,
      extension.onContentChanged
    )

  if extension.onTabDown?
    origKeyDown = extension.onKeyDown
    extension.onKeyDown = (editor, event) ->
      if event.key is "Tab"
        range = DOMUtils.getRangeInScope(editor.editableNode)
        extension.onTabDown(editor.editableNode, range, event)
      else
        origKeyDown?(event, editor.editableNode, editor.selection)

    extension.onKeyDown = deprecate(
      "DraftStoreExtension.onTabDown",
      "ComposerExtension.onKeyDown",
      extension,
      extension.onKeyDown
    )

  if extension.onMouseUp?
    origOnClick = extension.onClick
    extension.onClick = (editor, event) ->
      range = DOMUtils.getRangeInScope(editor.editableNode)
      extension.onMouseUp(editor.editableNode, range, event)
      origOnClick?(event, editor.editableNode, editor.selection)

    extension.onClick = deprecate(
      "DraftStoreExtension.onMouseUp",
      "ComposerExtension.onClick",
      extension,
      extension.onClick
    )

  return extension

module.exports = ComposerExtensionAdapter
