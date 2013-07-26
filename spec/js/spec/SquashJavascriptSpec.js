// Copyright 2013 Square Inc.
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

var makeError = function(klass, message) {
  if (!klass) klass = Error;
  try {
    throw new klass(message || "error");
  } catch (err) { return err; }
};

describe("SquashJavascript", function() {
  beforeEach(function() {
    jasmine.Clock.useMock();
    SquashJavascript.instance().options = null;
  });

  describe("#configure", function() {
    it("should use default values", function() {
      SquashJavascript.instance().configure({});
      expect(SquashJavascript.instance().options.disabled).toBe(false);
      expect(SquashJavascript.instance().options.notifyPath).toBe('/api/1.0/notify');
      expect(SquashJavascript.instance().options.transmitTimeout).toBe(15000);
      expect(SquashJavascript.instance().options.ignoredExceptionClasses).toEqual([]);
      expect(SquashJavascript.instance().options.ignoredExceptionMessages).toEqual({});
    });

    it("should set new values", function() {
      SquashJavascript.instance().configure({transmitTimeout: 10000});
      expect(SquashJavascript.instance().options.transmitTimeout).toBe(10000);
    });

    it("should overwrite existing values when called twice", function() {
      SquashJavascript.instance().configure({transmitTimeout: 12000, disabled: true});
      SquashJavascript.instance().configure({transmitTimeout: 13000, disabled: false});
      expect(SquashJavascript.instance().options.transmitTimeout).toBe(13000);
      expect(SquashJavascript.instance().options.disabled).toBe(false);
    });
  });

  describe("#notify", function() {
    it("should not notify if disabled", function() {
      SquashJavascript.instance().configure({disabled: true});

      spyOn(SquashJavascript.instance(), 'HTTPTransmit');
      expect(function() { SquashJavascript.instance().notify(new Error()); }).toThrow();
      expect(SquashJavascript.instance().HTTPTransmit).not.toHaveBeenCalled();
    });

    describe("[configuration checks]", function() {
      beforeEach(function() {
        spyOn(SquashJavascript.instance(), 'HTTPTransmit');
      });

      it("should throw an error if APIKey is not set", function() {
        SquashJavascript.instance().configure({environment: 'development', revision: 'abc123', APIHost: 'http://test.host'});
        expect(function() { SquashJavascript.instance().notify(new Error()); }).toThrow();
        jasmine.Clock.tick(2001);
        expect(SquashJavascript.instance().HTTPTransmit).not.toHaveBeenCalled();
      });

      it("should throw an error if environment is not set", function() {
        SquashJavascript.instance().configure({APIKey: 'abc-123', revision: 'abc123', APIHost: 'http://test.host'});
        expect(function() { SquashJavascript.instance().notify(new Error()); }).toThrow();
        jasmine.Clock.tick(2001);
        expect(SquashJavascript.instance().HTTPTransmit).not.toHaveBeenCalled();
      });

      it("should throw an error if revision is not set", function() {
        SquashJavascript.instance().configure({APIKey: 'abc-123', environment: 'development', APIHost: 'http://test.host'});
        expect(function() { SquashJavascript.instance().notify(new Error()); }).toThrow();
        jasmine.Clock.tick(2001);
        expect(SquashJavascript.instance().HTTPTransmit).not.toHaveBeenCalled();
      });

      it("should throw an error if APIHost is not set", function() {
        SquashJavascript.instance().configure({APIKey: 'abc-123', environment: 'development', revision: 'abc123'});
        expect(function() { SquashJavascript.instance().notify(new Error()); }).toThrow();
        jasmine.Clock.tick(2001);
        expect(SquashJavascript.instance().HTTPTransmit).not.toHaveBeenCalled();
      });
    });

    describe("[user data]", function() {
      beforeEach(function() {
        SquashJavascript.instance().configure({
                                                APIKey:      'abc-123',
                                                environment: 'development',
                                                revision:    'abc123',
                                                APIHost:     'http://test.host'
                                              });
      });

      it("should send up user data associated with the exception", function() {
        var spy = spyOn(SquashJavascript.instance(), 'HTTPTransmit');
        expect(function() { SquashJavascript.instance().notify(makeError(), {foo: 'bar'}); }).toThrow();
        jasmine.Clock.tick(2001);
        expect(SquashJavascript.instance().HTTPTransmit).toHaveBeenCalled();
        expect(JSON.parse(spy.mostRecentCall.args[2]).foo).toBe("bar");
      });

      it("should allow user data to override other fields", function() {
        var spy = spyOn(SquashJavascript.instance(), 'HTTPTransmit');
        expect(function() { SquashJavascript.instance().notify(makeError(), {screen_width: 12345}); }).toThrow();
        jasmine.Clock.tick(2001);
        expect(SquashJavascript.instance().HTTPTransmit).toHaveBeenCalled();
        expect(JSON.parse(spy.mostRecentCall.args[2]).screen_width).toBe(12345);
      });
    });

    describe("[ignored errors]", function() {
      beforeEach(function() {
        SquashJavascript.instance().configure({
                                                APIKey:      'abc-123',
                                                environment: 'development',
                                                revision:    'abc123',
                                                APIHost:     'http://test.host'
                                              });
      });

      it("should not notify for objects other than Errors", function() {
        spyOn(SquashJavascript.instance(), 'HTTPTransmit');

        expect(function() { SquashJavascript.instance().notify("hello"); }).toThrow();
        jasmine.Clock.tick(2001);
        expect(SquashJavascript.instance().HTTPTransmit).not.toHaveBeenCalled();
      });

      it("should not notify for ignored exception classes", function() {
        var spy = spyOn(SquashJavascript.instance(), 'HTTPTransmit');

        SquashJavascript.instance().configure({ignoredExceptionClasses: ['SyntaxError', 'TypeError']});
        expect(function() { SquashJavascript.instance().notify(makeError()); }).toThrow();
        jasmine.Clock.tick(2001);
        expect(function() { SquashJavascript.instance().notify(makeError(SyntaxError)); }).toThrow();
        jasmine.Clock.tick(2001);
        expect(function() { SquashJavascript.instance().notify(makeError(TypeError)); }).toThrow();
        jasmine.Clock.tick(2001);

        expect(SquashJavascript.instance().HTTPTransmit).toHaveBeenCalled();
        expect(spy.callCount).toBe(1); //TODO not a perfect test
      });

      it("should not notify for ignored exception messages", function() {
        var spy = spyOn(SquashJavascript.instance(), 'HTTPTransmit');

        SquashJavascript.instance().configure({ignoredExceptionMessages: {
          SyntaxError: [/foo/]
        }});
        expect(function() { SquashJavascript.instance().notify(makeError()); }).toThrow();
        jasmine.Clock.tick(2001);
        expect(function() { SquashJavascript.instance().notify(makeError(SyntaxError, "foo")); }).toThrow();
        jasmine.Clock.tick(2001);
        expect(function() { SquashJavascript.instance().notify(makeError(SyntaxError, "bar")); }).toThrow();
        jasmine.Clock.tick(2001);

        expect(SquashJavascript.instance().HTTPTransmit).toHaveBeenCalled();
        expect(spy.callCount).toBe(2); //TODO not a perfect test
      });
    });

    describe("[XHR]", function() {
      beforeEach(function() {
        SquashJavascript.instance().configure({
                                                APIKey:      'abc-123',
                                                environment: 'development',
                                                revision:    'abc123',
                                                APIHost:     'http://test.host',
                                                notifyPath:  '/notify'
                                              });
      });

      it("should use the correct URL and method", function() {
        spyOn(SquashJavascript.instance(), 'HTTPTransmit');
        expect(function() { SquashJavascript.instance().notify(makeError()); }).toThrow();
        jasmine.Clock.tick(2001);
        expect(SquashJavascript.instance().HTTPTransmit).toHaveBeenCalledWith('http://test.host/notify', jasmine.any(Array), jasmine.any(String));
      });

      it("should generate an appropriate JSON-formatted body", function() {
        var spy = spyOn(SquashJavascript.instance(), 'HTTPTransmit');
        var error = makeError(SyntaxError, "foobar'd");
        expect(function() { SquashJavascript.instance().notify(error); }).toThrow();
        jasmine.Clock.tick(2001);
        expect(SquashJavascript.instance().HTTPTransmit).toHaveBeenCalledWith(jasmine.any(String), jasmine.any(Array), jasmine.any(String));

        var json = JSON.parse(spy.mostRecentCall.args[2]);
        expect(json.api_key).toBe('abc-123');
        expect(json.environment).toBe('development');
        expect(json.client).toBe('javascript');
        //expect(json.backtraces).toEqual([]);
        expect(json.class_name).toBe('SyntaxError');
        expect(json.message).toBe("foobar'd");
        expect(json.revision).toBe('abc123');
        expect(json.occurred_at).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/);
      });

      it("should set the Content-Type header", function() {
        var spy = spyOn(SquashJavascript.instance(), 'HTTPTransmit');
        expect(function() { SquashJavascript.instance().notify(makeError()); }).toThrow();
        jasmine.Clock.tick(2001);
        expect(SquashJavascript.instance().HTTPTransmit).toHaveBeenCalledWith(jasmine.any(String), jasmine.any(Array), jasmine.any(String));
        expect(spy.mostRecentCall.args[1]).toContain(['Content-Type', 'application/json']);
      });

      it("should set the correct timeout", function() {
        SquashJavascript.instance().configure({transmitTimeout: 12000});
        var req = SquashJavascript.instance().HTTPTransmit("http://test.host", [], "");
        expect(req.timeout).toBe(12000);
      });
    });
  });

  describe("#addUserData", function() {
    beforeEach(function() {
      SquashJavascript.instance().configure({
                                              APIKey:      'abc-123',
                                              environment: 'development',
                                              revision:    'abc123',
                                              APIHost:     'http://test.host'
                                            });
    });

    it("should add user data to a raised error, and re-raise it", function() {
      var thrown = false;
      try {
        SquashJavascript.instance().addUserData({foo: 'bar'}, function() {
          throw makeError();
        });
      } catch (err) {
        expect(err._squash_user_data).toEqual({foo: 'bar'});
        thrown = true;
      }
      expect(thrown).toBe(true);
    });

    it("should merge user data when nested", function() {
      var thrown = false;
      try {
        SquashJavascript.instance().addUserData({foo: 'bar'}, function() {
          SquashJavascript.instance().addUserData({foo2: 'bar2'}, function() {
            throw makeError();
          });
        });
      } catch (err) {
        expect(err._squash_user_data).toEqual({foo: 'bar', foo2: 'bar2'});
        thrown = true;
      }
      expect(thrown).toBe(true);
    });
  });

  describe("#addingUserData", function() {
    beforeEach(function() {
      SquashJavascript.instance().configure({
                                              APIKey:      'abc-123',
                                              environment: 'development',
                                              revision:    'abc123',
                                              APIHost:     'http://test.host'
                                            });
    });

    it("should return a function that calls #addUserData", function() {
      var thrown = false;
      var called = false;
      try {
        SquashJavascript.instance().addingUserData({foo: 'bar'}, function(val) {
          called = val;
          throw makeError();
        })(true);
      } catch (err) {
        expect(err._squash_user_data).toEqual({foo: 'bar'});
        thrown = true;
      }
      expect(thrown).toBe(true);
      expect(called).toBe(true);
    });
  });

  describe("#ignoreExceptions", function() {
    beforeEach(function() {
      SquashJavascript.instance().configure({
                                              APIKey:      'abc-123',
                                              environment: 'development',
                                              revision:    'abc123',
                                              APIHost:     'http://test.host'
                                            });
    });

    it("should ignore given exception classes", function() {
      var thrown = false;
      try {
        SquashJavascript.instance().ignoreExceptions("SyntaxError", function() {
          throw makeError(SyntaxError);
        });
      } catch (err) {
        expect(SquashJavascript.instance().shouldIgnoreError(err)).toBe(true);
        thrown = true;
      }
      expect(thrown).toBe(true);

      thrown = false;
      try {
        SquashJavascript.instance().ignoreExceptions("SyntaxError", function() {
          throw makeError();
        });
      } catch (err) {
        expect(SquashJavascript.instance().shouldIgnoreError(err)).toBe(false);
        thrown = true;
      }
      expect(thrown).toBe(true);
    });

    it("should merge exception classes when nested", function() {
      var thrown = false;
      try {
        SquashJavascript.instance().ignoreExceptions("SyntaxError", function() {
          SquashJavascript.instance().ignoreExceptions("TypeError", function() {
            throw makeError(SyntaxError);
          });
        });
      } catch (err) {
        expect(SquashJavascript.instance().shouldIgnoreError(err)).toBe(true);
        thrown = true;
      }
      expect(thrown).toBe(true);

      thrown = false;
      try {
        SquashJavascript.instance().ignoreExceptions("SyntaxError", function() {
          SquashJavascript.instance().ignoreExceptions("TypeError", function() {
            throw makeError(TypeError);
          });
        });
      } catch (err) {
        expect(SquashJavascript.instance().shouldIgnoreError(err)).toBe(true);
        thrown = true;
      }
      expect(thrown).toBe(true);
    });
  });

  describe("#ignoringExceptions", function() {
    beforeEach(function() {
      SquashJavascript.instance().configure({
                                              APIKey:      'abc-123',
                                              environment: 'development',
                                              revision:    'abc123',
                                              APIHost:     'http://test.host'
                                            });
    });

    it("should return a function that ignores given exception classes", function() {
      var thrown = false;
      var called = false;
      try {
        SquashJavascript.instance().ignoringExceptions("SyntaxError", function(val) {
          called = val;
          throw makeError(SyntaxError);
        })(true);
      } catch (err) {
        expect(SquashJavascript.instance().shouldIgnoreError(err)).toBe(true);
        thrown = true;
      }
      expect(thrown).toBe(true);
      expect(called).toBe(true);

      thrown = false;
      called = false;
      try {
        SquashJavascript.instance().ignoringExceptions("SyntaxError", function(val) {
          called = val;
          throw makeError();
        })(true);
      } catch (err) {
        expect(SquashJavascript.instance().shouldIgnoreError(err)).toBe(false);
        thrown = true;
      }
      expect(thrown).toBe(true);
      expect(called).toBe(true);
    });
  });
});
