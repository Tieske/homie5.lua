local package_name = "homie5"
local package_version = "scm"
local rockspec_revision = "1"
local github_account_name = "Tieske"
local github_repo_name = "homie5.lua"


package = package_name
version = package_version.."-"..rockspec_revision

source = {
  url = "git+https://github.com/"..github_account_name.."/"..github_repo_name..".git",
  branch = (package_version == "scm") and "main" or nil,
  tag = (package_version ~= "scm") and package_version or nil,
}

description = {
  summary = "Homie library for version 5 (an MQTT convention for IoT/M2M)",
  detailed = [[
    Homie.lua provides a Lua based Homie v5 implementation for devices and
    controllers.
  ]],
  license = "MIT",
  homepage = "https://github.com/"..github_account_name.."/"..github_repo_name,
}

dependencies = {
  "lua >= 5.1, < 5.5",
  "copas >= 4.3, < 5",
  --"luamqtt",  -- do: "luarocks install Tieske/luamqtt --dev" for now
  "lualogging >= 1.6",
  "penlight ~> 1",
}

build = {
  type = "builtin",

  modules = {
    ["homie5.meta"] = "src/homie5/meta.lua",
    ["homie5.utils"] = "src/homie5/utils.lua",
    ["homie5.device"] = "src/homie5/device.lua",
  },

  copy_directories = {
    -- can be accessed by `luarocks homie5 doc` from the commandline
    "docs",
  },
}
