--- Homie device implementation.
-- This consists of a `Device` instance which can contain `Node` instances, which
-- in turn can hold `Property` instances.
--
-- The device implementation will take care of homie related specifics.


local mqtt = require "mqtt"
local stringx = require "pl.stringx"
local pl_utils = require "pl.utils"
local log = require("logging").defaultLogger()
local Semaphore = require "copas.semaphore"
local copas = require "copas"
local utils = require "homie.utils"

-- Node implementation ---------------------------------------------------------
local Node = {}
Node.__index = Node

--- The node id, as it appears in the MQTT topic (string, read-only).
-- @field Node.id

--- The ancestor class (read-only). Usefull when overriding methods, and needing access to
-- the original methods.
-- @field Node.super

--- The owning `Device` of the Node (read-only).
-- @field Node.device

--- The name of the Node (string, read-only).
-- @field Node.name

--- The type of the Node (string, read-only).
-- @field Node.type

--- Hash-table with the Node's properties indexed by `Property.id` (read-only).
-- @field Node.properties



-- Property implementation --------------------------------------------------------
local Property = {}
Property.__index = Property

--- The name of the property (string, read-only).
-- @field Property.name

--- Is the property a `retained` value? (boolean, read-only)
-- @field Property.retained

--- Is the property a `settable` value? (boolean, read-only)
-- @field Property.settable

--- The value of the property, do not use. Please use `Property:get` and `Property:set` to
-- read/write the value.
-- @field Property.value

--- The owning `Device` of the property (read-only).
-- @field Property.device

--- The owning `Node` of the property (read-only).
-- @field Property.node

--- The MQTT topic for the property (string, read-only).
-- @field Property.topic

--- The property datatype (string, read-only).
-- @field Property.datatype

--- The property format (string, read-only).
-- @field Property.format

--- The property unit (string, read-only).
-- @field Property.unit

--- The property id, as it appears in the MQTT topic (string, read-only).
-- @field Property.id

--- The ancestor class (read-only). Usefull when overriding methods, and needing access to
-- the original methods.
-- @field Property.super


--- Gets the current value.
--
-- *NOTE*: during initialization of a device this can return `nil`!
-- @return the (unpacked) value
-- @see Property:unpack
function Property:get()
  return self.value
end


--- Called when remotely setting the value, through the MQTT topic.
-- There should be no need to override this method.
-- This executes: `Property:unpack`, `Property:validate`, `Property:set`, in that order.
-- Logs an error if something is wrong, and doesn't change the value in that case.
-- @tparam string pvalue string, the packed value as received.
-- @return `true` or `nil+err`
-- @see Property:set
function Property:rset(pvalue)
  if self.device.state == self.device.states.init then
    -- device is in init phase, so we might be restoring state
    if not self.retained then
      -- if prop is non-retained ignore incoming values while the device is still
      -- in "init" phase.
      log:debug("[homie] rset: skipping non-retained property in init phase '%s'", self.topic)
      return true
    end

    -- despite maybe not being 'settable' we still restore state here in init phase

  else
    -- not in init phase, so operational, block setting attempt if not settable
    if not self.settable then
      log:warn("[homie] rset: attempt to set a non-settable property '%s' (ignoring)",
              self.topic)
      return nil, "property is not settable"
    end
  end

  local value, err = self:unpack(pvalue)
  if err then -- note: check err, not value!
    log:warn("[homie] rset: remote device tried setting '%s' with a bad value that failed unpacking: %s",
            self.topic, err)
    return nil, "bad value"
  end

  local ok, err = self:validate(value)
  if not ok then
    log:warn("[homie] rset: remote device tried setting '%s' with a bad value: %s",
            self.topic, err)
    return nil, "bad value"
  end

  log:debug("[homie] rset: setting '%s = %s'", self.topic, pvalue)
  self:set(value, true)
  return true
end


do
  local unpackers
  unpackers = {
    string = function(prop, value)
      return value
    end,

    integer = function(prop, value)
      if value:match("^%-?[%de]+$") then
        local v = tonumber(value)
        if v then
          return v
        end
      end
      return nil, ("bad integer value: '%s'"):format(value)
    end,

    float = function(prop, value)
      if value:match("^%-?[0-9%.e]+$") then
        local v = tonumber(value)
        if v then
          return v
        end
      end
      return nil, ("bad float value: '%s'"):format(value)
    end,

    percent = function(prop, value)
      local v = unpackers.float(prop, value)
      if not v then
        return nil, ("bad percent value: '%s'"):format(value)
      end
      return v
    end,

    boolean = function(prop, value)
      if value == "true" or value == "false" then
        return value == "true"
      end
      return nil, ("bad boolean value: '%s'"):format(value)
    end,

    enum = function(prop, value)
      return value
    end,

    color = function(prop, value)
      local v = { value:match("^(%d+),(%d+),(%d+)$") }
      if not v[1] then
        return nil, ("bad color value: '%s'"):format(value)
      end
      if prop.format == "hsv" then
        return { h = tonumber(v[1]), s = tonumber(v[2]), v = tonumber(v[3]) }
      else
        return { r = tonumber(v[1]), g = tonumber(v[2]), b = tonumber(v[3]) }
      end
    end,

    datetime = function(prop, value)
      -- TODO: implement
    end,

    duration = function(prop, value)
      -- "PThHmMsS"
      if value:sub(1,2) == "PT" then
        value = value:sub(3,-1)
        local h = value:match("^([^H]+)H")
        if h then
          value = value:sub(#h+2, -1)
          h = tonumber(h)
        else
          h = 0
        end

        local m = value:match("^([^M]+)M")
        if m then
          value = value:sub(#m+2, -1)
          m = tonumber(m)
        else
          m = 0
        end

        local s = value:match("^([^S]+)S")
        if s then
          value = value:sub(#s+2, -1)
          s = tonumber(s)
        else
          s = 0
        end

        if value == "" and h and m and s then
          return h*60*60 + m*60 + s
        end
      end
      return false, ("bad duration value: '%s'"):format(value)
    end,
  }
  --- Deserializes a value received over MQTT.
  -- Override in case of (de)serialization needs.
  --
  -- *NOTE*: check return values!! `nil` is a valid value, so check 2nd return value for errors.
  -- @tparam string value string value to unpack/deserialize
  -- @return any type of value (including `nil`), returns an error string as second value in case of errors.
  -- @see Property:unpack
  function Property:unpack(value)
    return unpackers[self.datatype](self, value)
  end
end


do
  local validators

  local function check_min_max(prop, value)
    if not prop.format then
      return true
    end

    local min, max = prop.format:match("^([^:]+):([^:]+)$")
    min = tonumber(min)
    max = tonumber(max)
    return value >= min and value <= max
  end

  validators = {
    string = function(prop, value)
      if type(value) == "string" then
        return true
      end
      return false, ("value is not of type string, got: '%s' (%s)"):format(tostring(value), type(value))
    end,

    integer = function(prop, value)
      if type(value) == "number" and
          math.floor(value) == value and
          check_min_max(prop, value) then
        return true
      end
      return false, ("value is not an integer matching format '%s', got: '%s' (%s)"):
                    format(tostring(prop.format), tostring(value), type(value))
    end,

    float = function(prop, value)
      if type(value) == "number" and check_min_max(prop, value) then
        return true
      end
      return false, ("value is not a float matching format '%s', got: '%s' (%s)"):
                    format(tostring(prop.format), tostring(value), type(value))
    end,

    percent = function(prop, value)
      if type(value) == "number" and check_min_max(prop, value) then
        return true
      end
      return false, ("value is not a percentage matching format '%s', got: '%s' (%s)"):
                    format(tostring(prop.format), tostring(value), type(value))
    end,

    boolean = function(prop, value)
      -- using Lua falsy/truthy, no hard boolean checks
      return true
    end,

    enum = function(prop, value)
      if type(value) ~= "string" or value == "" or value:find(",") then
        return false, ("value must be a non-empty string, and may not contain ',', got: '%s' (%s)"):
                      format(tostring(value), type(value))
      end
      if (","..prop.format..","):find(","..value..",", 1, true) then
        return true
      end
      return false, ("value '%s' not found in enum list: %s"):
                    format(tostring(value), prop.format)
    end,

    color = function(prop, value)
      if type(value) ~= "table" then
        return false, "value must be a table type, got: "..type(value)
      end
      local v
      if prop.format == "hsv" then
        v = { value.h, value.s, value.v }
      else
        v = { value.r, value.g, value.b }
      end
      if type(v[1]) ~= "number" or type(v[2]) ~= "number" or type(v[3]) ~= "number" or
         math.floor(v[1]) ~= v[1] or math.floor(v[2]) ~= v[2] or math.floor(v[3]) ~= v[3] then
        return false, ("individual color values must be integer number type, got: %s, %s, %s"):
                      format(tostring(v[1]), tostring(v[2]), tostring(v[3]))
      end
      if prop.format == "hsv" then
        if v[1] < 0 or v[1] > 360 then
          return false, "hsv value h must be from 0 to 360, got: "..tostring(v[1])
        end
        if v[2] < 0 or v[2] > 100 or v[3] < 0 or v[3] > 100 then
          return false, ("hsv values s and v must be from 0 to 100, got: %s, %s"):
                        format(tostring(v[2]), tostring(v[3]))
        end
      else
        if v[1] < 0 or v[1] > 255 or v[2] < 0 or v[2] > 255 or v[3] < 0 or v[3] > 255 then
          return false, ("rgb values must be from 0 to 255, got: %s, %s, %s"):
                        format(tostring(v[1]), tostring(v[2]), tostring(v[3]))
        end
      end
      return true
    end,

    datetime = function(prop, value)
      -- TODO: implement
    end,

    duration = function(prop, value)
      if type(value) == "number" and value >= 0 then
        return true
      end
      return false, ("value is not a valid duration, got: %s (%s)"):
                    format(tostring(value), type(value))
    end,
  }

  --- Checks an (unpacked) value. Base implementation
  -- only checks format. Override for more validation checks.
  -- @param value the (unpacked) value to validate
  -- @return `true` if ok, `nil+err` if not.
  function Property:validate(value)
    return validators[self.datatype](self, value)
  end
end


--- Local application code can set a value through this method.
-- Default just calls `Property:update`. Implement actual changing device behaviour here
-- by overriding. When overriding, it should always end by calling `Property:update`.
-- @param value the (unpacked) value to set
-- @tparam[opt=false] bool remote if truthy, the change came in over MQTT (via `Property:rset`)
-- @return truthy on success or falsy+error
function Property:set(value, remote)
  return self:update(value)
end


do
  local packers
  packers = {
    string = function(prop, value)
      return value
    end,

    integer = function(prop, value)
      return tostring(value)
    end,

    float = function(prop, value)
      return tostring(value)
    end,

    percent = function(prop, value)
      return tostring(value)
    end,

    boolean = function(prop, value)
      return tostring(not not value)
    end,

    enum = function(prop, value)
      return value
    end,

    color = function(prop, value)
      return prop.format == "hsv" and
        ("%d,%d,%d"):format(value.h, value.s, value.v) or
        ("%d,%d,%d"):format(value.r, value.g, value.b)
    end,

    datetime = function(prop, value)
      -- TODO: implement
    end,

    duration = function(prop, value)
      local s, m, h
      h = math.floor(value/(60 * 60))
      value = value - h * 60 * 60
      m = math.floor(value/60)
      s = value - m * 60

      local ret = ""
      if h > 0 then
        ret = ret .. tonumber(h).."H"
      end
      if m > 0 then
        ret = ret .. tonumber(m).."M"
      end
      if s > 0 then
        ret = ret .. tonumber(s).."S"
      end
      if ret == "" then
        ret = "0S"
      end
      return "PT"..ret
    end,
  }
  --- Serializes a value to send over MQTT.
  -- Override in case of (de)serialization needs. Since this method is only called after
  -- `Property:validate`, it should always succeed. Any reason for not succeeding should
  -- be handled when validating.
  -- @param value the unpacked value to be serialized into a string
  -- @return packed value (string), or nil+err on failure
  -- @see Property:unpack
  function Property:pack(value)
    return packers[self.datatype](self, value)
  end
end


--- Compares 2 (unpacked) values for equality. If old and new values are equal,
-- no updates need to be transmitted. If values are unpacked into complex structures
-- override this to check for equality.
-- @param value1 the (unpacked) value to compare with the 2nd
-- @param value2 the (unpacked) value to compare with the 1st
-- @return boolean
function Property:values_same(value1, value2)
  if self.datatype == "boolean" then
    value1 = not not value1
    value2 = not not value2
  end

  if type(value1) ~= type(value2) then
    return false
  end

  if self.datatype == "color" then
    if self.format == "hsv" then
      return value1.h == value2.h and value1.s == value2.s and value1.v == value2.v
    else
      return value1.r == value2.r and value1.g == value2.g and value1.b == value2.b
    end
  end

  return value1 == value2
end

--- Validates the value and updates `Property.value`. Will send the MQTT update message. No need to
-- override.
--
-- *NOTE*: if the property is NOT 'retained', then `force` will always be set to `true`.
-- @param value the new (unpacked) value to set
-- @tparam[opt=false] bool force set to truthy to always send an update, even if unchanged.
-- @return true, or nil+error
function Property:update(value, force)
  if self.datatype == "boolean" then
    value = not not value
  end

  local ok, err = self:validate(value)
  if not ok then
    return nil, err
  end

  if not self.retained then
    -- if not retained then always update
    force = true
  end

  if not force then
    if self:values_same(value, self:get()) then
      return true -- no need for updates
    end
  end

  local pvalue, err = self:pack(value)
  if not pvalue then
    return nil, err
  end

  self.value = value

  -- craft mqtt packet and send it
  return self.device:send_property_update(self.topic, pvalue, self.retained)
end


-- Device implementation -------------------------------------------------------

--- Enum table with possible values for `Device.state`.
-- @field Device.states

--- Current device status, see `Device.states` (string, read-only). Use `Device:set_state`
-- to change the value.
-- @field Device.state

--- Homie version implemented by `Device` (string, read-only).
-- @field Device.homie

--- The name of the device (string, read-only).
-- @field Device.name

--- The homie extensions supported by the device (string, read-only).
-- @field Device.extensions

--- The homie implementation identifier (string, read-only).
-- @field Device.implementation

--- Hash-table with the Device's nodes indexed by `Node.id` (read-only).
-- @field Device.nodes

--- The homie domain to use (string, read-only).
-- @field Device.domain

--- The device base-topic; domain + device id (string, read-only).
-- @field Device.base_topic

--- The device id, as it appears in the MQTT topic (string, read-only).
-- @field Device.id

--- Recover device state from the broker? (false|number, read-only). If a number
-- then it is the time (in seconds) to wait for all state to be returned by the
-- broker (start-up delay).
-- @field Device.broker_state

--- Hash-table with broadcast handler functions, indexed by their broadcast topic (read-only).
-- The keys (broadcast-topic) will be updated to be fully qualified.
-- @field Device.broadcast

--- The underlying `luamqtt` device used for the MQTT communications (read-only).
-- @field Device.mqtt

--- The mqtt-broker uri to connect to (string, read-only).
-- @field Device.uri

--- TODO:
-- @field Device.send_updates



local Device = {}
Device.__index = Device
require("homie.meta")(Device)

log:info("[homie] loaded homie.lua library; Device (version %s)", Device._VERSION)

-- device states enumeration
Device.states = setmetatable({
  init = "init",
  ready = "ready",
  disconnected = "disconnected",
  sleeping = "sleeping",
  lost = "lost",
  alert = "alert",
}, {
  __index = function(self, key)
    error("'"..tostring(key).."' is not a valid device-state")
  end,
})

Device.datatypes = {
  string = "string",
  integer = "integer",
  float = "float",
  percent = "percent",
  boolean = "boolean",
  enum = "enum",
  color = "color",
  datetime = "datetime",
  duration = "duration",
}

-- validate homie topic segment
-- @param segment string the segment to validate
-- @param attrib if truthy then validate it as a attribute, starting with a $
-- @return valid segment, or nil+err
local function validate_segment(segment, attrib)
  if type(segment) ~= "string" then
    return nil, "expected sgement to be a string"
  end
  local t = segment
  if attrib then
    if t:sub(1,1) ~= "$" then
      return nil, "attributes must start with a '$'"
    end
    t = t:sub(2,-1)
  end
  if t:match("^[a-z0-9]+[a-z0-9%-]*$") and t:sub(-1,-1) ~= "-" then
    return segment
  end
  return nil, ("invalid Homie topic segment; '%s', only: a-z, 0-9 and '-' (not start nor end with '-')"):format(segment)
end

-- validates a broadcast topic, and fully qualifies it.
-- @param self the device object
-- @param topic
-- @return the fully qualified topic, or nil+err
local function validate_broadcast_topic(self, topic)
  if topic:find("/$broadcast/", 1, true) then
    -- is fully qualified, so must match domain
    local start = self.domain.."/$broadcast/"
    if topic:sub(1, #start) ~= start then
      return nil, ("broadcast topic '%s' doesn't match device domain '%s/$broadcast/'"):format(topic, self.domain)
    end
    return topic
  end

  -- relative, so prefix with domain
  if topic:sub(1,1) == "/" then
    return self.domain.."/$broadcast" .. topic
  end
  return self.domain.."/$broadcast/" .. topic
end

-- wraps a broadcast handler function.
-- does the acknowledge, calls the handler while injuecting 'self' (the device).
local function create_broadcast_handler(device, handler)
  return function(msg)
    local ok, err = device.mqtt:acknowledge(msg)
    if not ok then
      log:error("[homie] failed to acknowledge broadcast message: %s", err)
    end
    return handler(device, msg)
  end
end

-- validates a single property
-- @param datatype string, data-type, MUST be valid, not validated here
-- @param format string the format string to validate for the datatype
-- @return format string, or nil + err
local function validate_format(datatype, format)
  if type(format) ~= "string" then
    return nil, "expected `property.format` to be a string"
  end

  -- we're also allowing percent dattype here
  if datatype == "integer" or datatype == "float" or datatype == "percent" then
    local min, max = pl_utils.splitv(format, ":", 2)
    if not min or not max then
      return nil, "bad min:max format specified"
    end
    local min = tonumber(min)
    if not min then
      return nil, "bad min:max format specified"
    end
    local max = tonumber(max)
    if not max then
      return nil, "bad min:max format specified"
    end
    if min > max then
      return nil, "bad min:max format specified"
    end

  elseif datatype == "enum" then
    local enum = stringx.split(format, ",")
    for i, val in ipairs(enum) do
      if val == "" then
        return nil, "enum format cannot have empty strings"
      end
      if stringx.strip(val) ~= val then
        return nil, "enum format cannot have leading/trailing whitespace"
      end
    end


  elseif datatype == "color" then
    if format ~= "hsv" and format ~= "rgb" then
      return nil, ("format '%s' is not valid for datatype '%s'"):format(format, datatype)
    end

  else
    return nil, ("format '%s' is not valid for datatype '%s'"):format(format, datatype)
  end

  return format
end

-- validates a single property
-- @param prop property table to verify
-- @return property table, or nil + err
local function validate_property(prop)
  if type(prop) ~= "table" then
    return nil, "expected 'property' to be a table"
  end

  if type(prop.name) ~= "string" or #prop.name < 1 then
    return nil, "expected `property.name` to be a string of at least 1 character"
  end

  if type(prop.datatype) ~= "string" or Device.datatypes[prop.datatype] == nil then
    return nil, "expected `property.datatype` to be a string and a valid datatype"
  end

  if prop.settable ~= nil then
    if type(prop.settable) ~= "boolean" then
      return nil, "expected `property.settable` to be a boolean if given"
    end
  else
    prop.settable = false
  end

  if prop.retained ~= nil then
    if type(prop.retained) ~= "boolean" then
      return nil, "expected `property.retained` to be a boolean if given"
    end
  else
    prop.retained = true
  end

  if prop.unit ~= nil then
    if type(prop.unit) ~= "string" or #prop.unit < 1 then
      return nil, "expected `property.unit` to be a string of at least 1 character if given"
    end
  end

  if prop.format ~= nil or prop.datatype == "color" or prop.datatype == "enum" then
    local ok, err = validate_format(prop.datatype, prop.format)
    if not ok then
      return nil, err
    end
  end

  -- percent special case
  if prop.datatype == "percent" then
    if prop.unit == nil then
      prop.unit = "%"
    else
      if prop.unit ~= "%" then
        return nil, "expected `property.unit` to be '%' for datatype 'percent', if given"
      end
    end
  end

  if prop.default ~= nil then
    local ok, err = prop:validate(prop.default)
    if not ok then
      return nil, "bad default value: " .. err
    end
  end

  for key in pairs(prop) do
    if not ({
        name = true,
        datatype = true,
        settable = true,
        retained = true,
        format = true,
        unit = true,
        id = true,
        node = true,
        device = true,
        topic = true,
        super = true,
        default = true,
        unpack = true,
        set = true,
        validate = true,
        values_same = true,
        pack = true,
      })[key] then
      return nil, "property contains unknown key '" .. tostring(key) .. "'"
    end
  end

  return prop
end


-- validates a properties table
-- @param props hashtable, property table by property-id
-- @return properties table or nil+err
local function validate_properties(props, node, device)
  if type(props) ~= "table" then
    return nil, "expected 'properties' to be a table"
  end

  for propid, prop in pairs(props) do
    local ok, err
    ok, err = validate_segment(propid)
    if not ok then
      return nil, "bad property-id: " .. err
    end

    if type(prop) ~= "table" then
      return nil, "expected 'property' to be a table"
    end

    -- add the id, node and device, create topic, and make an object of type Property
    prop.id = propid
    prop.node = assert(node, "node parameter is missing")
    prop.device = assert(device, "device parameter is missing")
    prop.topic = device.base_topic .. node.id .. "/" .. propid
    setmetatable(prop, Property)
    prop.super = Property

    ok, err = validate_property(prop)
    if not ok then
      return nil, "bad property '" .. propid .. "': " .. err
    end
  end

  return props
end


-- validates a single node
-- @param node node table to verify
-- @return node, or nil + err
local function validate_node(node, device)
  if type(node) ~= "table" then
    return nil, "expected 'node' to be a table"
  end

  if type(node.name) ~= "string" or #node.name < 1 then
    return nil, "expected `node.name` to be a string of at least 1 character"
  end

  if type(node.type) ~= "string" or #node.type < 1 then
    return nil, "expected `node.type` to be a string of at least 1 character"
  end

  if type(node.properties) ~= "table" then
    return nil, "expected `node.properties` to be a table"
  end

  local ok, err = validate_properties(node.properties, node, device)
  if not ok then
    return nil, err
  end

  for key in pairs(node) do
    if not ({
        name = true,
        type = true,
        properties = true,
        id = true,
        device = true,
        super = true,
      })[key] then
      return nil, "node contains unknown key '" .. tostring(key) .. "'"
    end
  end

  return node
end


-- validates a nodes table
-- @param nodes hashtable, nodes table by nodeid
-- @return nodes table or nil+err
local function validate_nodes(nodes, device)
  if type(nodes) ~= "table" then
    return nil, "expected 'nodes' to be a table"
  end

  for nodeid, node in pairs(nodes) do
    local ok, err
    ok, err = validate_segment(nodeid)
    if not ok then
      return nil, "bad nodeid: " .. err
    end

    if type(node) ~= "table" then
      return nil, "expected 'node' to be a table"
    end

    -- add the id and device, make an object of type Node
    node.id = nodeid
    node.device = assert(device, "device parameter is missing")
    setmetatable(node, Node)
    node.super = Node

    ok, err = validate_node(node, device)
    if not ok then
      return nil, "bad node '" .. nodeid .. "': " .. err
    end
  end

  return nodes
end


-- validates a device
-- @param device device table to verify
-- @return device, or nil + err
local function validate_device(device)
  if type(device) ~= "table" then
    return nil, "expected 'device' to be a table"
  end

  if device.homie ~= "4.0.0" then
    return nil, "expected `device.homie` to be a string '4.0.0'"
  end

  if type(device.name) ~= "string" or #device.name < 1 then
    return nil, "expected `device.name` to be a string of at least 1 character"
  end

  if device.state ~= nil then
    return nil, "expected `device.state` to be 'nil', since it is managed by the homie library"
  end

  if device.extensions ~= "" then
    return nil, "expected `device.extensions` to be an empty string, since we do not support any yet"
  end

  if type(device.nodes) ~= "table" then
    return nil, "expected `device.nodes` to be a table"
  end

  if device.implementation == nil then
    device.implementation = ""
  end
  if type(device.implementation) ~= "string" then
    return nil, "expected `device.implementation` to be a string if given"
  end
  if device.implementation == "" then
    device.implementation = "homie.lua " .. Device._VERSION
  else
    device.implementation = device.implementation .. ", homie.lua " .. Device._VERSION
  end

  local ok, err = validate_nodes(device.nodes, device)
  if not ok then
    return nil, err
  end

  return device
end


--- Instantiate a new Homie device.
-- @tparam table[opt={}] opts Options table to create the instance from.
-- @tparam[opt="homie/"] string opts.domain base domain
-- @tparam[opt] string opts.id device id. Defaults to `homie-lua-xxxxxxx` randomized.
-- @return new device object.
function Device.new(opts, empty)
  if empty ~= nil then error("do not call 'new' with colon-notation", 2) end
  assert(type(opts) == "table", "expected 'opts' to be a table")
  local self = setmetatable(opts, Device)
  self.super = Device
  self:__init()
  return self
end

--- Initializer, called upon instantiation.
function Device:__init()
  -- domain: Base topic
  if self.domain == nil then
    self.domain = "homie"
  end
  self.domain = assert(validate_segment(self.domain))

  -- id: Homie device ID
  if self.id == nil then
    self.id = ("homie-lua-%07x"):format(math.random(1, 0xFFFFFFF))
  end
  self.id = assert(validate_segment(self.id))

  -- base_topic
  self.base_topic = self.domain .. "/" .. self.id .. "/"

  -- broker state (recover state from broker on initialization)
  if self.broker_state == nil then
    self.broker_state = false
  end
  if self.broker_state ~= false then
    assert(type(self.broker_state) == "number" and self.broker_state > 0,
          "expected 'broker_state' to be false, or a number greater than 0")
  end

  -- broadcast subscriptions
  local bc = self.broadcast or {}
  self.broadcast = {}
  self.broadcast_match = {}
  assert(type(bc) == "table", "expected 'broadcast' to be a table")
  for topic, handler in pairs(bc) do
    topic = assert(validate_broadcast_topic(self, topic))
    handler = assert(type(handler) == "function" and handler, "expected broadcast handler to be a function")

    self.broadcast[topic] = true
    self.broadcast_match[#self.broadcast_match + 1] = {
      pattern = mqtt.compile_topic_pattern(topic),
      handler = create_broadcast_handler(self, handler), -- inject 'self' as first parameter on call backs
    }
  end

  -- Validate device and nodes
  assert(validate_device(self))

  -- generate subscriptions for settable and own properties
  self.settable_subscriptions = {}
  self.own_topic_subscriptions = {}
  for nodeid, node in pairs(self.nodes) do
    for propid, prop in pairs(node.properties) do
      -- own device topics
      local handler = function(packet)
        -- handler only used during "init" stage, to collect stored state from
        -- the broker. Acknowledge and set initial value.
        self.mqtt:acknowledge(packet)
        log:info("[homie] restoring state from broker for '%s'", prop.topic)
        prop.rset(prop, packet.payload)
      end
      self.own_topic_subscriptions[prop.topic] = handler

      -- handlers for settable topics
      if prop.settable then
        -- TODO: should we subscribe to non-settable props as well?
        -- the rset method will block the updates, and provide a nice log message
        -- so that might provide better user feedback.
        local topic = prop.topic .. "/set"
        local handler = function(packet)
          -- acknowledge packet and invoke property-setter
          self.mqtt:acknowledge(packet)
          prop.rset(prop, packet.payload)
        end
        self.settable_subscriptions[topic] = handler
      end
    end
  end

  -- Instantiate mqtt device
  self.mqtt = mqtt.client {
    uri = self.uri,
    id = self.id,
    -- TODO: fix clean session stuff
    clean = false, --true,  -- only for first connect, after "init" phase to false
    reconnect = true,
    will = {
      topic = self.base_topic .. "$state",
      payload = self.states.lost,
      qos = 1,
      retain = true,
    }
  }

  -- set initial state
  self.state = nil
end


function Device:message_handler(msg)
  --print("message: ", require("pl.pretty").write(msg))
  local handler

  if self.accept_updates then
    handler = self.settable_subscriptions[msg.topic]
  end

  if not handler and self.state == self.states.init then
    -- check our own topics to restore state from broker
    handler = self.own_topic_subscriptions[msg.topic]
  end

  if handler then
    return handler(msg)
  else
    -- not a property, so try the broadcasts
    for _, patt in ipairs(self.broadcast_match) do
      if msg.topic:match(patt.pattern) then
        patt.handler(msg)
        handler = true
      end
    end
  end

  if not handler then
    log:warn("[homie] received unknown topic: %s", msg.topic)
  end
end


--- Method to verify initial values. Can be used to verify values received from
-- broker, or to just initialize values. When this returns the values must be in
-- a consistent state. This is only called on device start, not on reconnects.
-- Default behaviour is to keep existing state
function Device:verify_initial_values()
  -- override in instances
  -- TODO: this should have an equivalent on the `node` objects
  -- and the default should be to call that method on every node (if present)
  for nodeid, node in pairs(self.nodes) do
    for propid, prop in pairs(node.properties) do
      local v = prop:get()
      if v == nil then v = prop.default end
      local ok, err = prop:validate(v)
      if not ok then
        log:error("[homie] no acceptable value available for property '%s': %s", prop.topic, err)
      else
        prop:set(v)
      end
    end
  end
end


-- Push every topic we have including device description etc, to the broker
function Device:publish_device()
  local topics = {}
  topics[self.base_topic .. "$homie"] = self.homie
  topics[self.base_topic .. "$name"] = self.name
  --topics[self.base_topic .. "$state"] =  -- not publishing this here
  topics[self.base_topic .. "$extensions"] = "none" -- an empty string is not stored on MQTT broker
  topics[self.base_topic .. "$implementation"] = self.implementation
  local nds = {}
  for nodeid, node in pairs(self.nodes) do
    nds[#nds+1] =  nodeid
    topics[self.base_topic .. nodeid .."/$name"] = node.name
    topics[self.base_topic .. nodeid .."/$type"] = node.type
    local props = {}
    for propid, prop in pairs(node.properties) do
      props[#props+1] = propid
      topics[prop.topic.."/$name"] = prop.name
      topics[prop.topic.."/$datatype"] = prop.datatype
      topics[prop.topic.."/$format"] = prop.format
      topics[prop.topic.."/$settable"] = tostring(prop.settable)
      topics[prop.topic.."/$retained"] = tostring(prop.retained)
      topics[prop.topic.."/$unit"] = prop.unit
      if prop.retained then
        topics[prop.topic] = prop:pack(prop:get())
      end
    end
    topics[self.base_topic .. nodeid .."/$properties"] = table.concat(props,",")
  end
  topics[self.base_topic .. "$nodes"] = table.concat(nds, ",")

  return utils.publish_topics(self.mqtt, topics, 60)
end


--- Send an MQTT message with the value update.
-- @tparam string topic to post to
-- @tparam string pvalue the packed/serialized value to send over the wire
-- @tparam[opt] boolean retained the retain flag to use when sending
-- @return truthy, or falsy+error
function Device:send_property_update(topic, pvalue, retained)
  if not self.send_updates then
    -- in init phase we do not update
    return true
  end

  -- non-retained messages should be dropped if not connected
  -- retained ones should be queued, and coalesced.
  -- TODO: implement, for now just publish

  return self.mqtt:publish {
    topic = topic,
    payload = pvalue,
    qos = 1,
    retain = retained,
    -- callback = function(...)
      -- TODO: implement, but what? timeout reporting?
    -- end
  }
end


--- Sets a device state. Waits for confirmation.
-- @tparam string newstate any of the `Device.states` constants.
-- @tparam[opt=30] number timeout timeout in seconds.
-- @return success+err
function Device:set_state(newstate, timeout)
  timeout = timeout or 30
  local s = Semaphore.new(1, 0, timeout)

  log:info("[homie] Setting device state: '%s%s = %s' (was '%s')", self.base_topic, "$state", newstate, self.state)
  self.mqtt:publish {
    topic = self.base_topic .. "$state",
    payload = self.states[newstate],
    qos = 1,
    retain = true,
    callback = function()
      s:give(1)
    end,
  }

  local ok, err = s:take(1)
  if not ok then
    log:error("[homie] Failed setting device state '%s%s = %s', error: %s", self.base_topic, "$state", newstate, err)
  else
    self.state = newstate
  end

  return ok, err
end


function Device:connect_handler(connack)
  if connack.rc ~= 0 then
    return -- connection failed, exit and wait for reconnect
  end

  if self.state ~= self.states.init then
    -- we're reconnecting after a failure, overwrite 'will' with current state
    self:set_state(self.state)
    return -- exit here, not re-publishing everything
  end

  -- we're connected for the first time, so start initialization procedure
  local ok = self:set_state(self.states.init)
  if not ok then return end

  -- collect state from broker if set to
  if self.broker_state then
    local ok = utils.subscribe_topics(self.mqtt, self.own_topic_subscriptions, false, 60)
    if not ok then return end

    -- wait to receive all updates
    copas.pause(self.broker_state)

    -- unsubscribe from own topics, since by now we received the stored state from the broker
    local ok = utils.subscribe_topics(self.mqtt, self.own_topic_subscriptions, true, 60)
    if not ok then return end
  end

  -- verify initial values receieved, or overwrite values with read config from file etc
  self:verify_initial_values()

  -- Publish all topics
  self.send_updates = true
  self:publish_device(60)
  if not ok then
    self.send_updates = false
    return
  end

  -- subscribe to settable topics
  self.accept_updates = true
  local ok = utils.subscribe_topics(self.mqtt, self.settable_subscriptions, false, 60)
  if not ok then
    self.accept_updates = false
    self.send_updates = false
    return
  end

  -- set state to 'ready'
  local ok = self:set_state(self.states.ready)
  if not ok then
    self.accept_updates = false
    self.send_updates = false
    return
  end

  -- finalize init phase
  self.state = self.states.ready
  self.mqtt.opts.clean = false
end


--- Starts the device. Publishes the homie description topics and subscriptions,
-- recovers state from the broker if set to do so, and sets status to `ready`.
-- The device will set up keepalives, and will automatically reconnect if there is
-- a failure.
function Device:start()
  -- set initial state
  self.state = self.states.init
  self.send_updates = false
  self.accept_updates = false
  log:debug("[homie] starting homie device '%s'", self.id)

  self.mqtt:on {
    connect = function(connack)
      self:connect_handler(connack)
    end,
    message = function(msg)
      self:message_handler(msg)
    end,
  }

  require("mqtt.loop").add(self.mqtt)
end


--- Stops the device cleanly. Sets device state to `disconnected`.
function Device:stop()
  self:set_state(self.states.disconnected)
  self.mqtt:shutdown() -- disables any reconnects
end


if _G._TEST then
  -- export local functions for test purposes
  Device._validate_segment = validate_segment
  Device._validate_broadcast_topic = validate_broadcast_topic
  Device._validate_format = validate_format
  Device._validate_property = validate_property
  Device._validate_properties = validate_properties
  Device._validate_node = validate_node
  Device._validate_nodes = validate_nodes
  Device._validate_device = validate_device
  -- object metatables
  Device._Property = Property
  Device._Node = Node
end

return Device
