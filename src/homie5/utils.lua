--- Generic utilities.

local copas = require "copas"
local now = require("socket").gettime
local Semaphore = require "copas.semaphore"
local Queue = require "copas.queue"
--local log = require("logging").defaultLogger()


local _M = {}


--- waits for a task to complete. Does exponential backoff while waiting.
-- @tparam function check should return true on completion
-- @tparam[opt=30] number timeout time out in seconds
-- @tparam[opt=0.010] number init wait in seconds
-- @tparam[opt=1] number max wait in seconds (each try doubles the wait until it hits this value)
-- @return true if finished, or nil+timeout
function _M.wait_for(check, timeout, init, max)
  assert(type(check) == "function", "expected 'check' to be a function")
  timeout = timeout or 30
  assert(timeout > 0, "expected 'timeout' to be greater than 0")
  init = init or 0.010
  assert(init > 0, "expected 'init' to be greater than 0")
  max = max or 1
  assert(max > 0, "expected 'max' to be greater than 0")

  local end_time = now() + max
  while now() > end_time do
    if check() then
      return true
    end
    copas.pause(init)
    init = math.min(max, init * 2)
  end
  return nil, "timeout"
end


--- schedules an async task using `copas.addthread` and waits for completion.
-- On a timeout the task will be removed from the Copas scheduler, and the cancel
-- function will be called. The latter one is required when doing socket
-- operations, you must close the socket in case it is in the receiving/sending
-- queues
-- @tparam function task function with the task to execute
-- @tparam[opt=30] number timeout timeout in seconds for the task
-- @tparam[opt] function cancel function to cancel the task
function _M.wait_for_task(task, timeout, cancel)
  local sema = Semaphore.new(1)
  local coro = copas.addthread(function()
    task()
    sema:give()
  end)
  local ok, err = sema:wait(1, timeout or 30)
  if not ok then
    -- timeout
    copas.removethread(coro)
    if cancel then cancel() end
    return ok, err
  end
  return true
end


--- (un)subscribes to/from a list of topics. Will not return until completely done/failed.
-- @tparam mqtt-device mqtt the mqtt device
-- @tparam array list table with topics (topics can be in the key or value, as long as only one of them is a string)
-- @tparam bool unsub subcribe or unsubscribe
-- @tparam number timeout timeout in seconds
-- @return true or nil+err
function _M.subscribe_topics(mqtt, list, unsub, timeout)
  assert(timeout, "timeout is a required parameter")

  if not next(list) then
    return true -- empty list, so nothing to do
  end

  local s = Semaphore.new(10^9)
  local q = Queue.new()
  local h = unsub and mqtt.unsubscribe or mqtt.subscribe

  for key, value in pairs(list) do
    local topic = type(key) == "string" and key or
                  type(value) == "string" and value or
                  error("either key or value must be a topic string)")
    q:push(function()
      return h(mqtt ,{
        topic = topic,
        qos = 1,
        callback = function(...)
          s:give(1)
          --log:info("%ssubscribing %s topic '%s' succeeded", (unsub and "un" or ""),(unsub and "from" or "to"),topic)
        end
      })
    end)
  end

  local items_to_finish = q:get_size()

  q:add_worker(function(item)
    if not item() then
      s:destroy()
      q:destroy()
    end
  end)

  local ok, err = s:take(items_to_finish, timeout)
  s:destroy()
  q:destroy()

  return ok, err
end


--- Publishes a list of topics. Will not return until done/failed.
-- Note: the defaults are; `retain = true`,
-- `qos = 1`, and `callback` can't be set (will always be overridden).
-- @tparam mqtt-device mqtt the mqtt device
-- @tparam array list table payloads indexed by topics (payload can also be a table with
-- options see `mqtt_client:publish`)
-- @tparam number timeout timeout in seconds
-- @return true or nil+err
function _M.publish_topics(mqtt, list, timeout)
  assert(timeout, "timeout is a required parameter")

  if not next(list) then
    return true -- empty list, so nothing to do
  end

  local s = Semaphore.new(10^9)
  local q = Queue.new()
  local cb = function(...)
    s:give(1)
  end

  for topic, payload in pairs(list) do
    if type(payload) == "string" then
      payload = { payload = payload }
    end
    payload.topic = topic
    payload.callback = cb

    -- set alternative defaults
    if payload.retain == nil then payload.retain = true end
    if payload.qos == nil then payload.qos = 1 end

    q:push(function()
      return mqtt:publish(payload)
    end)
  end

  local items_to_finish = q:get_size()

  q:add_worker(function(item)
    if not item() then
      s:destroy()
      q:destroy()
    end
  end)

  local ok, err = s:take(items_to_finish, timeout)
  s:destroy()
  q:destroy()

  return ok, err
end


--- Turns a string into a valid Homie identifier.
-- @tparam string name a string, typically a human readable name
-- @return string with Homie ID, or nil+err
function _M.slugify(name)
  local name_out = name:lower():gsub("[^a-z0-9]", "-"):gsub("^[^a-z]+", ""):
      gsub("[^a-z0-9]+$", ""):gsub("%-%-+", "-")

  if name_out == "" then
    return nil, ("cannot slugify '%s', no valid characters left"):format(name)
  end
  return name_out
end


return _M
