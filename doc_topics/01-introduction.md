# 1. Introduction

## 1.1 Property values

This is what the Lua representations look like (the 'unpacked' values);
- **string**: this is a Lua string value. Empty string values can be used, the library will take care of conversions when receiving/sending.
- **integer** & **float**: these are Lua numbers. The library will take care of rounding the values when setting the value (by the `validate` method).
- **boolean**: a Lua boolean true/false. The `validate` method will convert truthy/falsy values to a Lua `true`/`false` when setting a value.
- **enum**: this is a Lua string value.
- **color**: this is represented by a Lua table. With keys `r`, `g`, `b`, or `h`, `s`, `v`, or `x`, `y`, `z`. When receiving values only the received 3 keys will be present (the `validate` method will add the `z` value for the `xyz` format). Internally all 9 keys can be used. When transmitting, the value will be encoded based on the `format` precedence, and the first format that has all 3 keys set.
- **datetime**: todo
- **duration**: this is a Lua number, in seconds (with fractions)
- **json**: this is a Lua table. En/decoding is done via the `lua-cjson` library, and using that library arrays can be marked as such using the `array_mt` metatable. Validation is done using `lua-resty-ljsonschema` which implements draft 4 of the JSONSchema standardization effort.

## 1.2 Property updates

There are 2 entrypoints in the update flow;

1. an incoming MQTT topic from a remote Homie controller, entry via the `rset` method
2. the local application updating a value, entry via the `set` method

Values have 2 possible representations:

1. packed; the serialized values as they are send via MQTT
2. unpacked; the Lua version of the value, in unpacked state


method | description | usage
-|-|-
--> `Property:rset` | This is the entrypoint for remotely setting a value. | Do not use, will be called internally when a remote set is received.
`Property:unpack` | The received value is being unpacked. | Override if you need to unpack a custom format. But typically those should be encoded as json.
`Property:validate` | The received upacked value will be validated. | Override if you need to validate a custom format. But typically those should be encoded as json and validated with jsonschema.
--> `Property:set` | This is the entry-point for local application code to start an update. | Call to set a new target value for the property.
`Property:execute` | Local implementation, to effectuate any changes. | Override if setting values requires action on the behalf of the device, eg. turn on a light (property is settable). <br/>No need to override if just reporting a sensor value (property not settable), since the default implementation will just call `Property:update`.
`Property:update` | To be called from the `Property:execute` method whenever status updates should be send over the MQTT bus. | This should only be called from the `Property:execute` method's implementation
`Property:pack` | Serializes the value for transmission over an MQTT topic. | Override if you need to pack a custom format. But typically those should be encoded as json. <br/> **Note**: for json formats this can be used to ensure empty arrays are encoded as such and not as empty objects.
`Property:values_same`| This is not a separate step, but is invoked by `Property:update` to check if an update is really an update. If not, no updates will be send for retained properties. | Override if you need to compare a custom format for equality. <br/> **Note**: for json formats this can be used to compare arrays where order is not significant.
