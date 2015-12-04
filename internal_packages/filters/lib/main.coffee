# # Filters
#
# A way to apply filters, AKA mail rules, to incoming mail.

# Requiring 'nylas-exports' is the way to access core N1 components.
{PreferencesUIStore} = require 'nylas-exports'

# Your main.coffee (or main.cjsx) file needs to export an object for your
# package to run.
module.exports =
  # When your package is loading, the `activate` method runs. `activate` is the
  # package's time to insert React components into the application and also
  # listen to events.
  activate: ->
    tab = new PreferencesUIStore.TabItem
      tabId: 'Mail Rules'
      displayName: 'Mail Rules'
      component: require './filter-list'
      componentRequiresAccount: true
      order: 4
    PreferencesUIStore.registerPreferencesTab(tab)

  # `deactivate` is called when packages are closing. It's a good time to
  # unregister React components.
  deactivate: ->
    PreferencesUIStore.unregisterPreferencesTab('Mail Rules')
