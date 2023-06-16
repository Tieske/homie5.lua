describe("Homie device", function()

  local D

  setup(function()
    _G._TEST = true
    D = require "homie.Device"
  end)

  teardown(function()
    _G._TEST = nil
  end)



  describe("validate_segment()", function()

    it("allows valid segments", function()
      local v = D._validate_segment
      assert(v("homie") == "homie")
      assert(v("h-omie") == "h-omie")
      assert(v("homi-e") == "homi-e")
      assert(v("h0m1e") == "h0m1e")
      assert(v("1omi3") == "1omi3")
      assert(v("$homie", true) == "$homie")
      assert(v("$h-omie", true) == "$h-omie")
      assert(v("$homi-e", true) == "$homi-e")
      assert(v("$h0m1e", true) == "$h0m1e")
      assert(v("$1omi3", true) == "$1omi3")
    end)

    it("fails on bad segment", function()
      local v = D._validate_segment
      assert(not v("HOMIE"))
      assert(not v("-omie"))
      assert(not v("homi-"))
      assert(not v("h0M1e"))
      assert(not v("$1omi3"))
      assert(not v("$HOMIE", true))
      assert(not v("$-omie", true))
      assert(not v("$homi-", true))
      assert(not v("$h0M1e", true))
      assert(not v("1omi3", true))
    end)

  end)



  describe("validate_broadcast_topic()", function()

    local d = { domain = "domain" }

    it("qualifies relative topics", function()
      local v = D._validate_broadcast_topic
      assert(v(d, "hello") == "domain/$broadcast/hello")
      assert(v(d, "hello/there") == "domain/$broadcast/hello/there")
      assert(v(d, "/hello") == "domain/$broadcast/hello")
      assert(v(d, "/hello/there") == "domain/$broadcast/hello/there")
    end)

    it("keeps qualified topics", function()
      local v = D._validate_broadcast_topic
      assert(v(d, "domain/$broadcast/hello") == "domain/$broadcast/hello")
    end)

    it("checks proper domain", function()
      local v = D._validate_broadcast_topic
      -- domain in 'd' == 'domain', which doesn't match 'homie' given here
      assert(not v(d, "homie/$broadcast/hello"))
    end)

  end)



  describe("validate_format()", function()

    it("allows valid formats", function()
      local v = D._validate_format
      assert(v("percent", "0:100"))
      assert(v("float", "0.111:9.999"))
      assert(v("integer", "-100:100"))
      assert(v("enum", "a,b,c"))
      assert(v("color", "hsv"))
      assert(v("color", "rgb"))
    end)

    it("fails invalid formats", function()
      local v = D._validate_format
      -- number formats
      assert(not v("percent", 0))
      assert(not v("float", ":9.999"))
      assert(not v("integer", "100:-100"))
      -- color
      assert(not v("color", "not hsv nor rgb"))
      -- enum
      assert(not v("enum", ",hsv"))
      assert(not v("enum", "hsv, rgb ,whitespace"))
      -- datatype without format
      assert(not v("datetime", "value"))
    end)

  end)



  describe("validate_property()", function()

    local prop, node, dev

    before_each(function()
      -- set to something valid before each test
      prop = setmetatable({
        name = "setpoint",
        datatype = "float",
        format = "1:100",
        settable = true,
        retained = true,
        unit = "°C",
        default = 10,
      }, D._Property)
      node = {}
      dev = {}
    end)

    it("accepts valid properties", function()
      assert(D._validate_property(prop, node, dev))
    end)

    it("does not allow unknown attributes/fields", function()
      prop.someattribute = "a value"
      assert(not D._validate_property(prop, node, dev))
    end)

    it("property must be a table", function()
      prop = 123
      assert(not D._validate_property(prop, node, dev))
    end)

    describe("$name attribute", function()

      it("is required", function()
        prop.name = nil
        assert(not D._validate_property(prop, node, dev))
      end)

      it("must be a string", function()
        prop.name = 123
        assert(not D._validate_property(prop, node, dev))
      end)

      it("cannot be empty string", function()
        prop.name = ""
        assert(not D._validate_property(prop, node, dev))
      end)

    end)

    describe("$datatype attribute", function()

      it("is required", function()
        prop.datatype = nil
        assert(not D._validate_property(prop, node, dev))
      end)

      it("must be a string", function()
        prop.datatype = 123
        assert(not D._validate_property(prop, node, dev))
      end)

      it("must be a valid type", function()
        prop.datatype = "not an integer"
        assert(not D._validate_property(prop, node, dev))
      end)

    end)

    describe("$settable attribute", function()

      it("is not required", function()
        prop.settable = nil
        assert(D._validate_property(prop, node, dev))
      end)

      it("must be a boolean", function()
        prop.settable = 123
        assert(not D._validate_property(prop, node, dev))
      end)

      it("defaults to false", function()
        prop.settable = nil
        assert(D._validate_property(prop, node, dev))
        assert.is.False(prop.settable)
      end)

    end)

    describe("$retained attribute", function()

      it("is not required", function()
        prop.retained = nil
        assert(D._validate_property(prop, node, dev))
      end)

      it("must be a boolean", function()
        prop.retained = 123
        assert(not D._validate_property(prop, node, dev))
      end)

      it("defaults to false", function()
        prop.retained = nil
        assert(D._validate_property(prop, node, dev))
        assert.is.True(prop.settable)
      end)

    end)

    describe("$format attribute", function()

      it("is required for enum", function()
        prop.format = nil
        prop.datatype = "enum"
        prop.format = nil
        assert(not D._validate_property(prop, node, dev))
      end)

      it("is required for color", function()
        prop.format = nil
        prop.datatype = "color"
        prop.format = nil
        assert(not D._validate_property(prop, node, dev))
      end)

      it("is not required for others", function()
        prop.format = nil
        prop.datatype = "integer"
        prop.format = nil
        assert(D._validate_property(prop, node, dev))
      end)

    end)

    describe("$unit attribute", function()

      it("is not required", function()
        prop.unit = nil
        assert(D._validate_property(prop, node, dev))
      end)

      it("must be a string", function()
        prop.unit = 123
        assert(not D._validate_property(prop, node, dev))
      end)

      it("cannot be empty string", function()
        prop.unit = ""
        assert(not D._validate_property(prop, node, dev))
      end)

    end)

    describe("default attribute", function()

      it("is not required", function()
        prop.default = nil
        assert(D._validate_property(prop, node, dev))
      end)

      it("must pass validation", function()
        prop.default = "not a number"
        assert(not D._validate_property(prop, node, dev))
      end)

    end)

  end)  -- validate_property()



  describe("validate_properties()", function()

    local props, node, dev

    before_each(function()
      -- set properties to something valid before each test
      props = {
        propid = {
          name = "setpoint",
          datatype = "float",
          format = "1:100",
          settable = true,
          retained = true,
          unit = "°C",
        }
      }
      node = {
        id = "mynode"
      }
      dev = {
        base_topic = "homie/mydev/"
      }
    end)


    it("accepts valid properties", function()
      assert(D._validate_properties(props, node, dev))
    end)

    it("property must be a table", function()
      props.propid = "hello"
      assert(not D._validate_properties(props, node, dev))
    end)

    it("properties must have a valid property ID", function()
      props["---"] = props.propid
      assert(not D._validate_properties(props, node, dev))
    end)

    it("properties must be valid", function()
      props.propid.name = 123
      assert(not D._validate_properties(props, node, dev))
    end)

    it("sets the qmtt topic for the property", function()
      assert(D._validate_properties(props, node, dev))
      assert.equals("homie/mydev/mynode/propid", props.propid.topic)
    end)

    it("sets the related node and device properties", function()
      assert(D._validate_properties(props, node, dev))
      assert.equals(node, props.propid.node)
      assert.equals(dev, props.propid.device)
    end)

    it("sets the Property metatable", function()
      assert(D._validate_properties(props, node, dev))
      assert.equals(D._Property, getmetatable(props.propid))
    end)

  end)



  describe("validate_node()", function()

    local node, dev

    before_each(function()
      -- set to something valid before each test
      node = {
        id = "mynode",
        name = "thermostat",
        type = "horstmann",
        properties = {
          propid = {
            name = "setpoint",
            datatype = "float",
            format = "1:100",
            settable = true,
            retained = true,
            unit = "°C",
          }
        }
      }
      dev = {
        base_topic = "homie/mydev/"
      }
    end)


    it("accepts a valid node", function()
      assert(D._validate_node(node, dev))
    end)

    it("does not allow unknown attributes/fields", function()
      node.someattribute = "a value"
      assert(not D._validate_node(node, dev))
    end)

    it("node must be a table", function()
      node = 123
      assert(not D._validate_node(node, dev))
    end)

    describe("$name attribute", function()

      it("is required", function()
        node.name = nil
        assert(not D._validate_node(node, dev))
      end)

      it("must be a string", function()
        node.name = 123
        assert(not D._validate_node(node, dev))
      end)

      it("cannot be empty string", function()
        node.name = ""
        assert(not D._validate_node(node, dev))
      end)

    end)

    describe("$type attribute", function()

      it("is required", function()
        node.type = nil
        assert(not D._validate_node(node, dev))
      end)

      it("must be a string", function()
        node.type = 123
        assert(not D._validate_node(node, dev))
      end)

      it("cannot be empty string", function()
        node.type = ""
        assert(not D._validate_node(node, dev))
      end)

    end)

    it("$properties is required", function()
      node.properties = nil
      assert(not D._validate_node(node, dev))
    end)

  end)



  describe("validate_nodes()", function()

    local nodes, dev

    before_each(function()
      -- set to something valid before each test
      nodes = {
        nodeid = {
          name = "thermostat",
          type = "horstmann",
          properties = {
            propid = {
              name = "setpoint",
              datatype = "float",
              format = "1:100",
              settable = true,
              retained = true,
              unit = "°C",
            }
          }
        }
      }
      dev = {
        base_topic = "homie/mydev/"
      }
    end)


    it("accepts valid nodes", function()
      assert(D._validate_nodes(nodes, dev))
    end)

    it("node must be a table", function()
      nodes.nodeid = "hello"
      assert(not D._validate_nodes(nodes, dev))
    end)

    it("nodes must have a valid node ID", function()
      nodes["---"] = nodes.nodeid
      assert(not D._validate_nodes(nodes, dev))
    end)

    it("nodes must be valid", function()
      nodes.nodeid.name = 123
      assert(not D._validate_nodes(nodes, dev))
    end)

    it("sets the related device properties", function()
      assert(D._validate_nodes(nodes, dev))
      assert.equals(dev, nodes.nodeid.device)
    end)

    it("sets the Node metatable", function()
      assert(D._validate_nodes(nodes, dev))
      assert.equals(D._Node, getmetatable(nodes.nodeid))
    end)

  end)



  describe("validate_device()", function()

    local dev

    before_each(function()
      -- set to something valid before each test
      dev = {
        homie = "4.0.0",
        name = "device name",
        extensions = "",
        implementation = "my device",
        base_topic = "homie/mydev",
        nodes = {
          nodeid = {
            name = "thermostat",
            type = "horstmann",
            properties = {
              propid = {
                name = "setpoint",
                datatype = "float",
                format = "1:100",
                settable = true,
                retained = true,
                unit = "°C",
              }
            }
          }
        }
      }
    end)


    it("accepts a valid device", function()
      assert(D._validate_device(dev))
    end)

    it("does allow unknown attributes/fields", function()
      dev.someattribute = "a value"
      assert(D._validate_device(dev))
    end)

    it("device must be a table", function()
      dev = 123
      assert(not D._validate_device(dev))
    end)

    it("$homie attribute must be '4.0.0'", function()
      dev.homie = "bad value"
      assert(not D._validate_device(dev))
    end)

    describe("$name attribute", function()

      it("is required", function()
        dev.name = nil
        assert(not D._validate_device(dev))
      end)

      it("must be a string", function()
        dev.name = 123
        assert(not D._validate_device(dev))
      end)

      it("cannot be empty string", function()
        dev.name = ""
        assert(not D._validate_device(dev))
      end)

    end)

    it("$state attribute must be nil", function()
      dev.state = "init"
      assert(not D._validate_device(dev))
    end)

    it("$extensions attribute must be an empty string", function()
      dev.extensions = "not empty"
      assert(not D._validate_device(dev))
    end)

    describe("$implementation attribute", function()

      it("must be a string", function()
        dev.implementation = 123
        assert(not D._validate_device(dev))
      end)

      it("is not required", function()
        dev.implementation = nil
        assert(D._validate_device(dev))
      end)

      it("defaults to homie.lua version", function()
        dev.implementation = nil
        assert(D._validate_device(dev))
        assert.equal("homie.lua " .. D._VERSION, dev.implementation)
      end)

      it("appends homie.lua version", function()
        assert(D._validate_device(dev))
        assert.equal("my device, homie.lua " .. D._VERSION, dev.implementation)
      end)

    end)

    it("$nodes is required", function()
      dev.nodes = nil
      assert(not D._validate_device(dev))
    end)

  end)



  describe("Device instantiation", function()

    local dev

    before_each(function()
      -- set to something valid before each test
      dev = {
        domain = "not-homie",
        id = "123",
        uri = "mqtts://mqtt.broker.com",
        -- homie properties
        homie = "4.0.0",
        name = "device name",
        extensions = "",
        implementation = "my device",
        broadcast = {
          ["not-homie/$broadcast/alerts"] = function() end
        },
        nodes = {
          nodeid = {
            name = "thermostat",
            type = "horstmann",
            properties = {
              propid = {
                name = "setpoint",
                datatype = "float",
                format = "1:100",
                settable = true,
                retained = true,
                unit = "°C",
              }
            }
          }
        }
      }
    end)


    it("succeeds with a valid device", function()
      D.new(dev)
    end)

    it("fails with colon-style call", function()
      assert.has.error(function()
        D:new(dev)
      end, "do not call 'new' with colon-notation")
    end)

    it("opts must be a table", function()
      assert.has.error(function()
        D.new(123)
      end, "expected 'opts' to be a table")
    end)

    it("super property is the class", function()
      assert(D.new(dev).super == D, "Expected 'super' to be the Device class")
    end)

    describe("__init()", function()

      it("domain property validation", function()
        assert.has.no.error(function()
          dev.broadcast = nil
          dev.domain = "hello"  -- valid
          D.new(dev)
        end)

        assert.has.error(function()
          dev.domain = "-hello"  -- invalid
          D.new(dev)
        end)

        assert.has.no.error(function()
          dev.domain = nil  -- defaults to "homie"
          D.new(dev)
        end)
        assert.equal("homie", dev.domain)

        assert.has.error(function()
          dev.domain = 123  -- must be a string
          D.new(dev)
        end)
      end)

      it("id property validation", function()
        dev.broadcast = nil

        assert.has.no.error(function()
          dev.id = "some-id"  -- valid
          D.new(dev)
        end)

        assert.has.error(function()
          dev.id = "-bad-id-"  -- invalid
          D.new(dev)
        end)

        assert.has.no.error(function()
          dev.id = nil  -- defaults to "homie.lua-xxxxxx"
          D.new(dev)
        end)
        assert.equal("homie-lua-", dev.id:sub(1,10))

        assert.has.error(function()
          dev.id = 123  -- must be a string
          D.new(dev)
        end)
      end)

      describe("broadcast topics", function()

        it("topic get validated", function()
          assert.has.error(function()
            -- add domain non-matching
            dev.broadcast[dev.domain.."x/$broadcast/#"] = function() end
            D.new(dev)
          end)
        end)

        it("handler gets 'self' injected", function()
          local bt = dev.domain.."/$broadcast/#"
          local delivered
          dev.broadcast[bt] = function(...)
            delivered = { n = select("#", ...), ... }
          end
          assert(D.new(dev))
          local msg = {}
          local mqtt_client = dev.mqtt
          mqtt_client.acknowledge = function() return true end
          -- call handler with parameters as done by the MQTT client
          -- (calling them all, since we don't know order)
          for i, matcher in ipairs(dev.broadcast_match) do
            matcher.handler(msg, mqtt_client)
          end
          assert.is.table(delivered)
          assert.equal(dev, delivered[1])
          assert.equal(msg, delivered[2])
          assert.equal(2, delivered.n)
        end)

        it("handler acknowledges received message", function()
          local bt = dev.domain.."/$broadcast/#"
          dev.broadcast[bt] = function() end
          assert(D.new(dev))
          local msg = {}
          local mqtt_client = dev.mqtt
          function mqtt_client:acknowledge(ackmsg)
            assert.equals(msg, ackmsg)
            return true
          end
          -- call handler with parameters as done by the MQTT client
          dev.broadcast_match[1].handler(msg, mqtt_client)
        end)

      end)

    end)

  end)

end)
