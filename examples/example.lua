local copas = require "copas"
local Device = require "homie.device"
local log = require("logging").defaultLogger() -- https://github.com/lunarmodules/lualogging

local dev = {
  -- generic
  ----------

  -- URI to access the mqtt broker; mqtt(s)://user:pass@hostname:port
  uri = "mqtt://synology",

  -- homie base-domain (optional defaults to "homie")
  domain = "homie",


  -- Device options
  -----------------


  -- Whether or not to restore state from the mqtt broker.
  -- set to 'false' or number (optional, defaults to false).
  -- If set to a number the device will subscribe to its own topic values and
  -- then wait for the number of seconds to receive the state from the broker.
  -- Then it continues startup by calling the `verify_initial_values` method
  broker_state = 3, --false,


  -- This method is called in the "init" phase. After receiving the state from
  -- the broker (if set to, see `broker_state`). This method MUST ensure that
  -- all current values are consistent. After this method returns the device
  -- will be set to `ready`. The default implementation will set any property
  -- that didn't receive value restored from the broker to the value specified
  -- as `default` in the `properties` table below.
  verify_initial_values = function(self) -- self: the Homie-device object
    self.super.verify_initial_values(self) -- call ancestor method

    -- implement custom logic

  end,


  -- Homie device
  ---------------

  -- these are the standard homie device topics, see homie spec

  id = "mydevice1",  -- defaults to a random "homie-lua-xxxxx" value
  homie = "4.0.0", -- implemented homie version, must be "4.0.0" for now
  extensions = "", -- implemented homie extensions, must be "" for now
  name = "my light",
  broadcast = {
    -- hash-table of broadcast subscriptions, with handlers; either relative, or
    -- fully qualified topics. Examples:

    ["homie/$broadcast/alarms/smoke"] = function(homie_device, mqtt_msg)
      -- smoke was detected
    end,

    ["alarms/intruder"] = function(homie_device, mqtt_msg)
      -- this example will automatically be prefixed with "<domain>/$broadcast/".
      -- an intruder was detected
    end,
  },
  nodes = {

    tablelight = {  -- "tablelight" is the Node-id
      name = "Living room table lights",
      type = "a dimmable light",
      properties = {

        power = { -- "power" is the property-id
          name = "power",
          datatype = "boolean",
          -- optionals
          settable = true,
          retained = true,

          -- default value; see `verify_initial_values`
          default = false,

          -- 'unpack' handler.
          -- Will be used to unpack a value into a Lua format. The default
          -- implementation will unpack all standard Homie datatypes.
          -- For example; unpack a JSON payload.
          unpack = function(self, pvalue) -- self: property object, pvalue; packed value (string)
            -- return the unpacked value, stick to default behaviour.
            -- return nil+err for unpack errors
            return self.super.unpack(self, pvalue)
          end,

          -- 'set' handler.
          -- The handler called to set a value (a Lua type value).
          -- This is where the major logic of the implementation should be
          -- implemented. Must call `self:update` to effectuate the change
          set = function(self, value, remote) -- self: property object, value: unpacked Lua value
            log:info("Power set %s", tostring(value))
            local prop_output = self.node.properties.output
            local prop_bright = self.node.properties.brightness
            if value then
              local bright = prop_bright:get()
              if bright then -- during init, this can be nil
                prop_output:set(bright)
              end
            else
              prop_output:set(0)
            end

            self:update(value) -- update the value internally, and publish topic
          end,

          -- 'validate' handler.
          -- The handler called to validate a value (a Lua type value).
          -- Called twice: 1 before calling `set` in case the change comes in
          -- from a settable mqtt topic (external). 2 from the `update` method
          -- (after `set`).
          -- Validate the value to be valid. Return true or false+err.
          validate = function(self, value) -- self: property object, value: unpacked Lua value
            -- the default will perform standard Homie validations per "format" property.
            return self.super.validate(self, value)
          end,

          -- 'value_same' handler.
          -- Compares to (Lua type) values for equality. Returns true or false.
          -- If it returns `true` then the update will not be sent to the MQTT
          -- topic. Only values that actually differ will be posted.
          values_same = function(self, value1, value2) -- self: property object, value1/2: unpacked Lua value
            -- the default will perform standard Homie comparison
            return self.super.values_same(self, value1, value2)
          end,

          -- 'pack' handler.
          -- Will be used to pack a Lua value into a Homie format. The default
          -- implementation will pack all standard Homie datatypes.
          -- For example; pack a JSON payload into a Homie string type
          pack = function(self, value) -- self: property object, value: unpacked Lua value
            -- return the packed value, stick to default behaviour.
            -- return nil+err for pack errors
            return self.super.pack(self, value)
          end,

        },

        brightness = { -- "brightness" is the property-id
          name = "brightness",
          datatype = "percent",
          -- optionals
          settable = true,
          retained = true,
          format = "0:100",
          unit = "%",

          -- default value; see `verify_initial_values`
          default = 100,

          -- 'set' handler
          set = function(self, value, remote) -- self: property object, value: unpacked Lua value
            log:info("Brightness set %s", tostring(value))
            local prop_output = self.node.properties.output
            local prop_power = self.node.properties.power

            if value == 0 then
              -- turn power off, but do not change brightness value
              prop_power:set(false)
              return -- do not call 'update', we keep our value
            end

            if prop_power:get() then
              -- only if power is on, change the output value
              prop_output:set(value)
            end

            self:update(value) -- update the value internally, and publish topic
          end,
        },

        output = { -- "output" is the property-id
          name = "power output",
          datatype = "percent",
          -- optionals
          settable = false,
          retained = true,
          format = "0:100",
          unit = "%",

          -- default value; see `verify_initial_values`
          default = 0,

          -- 'set' handler
          set = function(self, value, remote) -- self: property object, value: unpacked Lua value
            log:info("Output set %s", tostring(value))

            -- implement actual device value setting to hardware here

            self:update(value) -- update the value internally, and publish topic
          end,
        },


        -- more properties can be added here...
      },
    },


    -- more nodes can be added here....
  }
}


copas.loop(function()
  Device.new(dev):start()
end)
