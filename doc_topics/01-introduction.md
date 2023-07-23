# 1. Introduction

## 1.1 Property updates

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
