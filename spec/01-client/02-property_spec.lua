describe("Homie device", function()

  local D

  setup(function()
    _G._TEST = true
    D = require "homie.Device"
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
      assert("hello", prop:unpack("hello"))
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

    it("percent", function()
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
      assert.same({ h=0, s=0, v=0 }, prop:unpack("0,0,0"))
      assert.same({ h=1, s=2, v=3 }, prop:unpack("1,2,3"))
      assert.same({ h=255, s=255, v=255 }, prop:unpack("255,255,255"))
      assert(not prop:unpack("0,0"))
      assert(not prop:unpack("0,0,"))
      assert(not prop:unpack(",0,0"))
      assert(not prop:unpack("a,b,c"))
      assert(not prop:unpack("0.1,0.2,0.3"))
    end)

    it("color; rgb", function()
      prop.datatype = "color"
      prop.format = "rgb"
      assert.same({ r=0, g=0, b=0 }, prop:unpack("0,0,0"))
      assert.same({ r=1, g=2, b=3 }, prop:unpack("1,2,3"))
      assert.same({ r=255, g=255, b=255 }, prop:unpack("255,255,255"))
      assert(not prop:unpack("0,0"))
      assert(not prop:unpack("0,0,"))
      assert(not prop:unpack(",0,0"))
      assert(not prop:unpack("a,b,c"))
      assert(not prop:unpack("0.1,0.2,0.3"))
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

  end)



  describe("property:validate()", function()

    it("string", function()
      prop.datatype = "string"
      assert.equals("123", prop:unpack("123"))
      assert.equals("hello", prop:unpack("hello"))
      assert(not prop:validate(123))
    end)

    it("integer", function()
      prop.datatype = "integer"
      prop.format = "-100.1e1:100.1e1"
      assert.is.True(prop:validate(12))
      assert.is.True(prop:validate(-12))
      assert.is.False(prop:validate(12.1))
      assert.is.False(prop:validate(-12.1))
      assert.is.False(prop:validate("123"))
      assert.is.False(prop:validate(-1000000))
      assert.is.False(prop:validate(1000000))

      prop.format = nil -- format is optional
      assert.is.True(prop:validate(12))
    end)

    it("float", function()
      prop.datatype = "float"
      prop.format = "-100.1e1:100.1e1"
      assert.is.True(prop:validate(12))
      assert.is.True(prop:validate(-12))
      assert.is.True(prop:validate(12.1))
      assert.is.True(prop:validate(-12.1))
      assert.is.False(prop:validate("123"))
      assert.is.False(prop:validate(-1000000))
      assert.is.False(prop:validate(1000000))

      prop.format = nil -- format is optional
      assert.is.True(prop:validate(12))
    end)

    it("percent", function()
      prop.datatype = "percent"
      prop.format = "-100.1e1:100.1e1"
      assert.is.True(prop:validate(12))
      assert.is.True(prop:validate(-12))
      assert.is.True(prop:validate(12.1))
      assert.is.True(prop:validate(-12.1))
      assert.is.False(prop:validate("123"))
      assert.is.False(prop:validate(-1000000))
      assert.is.False(prop:validate(1000000))

      prop.format = nil -- format is optional
      assert.is.True(prop:validate(12))
    end)

    it("boolean", function()
      prop.datatype = "boolean"
      assert.is.True(prop:validate(1))
      assert.is.True(prop:validate("2"))
      assert.is.True(prop:validate(true))
      assert.is.True(prop:validate(nil))
      assert.is.True(prop:validate(false))
    end)

    it("enum", function()
      prop.datatype = "enum"
      prop.format = "on,between,off"
      assert.is.True(prop:validate("on"))
      assert.is.True(prop:validate("off"))
      assert.is.True(prop:validate("between"))
      assert.is.False(prop:validate(" on"))
      assert.is.False(prop:validate("on "))
      assert.is.False(prop:validate(nil))
      assert.is.False(prop:validate(123))
    end)

    it("color; hsv", function()
      prop.datatype = "color"
      prop.format = "hsv"
      assert.is.True(prop:validate({h=10, s=20, v=30}))
      assert.is.True(prop:validate({h=0, s=0, v=0}))
      assert.is.True(prop:validate({h=360, s=100, v=100}))
      assert.is.False(prop:validate({h=-1, s=20, v=30}))
      assert.is.False(prop:validate({h=10, s=-1, v=30}))
      assert.is.False(prop:validate({h=10, s=20, v=-1}))
      assert.is.False(prop:validate({h=361, s=20, v=30}))
      assert.is.False(prop:validate({h=10, s=101, v=30}))
      assert.is.False(prop:validate({h=10, s=20, v=101}))
      assert.is.False(prop:validate({h=true, s=20, v=30}))
      assert.is.False(prop:validate({h=10, s=true, v=30}))
      assert.is.False(prop:validate({h=10, s=20, v=true}))
    end)

    it("color: rgb", function()
      prop.datatype = "color"
      prop.format = "rgb"
      assert.is.True(prop:validate({r=10, g=20, b=30}))
      assert.is.True(prop:validate({r=0, g=0, b=0}))
      assert.is.True(prop:validate({r=255, g=255, b=255}))
      assert.is.False(prop:validate({r=-1, g=20, b=30}))
      assert.is.False(prop:validate({r=10, g=-1, b=30}))
      assert.is.False(prop:validate({r=10, g=20, b=-1}))
      assert.is.False(prop:validate({r=256, g=20, b=30}))
      assert.is.False(prop:validate({r=10, g=256, b=30}))
      assert.is.False(prop:validate({r=10, g=20, b=256}))
      assert.is.False(prop:validate({r=true, g=20, b=30}))
      assert.is.False(prop:validate({r=10, g=true, b=30}))
      assert.is.False(prop:validate({r=10, g=20, b=true}))
    end)

    pending("datetime", function()
      -- TODO: implement
    end)

    it("duration", function()
      prop.datatype = "duration"
      assert.is.True(prop:validate(20))
      assert.is.False(prop:validate(-20))
      assert.is.False(prop:validate("20"))
    end)

  end)



  describe("property:rset()", function()

    before_each(function()
      prop.id = "propid"
      prop.settable = true
      prop.datatype = "integer"
      prop.node = { id = "nodeid" }
      prop.device = {
        states = { init = "init" },
        base_topic = "homie/devid/"
      }
    end)

    it("doesn't set on non-settable properties", function()
      prop.settable = false
      local ok, err = prop:rset("123")
      assert.equal("property is not settable", err)
      assert.is.Nil(ok)
    end)

    it("unpacks received values", function()
      local s = stub(prop, "set")
      prop:rset("123")
      assert.stub(s).was.called.with(prop, 123, true)
    end)

    it("validates received values", function()
      local ok, err = prop:rset("abc")
      assert.equal("bad value", err)
      assert.is.Nil(ok)
    end)

  end)



  describe("property:pack()", function()

    it("string", function()
      prop.datatype = "string"
      assert.equal("hello", prop:pack("hello"))
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

    it("percent", function()
      prop.datatype = "percent"
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
      assert.equal("10,20,30", prop:pack({h=10, s=20, v=30}))
    end)

    it("color; rgb", function()
      prop.datatype = "color"
      prop.format = "rgb"
      assert.equal("10,20,30", prop:pack({r=10, g=20, b=30}))
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
      prop.datatype = "integer"
      assert.is.True(prop:values_same(10.1, 10.1))
      assert.is.False(prop:values_same(10.1, 11.1))
    end)

    it("percent", function()
      prop.datatype = "percent"
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

    pending("datetime", function()
      -- TODO: implement
    end)

    it("duration", function()
      prop.datatype = "duration"
      assert.is.True(prop:values_same(10.1, 10.1))
      assert.is.False(prop:values_same(10.1, 11.1))
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
        base_topic = "homie/devid/"
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
      prop.node = { id = "nodeid" }
      prop.device = { base_topic = "homie/devid/" }
    end)

    it("calls 'update'", function()
      local s = stub(prop, "update")
      prop:set(123)
      assert.stub(s).was.called.with(prop, 123)
    end)

  end)


end)

