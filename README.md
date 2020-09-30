Client Library: JavaScript 
=================================

This client library reports front-end JavaScript exceptions to Squash, the
Squarish exception reporting and management system.

Documentation
-------------

For an overview of the various components of Squash, see the website
documentation at https://github.com/SquareSquash/web.

### JavaScript client

Documentation is written in Codo format. HTML documentation can be generated by
running `rake doc:js`. Note that Codo is still a work in progress, and the
generated docs will have some formatting errors. The documentation is written to
the `doc/js` directory.

If you do not have Codo installed in your path, you can download a project-local
install with `rake setup`.

### Ruby library

Markdown-formatted YARD documentation is available by running `rake doc:ruby`.
The documentation is written to the `doc/ruby` directory.

Compatibility
-------------

The JavaScript library is compatible with any modern JavaScript engine,
including any version of V8, Nitro, and Chakra.

The Rails engine (allowing the library to be easily used in a Rails app) is
compatible with Rails 3.1 and later.

Requirements
------------

The JavaScript library uses TraceKit for cross-platform stack trace extraction.
The library is included in this project. For Rails projects, a Sprockets include
file is provided. For non-Rails projects, the output of `rake minify` rolls in
the library.

**The included version of TraceKit has been modified somewhat:**

* `window.onerror` support was expanded to include changes in recent versions of
  modern browsers (namely, passing the column and error object as parameters).
* TraceKit was causing unexpected behavior on Chrome and Firefox, and parts of
  it are commented out. (The jQuery hooks were disabled.)

Installation
------------

### Rails

For Rails applications, add the Squash client engine to your Gemfile with
`gem 'squash_javascript', require: 'squash/javascript'`, and then include the
JavaScript into your application.js file (or other JavaScript manifest):

```` javascript
//= require squash_javascript
````

### Other projects of javascript

For other projects, you may need to compile the CoffeeScript file first. If you
do not have the `coffee` binary installed in your path, you can download and
install a copy of CoffeeScript by running `rake setup`. This task uses npm (the
Node package manager) to perform the installation; you will need to install npm
first if you haven't already.  CoffeeScript will be installed into a
project-local directory.

Once you have the `coffee` binary, you can run `rake minify` to generate a
JavaScript file that you can use in your project. If you would like a
non-minified JavaScript file without dependencies, run `rake compile`.

Place the compiled `squash_javascript.min.js` file in a Web-public directory and
include it using a `<script>` tag:

```` html
<script type="text/javascript" href="http://url.to.your/squash_javascript.min.js" />
````

The file defines a `SquashJavascript` singleton which is accessible using
`SquashJavascript.instance()`.

### Configuring CORS

In order for applications to report their JavaScript errors to Squash, your
Squash instance must be configured to accept cross-origin requests from your
other website. In your Squash web code, update the `allowed_origins`
configuration (under `config/environments/[environment]/dogfood.yml`) to include
the host serving your application.

Usage
-----

Before you can use Squash, you must configure it (see **Configuration** below).
At a minimum, you must specify

* the host on which Squash is running,
* your project's API key,
* the environment, and
* the SHA of the Git revision currently deployed.

Use `SquashJavascript.instance().configure` to set up the Squash JavaScript client:

```` javascript
SquashJavascript.instance().configure({APIHost: 'YOUR_API_HOST',
                                   APIKey: 'YOUR_API_KEY',
                                   environment: 'production',
                                   revision: '8718e4336990f9ea0198c2ff5668bbb673befd65'})
````

Squash will automatically install a listener that will trap exceptions, send
them to the server, and re-throw them. Note that the client will only notify for
instances of the `Error` class.

There are many additional features you can take advantage of; see **Additional
Features** below.

### Additional Features

There are a number of other features you can take advantage of to help you debug
your exceptions:

#### User Data

Exceptions can be annotated with freeform user data. This data can take any
format and have any meaning, typically being relevant to the exception at hand.

There are multiple ways to add user data to an exception. The most
straightforward way is to include the user data as the second argument to the
`notify` method:

```` javascript
SquashJavascript.instance().notify(error, {event: e, arguments: arguments});
````

You can apply user data to a block of code using the
`SquashJavascript.instance().addUserData` method:

```` javascript
$(window).resize(function(e) {
  SquashJavascript.instance().addUserData({event: e}, function() {
    // ... process event ...
  });
});
````

If that's too verbose, there's additionally a curry function, `addingUserData`,
that takes a function, applies the `addUserData` behavior to it, and returns a
new function:

```` javascript
$(window).resize(SquashJavascript.instance().addingUserData({event: e}, function(e) {
  // ... process event ...
});
````

And lastly, you can add user data directly to the exception:

```` javascript
function myFunction(value) {
  if (value < 0) {
    var err = new Error("value was less than 0");
    err._squash_user_data = { value: value };
    throw err;
  }

  // ... do the thing ...
}
````

You can also add user data to exceptions you catch and re-throw:

```` javascript
try {
  doSomethingWithInput(input);
} catch (err) {
  if (!err._squash_user_data) err._squash_user_data = new Object();
  err._squash_user_data.input = input;
  throw err; // assumed that SquashJavascript.instance().notify is called somewhere further up in the stack
}
````

#### Ignoring Exceptions

You can ignore certain error classes within a block of code if those exceptions
are not worth sending to Squash. Use the
`SquashJavascript.instance().ignore_exceptions` method:

```` javascript
SquashJavascript.instance().ignoreExceptions(EvalError, SyntaxError, function() {
  // ... some code ...
});
````

The curry-type syntax is also supported here:

```` javascript
$(window).resize(SquashJavascript.instance().ignoringExceptions(EvalError, SyntaxError, function(e) {
  /// ... some code ...
});
````

The exceptions _will_ be raised (not eaten) but will _not_ be reported to
Squash.

You can also globally ignore exceptions using the `ignored_exceptions`
configuration; see **Configuration** below.

Configuration
-------------

You can configure the client with the `SquashJavascript.instance().configure`
method. Calling this method multiple times will merge new values in with the
existing configuration. The method takes a hash, which accepts the following
keys:

### General

* `disabled`: If `true`, the Squash client will not report any errors.
* `APIKey`: The API key of the project that exceptions will be associated with.
  This configuration option is required. The value can be found by going to the
  project's home page on Squash.
* `environment`: The environment that exceptions will be associated with. This
  configuration option is required.
* `revision`: The SHA1 of the current Git revision. This is the revision of the
  code that is currently running. This configuration option is required.

### Error Transmission

* `APIHost`: The host on which Squash is running. Required.
* `notifyPath`: The path to post new exception notifications to. By default
  it's set to `/api/1.0/notify`.
* `transmitTimeout`: The amount of time to wait before giving up on trasmitting
  an error. By default this is treated as both an open and a read timeout.

### Ignored Exceptions

* `ignoredExceptionClasses`: An array of exception class names that will not
  be reported to Squash.
* `ignoredExceptionMessages`: A hash mapping an exception class name to an
  array of regexes. Exceptions of that class whose messages match a regex in the
  list will not be reported to Squash.

Error Transmission
------------------

Exceptions are transmitted to Squash using JSON-over-XMLHttpRequest. A default
API endpoint is pre-configured, though you can always set your own (see
**Configuration** above).

Failsafe Reporting
------------------

In the event that the Squash client itself raises an exception when processing
an exception, it will log that exception to the console. Both the original
exception and the failsafe error will be logged. The original exception will
still be re-raised, but the failsafe error will be "eaten."

Source Mapping
--------------

### Rails and Sprockets

Squash JavaScript can integrate with Sprockets to automatically generate source
maps for each stage of the asset compilation pipeline, then integrate with
Capistrano to upload the source maps to Squash. To use this feature, configure
your project like so:

1. Replace your JavaScript compiler gem with Closure, if you aren't already
   using it.

   ```` diff
   -gem 'uglifier'
   +gem 'closure-compiler'
   ````

2. Use Squash's source-mapping Tilt engines for CoffeeScript and JavaScript.

   These Tilt engines wrap existing Tilt template engines, but also generate
   source maps to `tmp/sourcemaps`.

   ```` ruby
   Sprockets.register_engine '.coffee', Squash::Javascript::SourceMappingCoffeescriptTemplate
   config.assets.js_compressor = Squash::Javascript::SourceMappingJavascriptMinifier
   ````

3. Add the Squash Capistrano tasks to your Capfile:

    ```` ruby
    require 'squash/javascript/capistrano'
    ````

    If you do not use Capistrano 3, you can use the `rake sourcemaps:upload:all`
    task to upload your generated source maps to Squash.

### Other Projects

If you can generate a source map for your minified JavaScript files (Closure
can), you can use this gem to upload that source map to Squash, where it will
be used to convert minified stack traces to their original format, which can
then benefit from Git-blaming, context, and other features of Squash.

To upload the source map to squash, run the `upload_source_map` binary included
with this gem, and pass it four arguments: 1) your Squash host, 2) your API key,
3) the environment name, and 4) the path to the JSON source map. Example:

````
upload_source_map http://your.squash.host abc-123-abc-123-abc-123 production artifacts/mapping.json
````

Use `--help` to learn about additional options.

Specs
-----

### JavaScript client

Jasmine unit and integration tests are implemented in the `spec/js` directory.
To run these tests, run `rake spec:js` (Mac OS X required), or simply compile
the CoffeeScript source and open the `SpecRunner.html` file in your favorite Web
browser.

### Ruby library

RSpec unit tests are implemented in the `spec/ruby` directory. To run these
tests, run `rake spec:ruby`.
