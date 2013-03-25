# Copyright 2012 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

root = exports ? this

# Singleton class for the client library. See the README file for usage
# examples. The singleton instance is accessed using the {.instance} method.
#
class root.SquashJavascript
  _instance = undefined

  # @return [_SquashJavascript] The singleton instance.
  #
  @instance: -> _instance ?= new _SquashJavascript()

# See {root.SquashJavascript}.
#
class _SquashJavascript
  # @private
  constructor: ->
    TraceKit.report.subscribe (info, error) -> SquashJavascript.instance().report(info, error)

  # Sets configuration options. See the README file for a list of accepted
  # configuration options. Multiple calls will merge new options in.
  #
  # @param [Object] options New options to apply.
  #
  configure: (options) ->
    @options ||= {
        disabled: false
        notifyPath: '/api/1.0/notify'
        transmitTimeout: 15000
        ignoredExceptionClasses: []
        ignoredExceptionMessages: {}
    }
    for own key, value of options
      @options[key] = value

  # Notify Squash of an error. The client must be configured first. The error
  # must have a valid stack trace (i.e., it must have been thrown). Does not
  # re-throw the error; that's your responsibility.
  #
  # You shouldn't normally need to call this method. Squash automatically
  # installs a listener that notifies the server for thrown exceptions.
  #
  # @param [Error] error The error to record.
  # @param [Object] user_data Additional user data to send up with the error.
  #
  notify: (error, user_data) ->
    if error instanceof Error
      error._squash_user_data = user_data
      TraceKit.report(error)
    else
      throw error

  # @private
  report: (info, error) ->
    try
      return false if @options?.disabled
      if !@options?.APIKey || !@options?.environment ||
          !@options?.revision || !@options?.APIHost
        console.error "Missing required Squash configuration keys"
        return false

      return false if this.shouldIgnoreError(info)
      return false unless info.stack

      fields = new Object()
      fields.api_key = @options.APIKey
      fields.environment = @options.environment
      fields.client = "javascript"
      fields.revision = @options.revision

      fields.class_name = info.type ? info.name
      # errors that make it up to window.onerror get stupidly rewritten: their
      # class is set to "Error" and the ACTUAL class is integrated into the
      # message (e.g., "Uncaught TypeError: [message]")
      if !info.name && (matches = info.message.match(/^(Uncaught )?(\w+): (.+)/))
        fields.class_name = matches[2]
        fields.message = matches[3]
      else
        fields.message = info.message
      fields.class_name ?= 'Error' # when all else fails

      fields.backtraces = buildBacktrace(info.stack)
      fields.capture_method = info.mode
      fields.occurred_at = ISODateString(new Date())

      fields.schema = window.location.protocol.replace(/:$/, '')
      fields.host = window.location.hostname
      fields.port = window.location.port if window.location.port.length > 0
      fields.path = window.location.pathname
      fields.query = window.location.search
      fields.fragment = window.location.hash if window.location.hash != ''

      fields.user_agent = navigator.userAgent

      fields.screen_width = screen.width
      fields.screen_height = screen.height
      fields.window_width = window.innerWidth
      fields.window_height = window.innerHeight
      fields.color_depth = screen.colorDepth

      if error
        (fields[k] = v for own k, v of error._squash_user_data)

      body = JSON.stringify(fields)
      this.HTTPTransmit (@options.APIHost + @options.notifyPath),
          [ ['Content-Type', 'application/json'] ],
          body

      return true
    catch internal_error
      console.error "Error while trying to notify Squash:", internal_error.stack
      console.error "-- original error:", info

  # Runs the given `block`. If an exception is thrown within the function, adds
  # the given user data to the exception and re-throws it.
  #
  # @param [Object] data The user data to add to any error.
  # @param [function] block The code to run.
  # @return [Object] The return value of `block`.
  # @see #addingUserData
  #
  addUserData: (data, block) ->
    try
      block()
    catch err
      err._squash_user_data ?= {}
      mergeBang err._squash_user_data, data
      throw err

  # Wraps `block` in a call to {#addUserData} and returns it. Any arguments are
  # passed through.
  #
  # @see #addUserData
  #
  addingUserData: (data, block) ->
    (args...) -> SquashJavascript.instance().addUserData(data, -> block(args...))

  # Runs the given `block`. If an exception is thrown within the function of one
  # of the types given, does not report the exception to Squash. Re-throws _all_
  # exceptions.
  #
  # @param [class..., String...] exceptions A list of error types to ignore.
  # @param [function] block The code to run.
  # @return [Object] The return value of `block`.
  # @see #ignoringExceptions
  #
  ignoreExceptions: (exceptions..., block) ->
    try
      block()
    catch err
      err._squash_ignored_exceptions = (err._squash_ignored_exceptions || []).concat(exceptions)
      throw err

  # Wraps `block` in a call to {#ignoreExceptions} and returns it. Any arguments
  # are passed through.
  #
  # @see #ignoreExceptions
  #
  ignoringExceptions: (exceptions..., block) ->
    (args...) -> SquashJavascript.instance().ignoreExceptions(exceptions..., -> block(args...))

  ################################## PRIVATES ##################################

  # @private
  HTTPTransmit: (url, headers, body) ->
    request = new XMLHttpRequest()
    request.timeout = @options.transmitTimeout
    request.open "POST", url, true
    for header in headers
      request.setRequestHeader header[0], header[1]
    request.send body
    request

  # @private
  shouldIgnoreError: (error) ->
    ignored_classes = @options.ignoredExceptionClasses.concat(error._squash_ignored_exceptions || [])

    return true if any(ignored_classes, (klass) -> error.name == klass)

    return any(@options.ignoredExceptionMessages, (class_name, messages) ->
      if error.name == class_name
        return any(messages, (message) -> error.message.match(message))
      else
        return false
    )

  buildBacktrace = (stack) ->
    backtraces = []
    for line in stack
      context = line.context
      context = null if context && any(context, (cline) -> cline.length > 200)
      backtraces.push {url: line.url, line: line.line, column: line.column, symbol: line.func, context: context, type: 'minified'}
    return [ {name: "Active Thread", faulted: true, backtrace: backtraces} ]

  ISODateString = (d) ->
    pad = (n) -> if n < 10 then '0' + n else n
    "#{d.getUTCFullYear()}-#{pad(d.getUTCMonth() + 1)}-#{pad d.getUTCDate()}T#{pad d.getUTCHours()}:#{pad d.getUTCMinutes()}:#{pad d.getUTCSeconds()}Z"

  any = (obj, condition) ->
    if obj instanceof Array
      for element in obj
        return true if condition(element)
    else
      for own key, value of obj
        return true if condition(key, value)
    return false

  mergeBang = (modified, constant) ->
    for own key, value of constant
      modified[key] = value
