--- This module does something.
--
-- Explain some basics, or the design.
--
-- @copyright Copyright (c) 2023-2023 Thijs Schreijer
-- @author Thijs Schreijer
-- @license MIT, see `LICENSE.md`.

local M = {}
M._VERSION = "0.0.1"
M._COPYRIGHT = "Copyright (c) 2023-2023 Thijs Schreijer"
M._DESCRIPTION = "Homie library for version 5"


--- Does something.
-- It will do what you tell it.
-- @tparam string|function what the thing that has to be done
-- @tparam[opt=false] boolean force set to a truthy value to force it.
-- @treturn boolean success
-- @treturn nil|string error message on failure
-- @usage
-- local success, err = project.do_something("tell a lie", true)
-- if not success then
--     print("failed at lying; ", err)
-- end
function M.do_something(what, force)
  assert(type(what) == "string" or type(what) == "function", "Expected a string or function")

  -- implement

end

return M
