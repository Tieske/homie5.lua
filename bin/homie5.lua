#!/usr/bin/env lua

--- CLI application.
-- Description goes here.
-- @script homie5
-- @usage
-- # start the application from a shell
-- homie5 --some --options=here

print("Welcome to the homie5 CLI, echoing arguments:")
for i, val in ipairs(arg) do
  print(i .. ":", val)
end
