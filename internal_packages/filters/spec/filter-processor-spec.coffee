_ = require 'underscore'
{Message,
 Contact,
 File,
 TaskQueueStatusStore,
 Actions} = require 'nylas-exports'

FilterProcessor = require '../lib/filter-processor'

Tests = [{
  filter: {
    id: "local-ac7f1671-ba03",
    name: "RuleMode Any, contains, equals",
    rules: [
      {
        templateKey: "from"
        comparatorKey: "contains"
        value: "@nylas.com"
      },
      {
        templateKey: "from"
        comparatorKey: "equals"
        value: "oldschool@nilas.com"
      }
    ],
    ruleMode: "any",
    actions: [
      {
        templateKey: "markAsRead"
      }
    ],
    accountId: "b5djvgcuhj6i3x8nm53d0vnjm"
  },
  good: [
    new Message(from: [new Contact(email:'ben@nylas.com')])
    new Message(from: [new Contact(email:'ben@nylas.com.jp')])
    new Message(from: [new Contact(email:'oldschool@nilas.com')])
  ]
  bad: [
    new Message(from: [new Contact(email:'ben@other.com')])
    new Message(from: [new Contact(email:'ben@nilas.com')])
    new Message(from: [new Contact(email:'twooldschool@nilas.com')])
  ]
},{
  filter: {
    id: "local-ac7f1671-ba03",
    name: "RuleMode all, ends with, begins with",
    rules: [
      {
        templateKey: "cc"
        comparatorKey: "endsWith"
        value: ".com"
      },
      {
        templateKey: "subject"
        comparatorKey: "beginsWith"
        value: "[TEST] "
      }
    ],
    ruleMode: "any",
    actions: [
      {
        templateKey: "applyLabel"
        value: "51a0hb8d6l78mmhy19ffx4txs"
      }
    ],
    accountId: "b5djvgcuhj6i3x8nm53d0vnjm"
  },
  good: [
    new Message(cc: [new Contact(email:'ben@nylas.org')], subject: '[TEST] ABCD')
    new Message(cc: [new Contact(email:'ben@nylas.org')], subject: '[test] ABCD')
    new Message(cc: [new Contact(email:'ben@nylas.com')], subject: 'Whatever')
    new Message(cc: [new Contact(email:'a@test.com')], subject: 'Whatever')
    new Message(cc: [new Contact(email:'a@hasacom.com')], subject: '[test] Whatever')
    new Message(cc: [new Contact(email:'a@hasacom.org'), new Contact(email:'b@nylas.com')], subject: 'Whatever')
  ]
  bad: [
    new Message(cc: [new Contact(email:'a@hasacom.org')], subject: 'Whatever')
    new Message(cc: [new Contact(email:'a@hasacom.org')], subject: '[test]Whatever')
    new Message(cc: [new Contact(email:'a.com@hasacom.org')], subject: 'Whatever [test] ')
  ]
},{
  filter: {
    id: "local-ac7f1671-ba03",
    name: "Any attachment name endsWith, anyRecipient equals",
    rules: [
      {
        templateKey: "anyAttachmentName"
        comparatorKey: "endsWith"
        value: ".pdf"
      },
      {
        templateKey: "anyRecipient"
        comparatorKey: "equals"
        value: "files@nylas.com"
      }
    ],
    ruleMode: "any",
    actions: [
      {
        templateKey: "changeFolder"
        value: "51a0hb8d6l78mmhy19ffx4txs"
      }
    ],
    accountId: "b5djvgcuhj6i3x8nm53d0vnjm"
  },
  good: [
    new Message(files: [new File(filename: 'bengotow.pdf')], to: [new Contact(email:'ben@nylas.org')])
    new Message(to: [new Contact(email:'files@nylas.com')])
    new Message(to: [new Contact(email:'ben@nylas.com')], cc: [new Contact(email:'ben@test.com'), new Contact(email:'files@nylas.com')])
  ],
  bad: [
    new Message(to: [new Contact(email:'ben@nylas.org')])
    new Message(files: [new File(filename: 'bengotow.pdfz')], to: [new Contact(email:'ben@nylas.org')])
    new Message(files: [new File(filename: 'bengotowpdf')], to: [new Contact(email:'ben@nylas.org')])
    new Message(to: [new Contact(email:'afiles@nylas.com')])
    new Message(to: [new Contact(email:'files@nylas.coma')])
  ]
}]

describe "FilterProcessor", ->
  beforeEach ->
    @processor = new FilterProcessor()

  describe "_checkFilterForMessage", ->
    it "should correctly filter sample messages", ->
      Tests.forEach ({filter, good, bad}) =>
        for message, idx in good
          message.accountId = filter.accountId
          if @processor._checkFilterForMessage(filter, message) isnt true
            expect("#{idx} (#{filter.name})").toBe(true)
        for message, idx in bad
          message.accountId = filter.accountId
          if @processor._checkFilterForMessage(filter, message) isnt false
            expect("#{idx} (#{filter.name})").toBe(false)

    it "should check the account id", ->
      {filter, good, bad} = Tests[0]
      message = good[0]
      message.accountId = 'not the same!'
      expect(@processor._checkFilterForMessage(filter, message)).toBe(false)

  describe "_applyFilterToMessage", ->
    it "should queue tasks for messages", ->
      spyOn(TaskQueueStatusStore, 'waitForPerformLocal')
      spyOn(Actions, 'queueTask')

      Tests.forEach ({filter}) =>
        TaskQueueStatusStore.waitForPerformLocal.reset()
        Actions.queueTask.reset()

        messageSpy = jasmine.createSpy('message')
        threadSpy = jasmine.createSpy('thread')
        response = @processor._applyFilterToMessage(filter, messageSpy, threadSpy)

        expect(TaskQueueStatusStore.waitForPerformLocal).toHaveBeenCalled()
        expect(response instanceof Promise).toBe(true)
        expect(Actions.queueTask).toHaveBeenCalled()
