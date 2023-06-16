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
  summary = "Homie library for version 5",
  detailed = [[
    Homie library for version 5
  ]],
  license = "MIT",
  homepage = "https://github.com/"..github_account_name.."/"..github_repo_name,
}

dependencies = {
  "lua >= 5.1, < 5.5",
}

build = {
  type = "builtin",

  modules = {
    ["homie5.init"] = "src/homie5/init.lua",
  },

  install = {
    bin = {
      ["homie5"] = "bin/homie5.lua",
    }
  },

  copy_directories = {
    -- can be accessed by `luarocks homie5 doc` from the commandline
    "docs",
  },
}
