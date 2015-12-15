ContenteditableService = require './contenteditable-service'

class MouseService extends ContenteditableService
  constructor: ->
    super
    @setup()

  eventHandlers: ->
    onClick: @_onClick

  _onClick: (event) ->
    # We handle mouseDown, mouseMove, mouseUp, but we want to stop propagation
    # of `click` to make it clear that we've handled the event.
    # Note: Related to composer-view#_onClickComposeBody
    event.stopPropagation()

  # We use global listeners to determine whether or not dragging is
  # happening. This is because dragging may stop outside the scope of
  # this element. Note that the `dragstart` and `dragend` events don't
  # detect text selection. They are for drag & drop.
  setup: ->
    @__onMouseDown = _.bind(@_onMouseDown, @)
    @__onMouseMove = _.bind(@_onMouseMove, @)
    @__onMouseUp = _.bind(@_onMouseUp, @)
    window.addEventListener("mousedown", @__onMouseDown)
    window.addEventListener("mouseup", @__onMouseUp)

  teardown: ->
    window.removeEventListener("mousedown", @__onMouseDown)
    window.removeEventListener("mouseup", @__onMouseUp)

  _onMouseDown: (event) =>
    @_mouseDownEvent = event
    @_mouseHasMoved = false
    window.addEventListener("mousemove", @__onMouseMove)

    # We can't use the native double click event because that only fires
    # on the second up-stroke
    if Date.now() - (@_lastMouseDown ? 0) < 250
      @_onDoubleDown(event)
      @_lastMouseDown = 0 # to prevent triple down
    else
      @_lastMouseDown = Date.now()

  _onDoubleDown: (event) =>
    editable = @innerState.editableNode
    return unless editable?
    if editable is event.target or editable.contains(event.target)
      @setInnerState doubleDown: true

  _onMouseMove: (event) =>
    if not @_mouseHasMoved
      @_onDragStart(@_mouseDownEvent)
      @_mouseHasMoved = true

  _onMouseUp: (event) =>
    window.removeEventListener("mousemove", @__onMouseMove)

    if @innerState.doubleDown
      @setInnerState doubleDown: false

    if @_mouseHasMoved
      @_mouseHasMoved = false
      @_onDragEnd(event)

    editableNode = @innerState.editableNode
    selection = document.getSelection()
    return event unless DOMUtils.selectionInScope(selection, editableNode)

    @_runEventCallbackOnExtensions("onClick", event)
    return event

  _onDragStart: (event) =>
    editable = @innerState.editableNode
    return unless editable?
    if editable is event.target or editable.contains(event.target)
      @setInnerState dragging: true

  _onDragEnd: (event) =>
    if @innerState.dragging
      @setInnerState dragging: false
    return event


module.exports = MouseService
