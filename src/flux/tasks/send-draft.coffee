_ = require 'underscore'
Actions = require '../actions'
DatabaseStore = require '../stores/database-store'
Message = require '../models/message'
{APIError} = require '../errors'
Task = require './task'
TaskQueue = require '../stores/task-queue'
FileUploadTask = require './file-upload-task'
NylasAPI = require '../nylas-api'
SoundRegistry = require '../../sound-registry'

module.exports =
class SendDraftTask extends Task

  constructor: (@draftClientId, {@fromPopout}={}) ->
    super

  label: ->
    "Sending draft..."

  shouldDequeueOtherTask: (other) ->
    other instanceof SendDraftTask and other.draftClientId is @draftClientId

  isDependentTask: (other) ->
    (other instanceof FileUploadTask and other.messageClientId is @draftClientId)

  onDependentTaskError: (task, err) ->
    if task instanceof FileUploadTask
      msg = "Your message could not be sent because a file failed to upload. Please try re-uploading your file and try again."
    @_notifyUserOfError(msg) if msg

  # The minute the user wants to send the draft, we grab the text from the
  # draft and save it locally. That is the actual text that we will send
  # regardless of what happens to the draft after this point.
  performLocal: ->
    console.log("Perform Local!", Date.now())
    # When we send drafts, we don't update anything in the app until
    # it actually succeeds. We don't want users to think messages have
    # already sent when they haven't!
    if not @draftClientId
      return Promise.reject(new Error("Attempt to call SendDraftTask.performLocal without @draftClientId."))

    return DatabaseStore.findBy(Message, clientId: @draftClientId).include(Message.attributes.body).then (draft) =>
      console.log("Have 'Updated Draft'", _.clone(draft.body), Date.now())
      if not draft
        return Promise.reject(new Error("We couldn't find draft #{@draftClientId} in the database."))
      @draft = draft
      @draftServerId = draft.serverId
      return

  performRemote: ->
    @_makeSendRequest()
    .then(@_saveNewMessage)
    .then(@_deleteRemoteDraft)
    .then(@_notifySuccess)
    .catch(@_onError)

  _makeSendRequest: =>
    console.log("---> Sending", _.clone(@draft.body), Date.now())
    NylasAPI.makeRequest
      path: "/send"
      accountId: @draft.accountId
      method: 'POST'
      body: @draft.toJSON()
      timeout: 1000 * 60 * 5 # We cannot hang up a send - won't know if it sent
      returnsModel: false
    .catch (err) =>
      # If the message you're "replying to" were deleted
      if err.message?.indexOf('Invalid message public id') is 0
        @draft.reply_to_message_id = null
        return @_makeSendRequest()
      else if err.message?.indexOf('Invalid thread') is 0
        @draft.thread_id = null
        @draft.reply_to_message_id = null
        return @_makeSendRequest()
      else return Promise.reject(err)

  # The JSON returned from the server will be the new Message.
  #
  # Our old draft may or may not have a serverId. We update the draft with
  # whatever the server returned (which includes a serverId).
  #
  # We then save the model again (keyed by its clientId) to indicate that
  # it is no longer a draft, but rather a Message (draft: false) with a
  # valid serverId.
  _saveNewMessage: (newMessageJSON) =>
    @draft = @draft.clone().fromJSON(newMessageJSON)
    @draft.draft = false
    DatabaseStore.persistModel(@draft)

  _deleteRemoteDraft: =>
    return Promise.resolve() unless @draftServerId
    NylasAPI.makeRequest
      path: "/drafts/#{@draftServerId}"
      accountId: @draft.accountId
      method: "DELETE"
      returnsModel: false
    .catch APIError, (err) =>
      # If the draft failed to delete remotely, we don't really care. It
      # shouldn't stop the send draft task from continuing.
      console.error("Deleting the draft remotely failed", err)

  _notifySuccess: =>
    if NylasEnv.config.get("core.sending.sounds")
      SoundRegistry.playSound('send')
    Actions.sendDraftSuccess
      draftClientId: @draftClientId
      newMessage: @draft
    return Task.Status.Success

  _onError: (err) =>
    msg = "Your message could not be sent at this time. Please try again soon."
    if not err instanceof APIError
      NylasEnv.emitError(err)
      return @_permanentError(err, msg)
    else if err.statusCode is 500
      return @_permanentError(err, msg)
    else if err.statusCode in [400, 404]
      NylasEnv.emitError(new Error("Sending a message responded with #{err.statusCode}!"))
      return @_permanentError(err, msg)
    else if err.statusCode is NylasAPI.TimeoutErrorCode
      msg = "We lost internet connection just as we were trying to send your message! Please wait a little bit to see if it went through. If not, check your internet connection and try sending again."
      return @_permanentError(err, msg)
    else
      return Promise.resolve(Task.Status.Retry)

  _permanentError: (err, msg) =>
    @_notifyUserOfError(msg)

    return Promise.resolve([Task.Status.Failed, err])

  _notifyUserOfError: (msg) =>
    if @fromPopout
      Actions.composePopoutDraft(@draftClientId, {errorMessage: msg})
    else
      Actions.draftSendingFailed({draftClientId: @draftClientId, errorMessage: msg})
