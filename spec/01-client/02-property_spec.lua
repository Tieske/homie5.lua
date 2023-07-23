local EMPTY_STRING_PLACEHOLDER = string.char(0)

describe("Homie device", function()

  local D

  setup(function()
    _G._TEST = true
    D = require "homie5.device"
  end)

  teardown(function()
    _G._TEST = nil
  end)

  local prop
  before_each(function()
    prop = setmetatable({}, D._Property)
  end)


  describe("property:get()", function()

    it("returns the current value", function()
      prop.value = "hi there!"
      assert.equal("hi there!", prop:get())
    end)

  end)



  describe("property:unpack()", function()

    it("string", function()
      prop.datatype = "string"
      assert.equals("hello", prop:unpack("hello"))
      assert.equals("", prop:unpack(EMPTY_STRING_PLACEHOLDER))
    end)

    it("integer", function()
      prop.datatype = "integer"
      assert.equals(10, prop:unpack("10"))
      assert.equals(-10, prop:unpack("-10"))
      assert.equals(100000, prop:unpack("10e4"))
      assert.equals(-100000, prop:unpack("-10e4"))
      assert(not prop:unpack("abc"))
      assert(not prop:unpack(""))
      assert(not prop:unpack("-"))
      assert(not prop:unpack("1.0"))
      assert(not prop:unpack("1-0"))
      assert(not prop:unpack(" 1 "))
    end)

    it("float", function()
      prop.datatype = "float"
      assert.equals(10, prop:unpack("10"))
      assert.equals(-10, prop:unpack("-10"))
      assert.equals(100000, prop:unpack("10e4"))
      assert.equals(-100000, prop:unpack("-10e4"))
      assert.equals(10.1, prop:unpack("10.1"))
      assert.equals(-10.1, prop:unpack("-10.1"))
      assert.equals(101000, prop:unpack("10.1e4"))
      assert.equals(-101000, prop:unpack("-10.1e4"))
      assert(not prop:unpack("abc"))
      assert(not prop:unpack(""))
      assert(not prop:unpack("-"))
      assert(not prop:unpack(" 1 "))
    end)

    it("boolean", function()
      prop.datatype = "boolean"
      assert.equals(true, prop:unpack("true"))
      assert.equals(false, prop:unpack("false"))
      assert(not prop:unpack("True"))
      assert(not prop:unpack("False"))
      assert(not prop:unpack(" true"))
      assert(not prop:unpack("true "))
    end)

    it("enum", function()
      prop.datatype = "enum"
      assert("hello", prop:unpack("hello"))
    end)

    it("color; hsv", function()
      prop.datatype = "color"
      prop.format = "hsv"
      assert.same({ h=0, s=0, v=0 }, prop:unpack("hsv,0,0,0"))
      assert.same({ h=1, s=2, v=3 }, prop:unpack("hsv,1,2,3"))
      assert.same({ h=255, s=255, v=255 }, prop:unpack("hsv,255,255,255"))
      assert.same({ h=0.1, s=0.2, v=0.3 }, prop:unpack("hsv,0.1,0.2,0.3"))
      assert(not prop:unpack("hsv,0,0"))
      assert(not prop:unpack("hsv,0,0,"))
      assert(not prop:unpack(",0,0"))
      assert(not prop:unpack("hsv,a,b,c"))
      assert(not prop:unpack("hsv,a,b,c"))
      assert(not prop:unpack("hsv,0,...,0")) -- "..." matches allowed decimal dots
    end)

    it("color; rgb", function()
      prop.datatype = "color"
      prop.format = "rgb"
      assert.same({ r=0, g=0, b=0 }, prop:unpack("rgb,0,0,0"))
      assert.same({ r=1, g=2, b=3 }, prop:unpack("rgb,1,2,3"))
      assert.same({ r=255, g=255, b=255 }, prop:unpack("rgb,255,255,255"))
      assert.same({ r=0.1, g=0.2, b=0.3 }, prop:unpack("rgb,0.1,0.2,0.3"))
      assert(not prop:unpack("rgb,0,0"))
      assert(not prop:unpack("rgb,0,0,"))
      assert(not prop:unpack(",0,0"))
      assert(not prop:unpack("rgb,a,b,c"))
      assert(not prop:unpack("rgb,0,...,0")) -- "..." matches allowed decimal dots
    end)
-- should these be a single unpack function without any validatioon???? per type
    it("color; xyz", function()
      prop.datatype = "color"
      prop.format = "xyz"
      assert.same({ x=0, y=0 }, prop:unpack("xyz,0,0"))
      assert.same({ x=1, y=1 }, prop:unpack("xyz,1,1"))
      assert.same({ x=0.5, y=0.3 }, prop:unpack("xyz,0.5,0.3"))
      assert(not prop:unpack("xyz,0"))
      assert(not prop:unpack("xyz,0,"))
      assert(not prop:unpack(",0"))
      assert(not prop:unpack("b,c"))
      assert(not prop:unpack("xyz,...,0")) -- "..." matches allowed decimal dots
    end)

    pending("datetime", function()
      -- TODO: implement
    end)

    it("duration", function()
      prop.datatype = "duration"
      assert.equals(10, prop:unpack("PT10S"))
      assert.equals(0.10, prop:unpack("PT.10S"))
      assert.equals(10*60, prop:unpack("PT10M"))
      assert.equals(0.1*60, prop:unpack("PT.10M"))
      assert.equals(10*60*60, prop:unpack("PT10H"))
      assert.equals(0.1*60*60, prop:unpack("PT.1H"))
      assert.equals(60*60 + 60 + 1, prop:unpack("PT1H1M1S"))
      assert(not prop:unpack("1H1M1S"))
      assert(not prop:unpack("PT1S1M1H"))
    end)

    it("json", function()
      prop.datatype = "json"
      assert.same({}, prop:unpack("{}"))
      assert.same({ name = "tieske" }, prop:unpack('{ "name": "tieske"}'))
      assert(not prop:unpack("this is not valid json"))
    end)

  end)



  describe("property:validate()", function()

    it("string", function()
      prop.datatype = "string"
      assert.equals("123", prop:validate("123"))
      assert.equals("hello", prop:validate("hello"))
      assert.is.Nil(prop:validate(123))
    end)

    it("integer", function()
      prop.datatype = "integer"
      prop.format = "-100.1e1:100.1e1"
      assert.equals(12, prop:validate(12))
      assert.equals(-12, prop:validate(-12))
      assert.is.Nil(prop:validate(12.1))
      assert.is.Nil(prop:validate(-12.1))
      assert.is.Nil(prop:validate("123"))
      assert.is.Nil(prop:validate(-1000000))
      assert.is.Nil(prop:validate(1000000))

      prop.format = nil -- format is optional
      assert.equals(12, prop:validate(12))

      -- step base priority: min, max, current-value
      prop.format = "-2:11:3" -- base = -2, allowed values: -2, 1, 4, 7, 10
      assert.equals(-2, prop:validate(-2))
      assert.equals(-2, prop:validate(-1))
      assert.equals(1, prop:validate(-0))
      assert.equals(1, prop:validate(1))
      assert.equals(1, prop:validate(2))
      assert.equals(4, prop:validate(3))
      prop.format = ":11:3" -- base = 11, allowed values: ..., -1, 2, 5, 8, 11
      assert.equals(-1, prop:validate(-2))
      assert.equals(-1, prop:validate(-1))
      assert.equals(-1, prop:validate(0))
      assert.equals(2, prop:validate(1))
      assert.equals(2, prop:validate(2))
      assert.equals(2, prop:validate(3))
      prop.value = 0
      prop.format = "::3" -- base = 0, allowed values: ..., -3, 0, 3, 6, 9, ...
      assert.equals(-3, prop:validate(-2))
      assert.equals(0, prop:validate(-1))
      assert.equals(0, prop:validate(0))
      assert.equals(0, prop:validate(1))
      assert.equals(3, prop:validate(2))
      assert.equals(3, prop:validate(3))

      -- unreachable maximum
      prop.format = "0:11:3" -- base = 0, allowed values: 0, 3, 6, 9
      assert.is.Nil(prop:validate(11)) -- 11 rounds to 12, which is beyond the maximum
    end)

    it("float", function()
      prop.datatype = "float"
      prop.format = "-100.1e1:100.1e1"
      assert.equals(12, prop:validate(12))
      assert.equals(-12, prop:validate(-12))
      assert.equals(12.1, prop:validate(12.1))
      assert.equals(-12.1, prop:validate(-12.1))
      assert.is.Nil(prop:validate("123"))
      assert.is.Nil(prop:validate(-1000000))
      assert.is.Nil(prop:validate(1000000))

      prop.format = nil -- format is optional
      assert.equals(12, prop:validate(12))

      -- step base priority: min, max, current-value
      prop.format = "0:1:0.3" -- base = 0, allowed values: 0, 0.3, 0.6, 0.9
      assert.is.near(0, prop:validate(0), 0.00001)
      assert.is.near(0, prop:validate(0.1), 0.00001)
      assert.is.near(0.3, prop:validate(0.2), 0.00001)
      assert.is.near(0.3, prop:validate(0.3), 0.00001)
      assert.is.near(0.3, prop:validate(0.4), 0.00001)
      assert.is.near(0.6, prop:validate(0.5), 0.00001)
      prop.format = ":1:0.3" -- base = 1, allowed values: ..., 0.1, 0.4, 0.7, 1
      assert.is.near(0.1, prop:validate(0), 0.00001)
      assert.is.near(0.1, prop:validate(0.1), 0.00001)
      assert.is.near(0.1, prop:validate(0.2), 0.00001)
      assert.is.near(0.4, prop:validate(0.3), 0.00001)
      assert.is.near(0.4, prop:validate(0.4), 0.00001)
      assert.is.near(0.4, prop:validate(0.5), 0.00001)
      prop.value = 0.2
      prop.format = "::0.3" -- base = 0.2, allowed values: ..., -0.1, 0.2, 0.5, 0.8, 0.11, ...
      assert.is.near(-0.1, prop:validate(0), 0.00001)
      assert.is.near(0.2, prop:validate(0.1), 0.00001)
      assert.is.near(0.2, prop:validate(0.2), 0.00001)
      assert.is.near(0.2, prop:validate(0.3), 0.00001)
      assert.is.near(0.5, prop:validate(0.4), 0.00001)
      assert.is.near(0.5, prop:validate(0.5), 0.00001)
      assert.is.near(0.5, prop:validate(0.6), 0.00001)

      -- unreachable maximum
      prop.format = "0:1.1:0.3" -- base = 0, allowed values: 0, 0.3, 0.6, 0.9
      assert.is.Nil(prop:validate(1.1)) -- 1.1 rounds to 1.2, which is beyond the maximum
    end)

    it("boolean", function()
      prop.datatype = "boolean"
      assert.equals(true, prop:validate(1))
      assert.equals(true, prop:validate("2"))
      assert.equals(true, prop:validate(true))
      assert.equals(false, prop:validate(nil))
      assert.equals(false, prop:validate(false))
    end)

    it("enum", function()
      prop.datatype = "enum"
      prop.format = "on,between,off"
      assert.equals("on", prop:validate("on"))
      assert.equals("off", prop:validate("off"))
      assert.equals("between", prop:validate("between"))
      assert.is.Nil(prop:validate(" on"))
      assert.is.Nil(prop:validate("on "))
      assert.is.Nil(prop:validate(nil))
      assert.is.Nil(prop:validate(123))
    end)

    it("color; hsv", function()
      prop.datatype = "color"
      prop.format = "hsv"
      assert.are.same({h=10, s=20, v=30}, prop:validate({h=10, s=20, v=30}))
      assert.are.same({h=0, s=0, v=0}, prop:validate({h=0, s=0, v=0}))
      assert.are.same({h=360, s=100, v=100}, prop:validate({h=360, s=100, v=100}))
      assert.is.Nil(prop:validate({h=-1, s=20, v=30}))
      assert.is.Nil(prop:validate({h=10, s=-1, v=30}))
      assert.is.Nil(prop:validate({h=10, s=20, v=-1}))
      assert.is.Nil(prop:validate({h=361, s=20, v=30}))
      assert.is.Nil(prop:validate({h=10, s=101, v=30}))
      assert.is.Nil(prop:validate({h=10, s=20, v=101}))
      assert.is.Nil(prop:validate({h=true, s=20, v=30}))
      assert.is.Nil(prop:validate({h=10, s=true, v=30}))
      assert.is.Nil(prop:validate({h=10, s=20, v=true}))
    end)

    it("color: rgb", function()
      prop.datatype = "color"
      prop.format = "rgb"
      assert.are.same({r=10, g=20, b=30}, prop:validate({r=10, g=20, b=30}))
      assert.are.same({r=0, g=0, b=0}, prop:validate({r=0, g=0, b=0}))
      assert.are.same({r=255, g=255, b=255}, prop:validate({r=255, g=255, b=255}))
      assert.is.Nil(prop:validate({r=-1, g=20, b=30}))
      assert.is.Nil(prop:validate({r=10, g=-1, b=30}))
      assert.is.Nil(prop:validate({r=10, g=20, b=-1}))
      assert.is.Nil(prop:validate({r=256, g=20, b=30}))
      assert.is.Nil(prop:validate({r=10, g=256, b=30}))
      assert.is.Nil(prop:validate({r=10, g=20, b=256}))
      assert.is.Nil(prop:validate({r=true, g=20, b=30}))
      assert.is.Nil(prop:validate({r=10, g=true, b=30}))
      assert.is.Nil(prop:validate({r=10, g=20, b=true}))
    end)

    it("color: xyz", function()
      prop.datatype = "color"
      prop.format = "xyz"
      assert.are.same({x=0, y=1, z=0}, prop:validate({x=0, y=1}))
      assert.are.same({x=1, y=0, z=0}, prop:validate({x=1, y=0}))
      assert.are.same({x=0.5, y=0.5, z=0 }, prop:validate({x=0.5, y=0.5}))
      assert.are.same({x=0.5, y=0.5, z=0 }, prop:validate({x=0.5, z=0}))
      assert.are.same({x=0.5, y=0.5, z=0 }, prop:validate({z=0, y=0.5}))
      assert.is.Nil(prop:validate({x=-1, y=0.1}))
      assert.is.Nil(prop:validate({x=2, y=0.1}))
      assert.is.Nil(prop:validate({y=-1, x=0.1}))
      assert.is.Nil(prop:validate({y=2, x=0.1}))
      assert.is.Nil(prop:validate({x=true, y=0.1}))
      assert.is.Nil(prop:validate({y=true, x=0.1}))
    end)

    it("color: rgb,hsv,xyz", function()
      prop.datatype = "color"
      prop.format = "rgb,hsv,xyz"
      assert.are.same({r=10, g=20, b=30}, prop:validate({r=10, g=20, b=30}))
      assert.are.same({r=0, g=0, b=0}, prop:validate({r=0, g=0, b=0}))
      assert.are.same({r=255, g=255, b=255}, prop:validate({r=255, g=255, b=255}))
      assert.are.same({h=10, s=20, v=30}, prop:validate({h=10, s=20, v=30}))
      assert.are.same({h=0, s=0, v=0}, prop:validate({h=0, s=0, v=0}))
      assert.are.same({h=360, s=100, v=100}, prop:validate({h=360, s=100, v=100}))
      assert.are.same({x=0, y=1, z=0}, prop:validate({x=0, y=1}))
      assert.are.same({x=1, y=0, z=0}, prop:validate({x=1, y=0}))
      assert.are.same({x=0.5, y=0.5, z=0}, prop:validate({x=0.5, y=0.5}))
    end)

    pending("datetime", function()
      -- TODO: implement
    end)

    it("duration", function()
      prop.datatype = "duration"
      assert.equals(20, prop:validate(20))
      assert.is.Nil(prop:validate(-20))
      assert.is.Nil(prop:validate("20"))
    end)

    it("json", function()
      prop.datatype = "json"
      -- default allows only object or array
      prop.format = nil
      assert.same({ name = "tieske" }, prop:validate(assert(prop:unpack('{ "name": "tieske" }'))))
      assert.same({ "tieske" }, prop:validate(assert(prop:unpack('[ "tieske" ]'))))
      assert.is.Nil(prop:validate(assert(prop:unpack('123')))) -- a numeric literal (is valid json)

      prop.format = [[{
        "type": "object",
        "properties": {
          "foo": { "type": "string" },
          "bar": { "type": "number" }
        }
      }]]
      assert.same({ foo = "hello", bar = 123 }, prop:validate({ foo = "hello", bar = 123 }))
      assert.is.Nil(prop:validate({ bar = "hello", foo = 123 }))
    end)

  end)



  describe("property:rset()", function()

    before_each(function()
      prop.id = "propid"
      prop.topic = "homie/5/devid/nodeid/propid"
      prop.settable = true
      prop.datatype = "integer"
      prop.format = "0:100:2"
      prop.node = { id = "nodeid" }
      prop.device = {
        states = { init = "init" },
        base_topic = "homie/5/devid/",
        send_property_update = function() return true end
      }
    end)

    it("doesn't set on non-settable properties", function()
      prop.settable = false
      local ok, err = prop:rset("123")
      assert.equal("property is not settable", err)
      assert.is.Nil(ok)
    end)

    it("unpacks received values", function()
      prop:rset("50")
      assert.equal(50, prop.value)
    end)

    it("validates received values", function()
      local ok, err = prop:rset("abc")
      assert.equal("bad value", err)
      assert.is.Nil(ok)
    end)

    it("rounds received values", function()
      prop:rset("11")
      assert.equal(12, prop.value)
    end)

  end)



  describe("property:pack()", function()

    it("string", function()
      prop.datatype = "string"
      assert.equal("hello", prop:pack("hello"))
      assert.equal(EMPTY_STRING_PLACEHOLDER, prop:pack(""))
    end)

    it("integer", function()
      prop.datatype = "integer"
      assert.equal("123", prop:pack(123))
      assert.equal("-123", prop:pack(-123))
    end)

    it("float", function()
      prop.datatype = "float"
      assert.equal("123", prop:pack(123))
      assert.equal("-123", prop:pack(-123))
      assert.equal("123.1", prop:pack(123.1))
      assert.equal("-123.1", prop:pack(-123.1))
    end)

    it("boolean", function()
      prop.datatype = "boolean"
      assert.equal("true", prop:pack(true))
      assert.equal("true", prop:pack("hi"))
      assert.equal("true", prop:pack(123))
      assert.equal("false", prop:pack(false))
      assert.equal("false", prop:pack(nil))
    end)

    it("enum", function()
      prop.datatype = "enum"
      assert.equal("hello", prop:pack("hello"))
    end)

    it("color; hsv", function()
      prop.datatype = "color"
      prop.format = "hsv"
      assert.equal("hsv,10,20,30", prop:pack({h=10, s=20, v=30}))
      assert.equal("hsv,0.1,0.2,0.3", prop:pack({h=0.1, s=0.20, v=0.3}))
    end)

    it("color; rgb", function()
      prop.datatype = "color"
      prop.format = "rgb"
      assert.equal("rgb,10,20,30", prop:pack({r=10, g=20, b=30}))
      assert.equal("rgb,0.1,0.2,0.3", prop:pack({r=0.1, g=0.20, b=0.3}))
    end)

    it("color; xyz", function()
      prop.datatype = "color"
      prop.format = "xyz"
      assert.equal("xyz,0.1,0.2", prop:pack({x=0.1, y=0.2}))
    end)

    it("color; rgb,hsv,xyz bases format on precedence", function()
      prop.datatype = "color"
      prop.format = "rgb,hsv,xyz"
      local data = {r=10, g=20, b=30, h=40, s=50, v=60, x=0.1, y=0.2}
      assert.equal("rgb,10,20,30", prop:pack(data))
      data.r = nil
      assert.equal("hsv,40,50,60", prop:pack(data))
      data.h = nil
      assert.equal("xyz,0.1,0.2", prop:pack(data))
    end)

    pending("datetime", function()
      -- TODO: implement
    end)

    it("duration", function()
      prop.datatype = "duration"
      assert.equal("PT1H1M1S", prop:pack(60*60 + 60 + 1))
      assert.equal("PT1H", prop:pack(60*60))
      assert.equal("PT1M", prop:pack(60))
      assert.equal("PT1S", prop:pack(1))
      assert.equal("PT0S", prop:pack(0))
      assert.equal("PT0.001S", prop:pack(0.001))
    end)

    it("json", function()
      prop.datatype = "json"
      assert.equal('["one","two"]', prop:pack({"one", "two"}))
      assert.equal('{"one":"two"}', prop:pack({one = "two"}))
    end)

  end)



  describe("property:values_same()", function()

    it("string", function()
      prop.datatype = "string"
      assert.is.True(prop:values_same("hello", "hello"))
      assert.is.False(prop:values_same("hello", "goodbye"))
    end)

    it("integer", function()
      prop.datatype = "integer"
      assert.is.True(prop:values_same(10, 10))
      assert.is.False(prop:values_same(10, 11))
    end)

    it("float", function()
      prop.datatype = "float"
      assert.is.True(prop:values_same(10.1, 10.1))
      assert.is.False(prop:values_same(10.1, 11.1))
    end)

    it("boolean", function()
      prop.datatype = "boolean"
      assert.is.True(prop:values_same(true, true))
      assert.is.True(prop:values_same(false, false))
      assert.is.True(prop:values_same(false, nil))
      assert.is.True(prop:values_same(true, "hi"))
      assert.is.True(prop:values_same(true, 123))
    end)

    it("enum", function()
      prop.datatype = "enum"
      assert.is.True(prop:values_same("hello", "hello"))
      assert.is.False(prop:values_same("hello", "goodbye"))
    end)

    it("color; hsv", function()
      prop.datatype = "color"
      prop.format = "hsv"
      assert.is.True(prop:values_same({ h=1, s=2, v=3 }, { h=1, s=2, v=3 }))
      assert.is.False(prop:values_same({ h=1, s=2, v=3 }, { h=0, s=2, v=3 }))
      assert.is.False(prop:values_same({ h=1, s=2, v=3 }, { h=1, s=0, v=3 }))
      assert.is.False(prop:values_same({ h=1, s=2, v=3 }, { h=1, s=2, v=0 }))
      assert.is.False(prop:values_same({ h=1, s=2, v=3 }, true))
      assert.is.False(prop:values_same({ h=1, s=2, v=3 }, "true"))
    end)

    it("color; rgb", function()
      prop.datatype = "color"
      prop.format = "rgb"
      assert.is.True(prop:values_same({ r=1, g=2, b=3 }, { r=1, g=2, b=3 }))
      assert.is.False(prop:values_same({ r=1, g=2, b=3 }, { r=0, g=2, b=3 }))
      assert.is.False(prop:values_same({ r=1, g=2, b=3 }, { r=1, g=0, b=3 }))
      assert.is.False(prop:values_same({ r=1, g=2, b=3 }, { r=1, g=2, b=0 }))
      assert.is.False(prop:values_same({ r=1, g=2, b=3 }, true))
      assert.is.False(prop:values_same({ r=1, g=2, b=3 }, "true"))
    end)

    it("color; xyz", function()
      prop.datatype = "color"
      prop.format = "xyz"
      assert.is.True(prop:values_same({ x=0.5, y=0.1 }, { x=0.5, y=0.1 }))
      assert.is.False(prop:values_same({ x=0.5, y=0.1 }, { x=0.4, y=0.1 }))
      assert.is.False(prop:values_same({ x=0.5, y=0.1 }, { x=0.5, y=0.2 }))
      assert.is.False(prop:values_same({ x=0.5, y=0.1 }, true))
      assert.is.False(prop:values_same({ x=0.5, y=0.1 }, "true"))
    end)

    it("color; rgb,hsv,xyz based on precedence", function()
      prop.datatype = "color"
      prop.format = "rgb,hsv,xyz"
      local data = {r=10, g=20, b=30, h=40, s=50, v=60, x=0.1, y=0.2}
      assert.is.True(prop:values_same(data, { r=10, g=20, b=30 }))
      assert.is.False(prop:values_same(data, { h=40, s=50, v=60 }))
      assert.is.False(prop:values_same(data, { x=0.1, y=0.2 }))
      data.r = nil
      assert.is.False(prop:values_same(data, { r=10, g=20, b=30 }))
      assert.is.True(prop:values_same(data, { h=40, s=50, v=60 }))
      assert.is.False(prop:values_same(data, { x=0.1, y=0.2 }))
      data.h = nil
      assert.is.False(prop:values_same(data, { r=10, g=20, b=30 }))
      assert.is.False(prop:values_same(data, { h=40, s=50, v=60 }))
      assert.is.True(prop:values_same(data, { x=0.1, y=0.2 }))
    end)

    pending("datetime", function()
      -- TODO: implement
    end)

    it("duration", function()
      prop.datatype = "duration"
      assert.is.True(prop:values_same(10.1, 10.1))
      assert.is.False(prop:values_same(10.1, 11.1))
    end)

    it("json", function()
      prop.datatype = "json"
      assert.is.True(prop:values_same({10, 11}, {10, 11}))
      assert.is.False(prop:values_same({10, 11}), {11, 12})
    end)

  end)



  describe("property:update()", function()

    before_each(function()
      prop.id = "propid"
      prop.retained = true
      prop.settable = true
      prop.datatype = "integer"
      prop.node = { id = "nodeid" }
      prop.device = {
        send_property_update = function() end,
        base_topic = "homie/5/devid/"
      }
      prop.topic = prop.device.base_topic .. prop.node.id .. "/" ..prop.id
    end)

    it("validates value", function()
      local ok, err = prop:set("abc")
      assert.is.falsy(ok)
      assert.equal("value is not an integer matching format 'nil', got: 'abc' (string)", err)
    end)

    it("calls device to send MQTT topic update", function()
      local new_value = (prop:get() or 0) + 1
      local s = stub(prop.device, "send_property_update")
      prop:update(new_value)
      assert.stub(s).was.called.with(prop.device, prop.topic, tostring(new_value), prop.retained)
    end)

    it("packs value", function()
      local new_value = (prop:get() or 0) + 1
      local s = stub(prop.device, "send_property_update")
      prop:update(new_value)
      assert.stub(s).was.called.with(prop.device, prop.topic, tostring(new_value), prop.retained)
    end)

    it("only updates if different", function()
      prop:update(123)
      local s = stub(prop.device, "send_property_update")
      prop:update(prop:get())
      assert.stub(s).was.Not.called()
    end)

    it("updates if same, but forced", function()
      prop:update(123)
      local s = stub(prop.device, "send_property_update")
      prop:update(prop:get(), true)
      assert.stub(s).was.called()
    end)

    it("always updates if not retained", function()
      prop.retained = false
      prop:update(123)
      local s = stub(prop.device, "send_property_update")
      prop:update(prop:get(), false) -- update to same value, not forced
      assert.stub(s).was.called()
    end)

  end)



  describe("property:set()", function()

    before_each(function()
      prop.id = "propid"
      prop.settable = true
      prop.datatype = "integer"
      prop.format = "0:100:5"
      prop.node = { id = "nodeid" }
      prop.device = {
        base_topic = "homie/5/devid/",
        send_property_update = function() return true end,
      }
    end)

    it("calls 'update'", function()
      prop.value = 0
      prop:set(50)
      assert.equals(50, prop.value)
    end)

    it("calls rounds number values", function()
      prop.value = 0
      prop:set(53)
      assert.equals(55, prop.value)
    end)

  end)


end)

