_ = require 'underscore'
Filter = require '../lib/filter'
{Message, Contact, File} = require 'nylas-exports'

Tests = [{
  filter: new Filter({
    id: "local-ac7f1671-ba03",
    name: "RuleMode Any, contains, equals",
    rules: [
      {
        key: "from"
        valueComparator: "contains"
        value: "@nylas.com"
      },
      {
        key: "from"
        value: "oldschool@nilas.com"
        valueComparator: "equals"
      }
    ],
    ruleMode: "any",
    actions: [
      {
        key: "applyCategory"
        value: "51a0hb8d6l78mmhy19ffx4txs"
      }
    ],
    accountId: "b5djvgcuhj6i3x8nm53d0vnjm"
  }),
  good: [
    new Message(from: [new Contact(email:'ben@nylas.com')])
    new Message(from: [new Contact(email:'oldschool@nilas.com')])
    new Message(from: [new Contact(email:'ben@other.com')])
  ]
  bad: [
    new Message(from: [new Contact(email:'ben@other.com')])
    new Message(from: [new Contact(email:'ben@nilas.com')])
    new Message(from: [new Contact(email:'twooldschool@nilas.com')])
  ]
},{
  filter: new Filter({
    id: "local-ac7f1671-ba03",
    name: "RuleMode all, ends with, begins with",
    rules: [
      {
        key: "cc"
        valueComparator: "endsWith"
        value: ".com"
      },
      {
        key: "subject"
        value: "[TEST] "
        valueComparator: "beginsWith"
      }
    ],
    ruleMode: "any",
    actions: [
      {
        key: "applyCategory"
        value: "51a0hb8d6l78mmhy19ffx4txs"
      }
    ],
    accountId: "b5djvgcuhj6i3x8nm53d0vnjm"
  }),
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
  filter: new Filter({
    id: "local-ac7f1671-ba03",
    name: "All attachment name endsWith, anyRecipient equals",
    rules: [
      {
        key: "anyAttachmentName"
        valueComparator: "endsWith"
        value: ".pdf"
      },
      {
        key: "anyRecipient"
        value: "files@nylas.com"
        valueComparator: "equals"
      }
    ],
    ruleMode: "all",
    actions: [
      {
        key: "applyCategory"
        value: "51a0hb8d6l78mmhy19ffx4txs"
      }
    ],
    accountId: "b5djvgcuhj6i3x8nm53d0vnjm"
  }),
  good: [
    new Message(files: new File(filename: 'bengotow.pdf'), to: [new Contact(email:'ben@nylas.org')])
    new Message(to: [new Contact(email:'files@nylas.com')])
    new Message(to: [new Contact(email:'ben@nylas.com')], cc: [new Contact(email:'ben@test.com'),new Contact(email:'files@nylas.com')])
  ],
  bad: [
    new Message(to: [new Contact(email:'ben@nylas.org')])
    new Message(files: new File(filename: 'bengotow.pdfz'), to: [new Contact(email:'ben@nylas.org')])
    new Message(files: new File(filename: 'bengotowpdf'), to: [new Contact(email:'ben@nylas.org')])
    new Message(to: [new Contact(email:'afiles@nylas.com')])
    new Message(to: [new Contact(email:'files@nylas.coma')])
  ]
}]

fdescribe "filter execution", ->
  Tests.forEach ({filter, good, bad}) ->
    it "should correctly filter messages (#{filter.name})", ->
      expect(filter.matches(msg)).toBe(true) for msg in good
      expect(filter.matches(msg)).toBe(false) for msg in bad
