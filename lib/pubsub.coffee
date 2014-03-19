"use strict"

_ = require("underscore")
Backbone = require ("backbone")

events = _.extend {}, Backbone.Events

module.exports = exports =
  sub: (msg, callback, context) ->
    events.on msg, callback, context

  unsub: (msg, callback, context) ->
    events.off msg, callback, context

  pub: (msg, args...) ->
    events.trigger msg, args...
