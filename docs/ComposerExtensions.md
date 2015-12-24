---
Title:   Extending the Composer
Section: Guides
Order:   6
---

The composer lies at the heart of N1, and many improvements to the mail experience require deep integration with the composer. To enable these sort of plugins, the {DraftStore} exposes an extension API.

This API allows your package to:

- Display warning messages before a draft is sent. (ie: "Are you sure you want to send this without attaching a file?")

- Intercept keyboard and mouse events to the composer's text editor.

- Transform the draft and make additional changes before it is sent.

To create your own composer extensions, subclass {ComposerExtension} and override the methods your extension needs.

In the sample packages repository, [templates]() is an example of a package which uses a ComposerExtension to enhance the composer experience.

### Example

This extension displays a warning before sending a draft that contains the names of competitors' products. If the user proceeds to send the draft containing the words, it appends a disclaimer.

```coffee
{ComposerExtension} = require 'nylas-exports'

class ProductsExtension extends ComposerExtension

   @warningsForSending: (draft) ->
      words = ['acme', 'anvil', 'tunnel', 'rocket', 'dynamite']
      body = draft.body.toLowercase()
      for word in words
        if body.indexOf(word) > 0
        	return ["with the word '#{word}'?"]
	  return []

   @finalizeSessionBeforeSending: (session) ->
      draft = session.draft()
      if @warningsForSending(draft)
         bodyWithWarning = draft.body += "<br>This email \
         	contains competitor's product names \
        	or trademarks used in context."
         return session.changes.add(body: bodyWithWarning)
      else return Promise.resolve()
```
