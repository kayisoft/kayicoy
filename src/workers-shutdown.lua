--------------------------------------------------------------------------------
---- workers-shutdown.lua -- Functions to Run on NGINX Worker Shutdown

--- Copyright (C) 2021 Kayisoft, Inc.

--- Author: Mohammad Matini <mohammad.matini@outlook.com>
--- Maintainer: Mohammad Matini <mohammad.matini@outlook.com>

--- Description: This file contains code to run on NGINX worker shutdown.

--- This file is part of Kayicoy.

--- Kayicoy is free software: you can redistribute it and/or modify
--- it under the terms of the GNU General Public License as published by
--- the Free Software Foundation, either version 3 of the License, or
--- (at your option) any later version.

--- Kayicoy is distributed in the hope that it will be useful,
--- but WITHOUT ANY WARRANTY; without even the implied warranty of
--- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--- GNU General Public License for more details.

--- You should have received a copy of the GNU General Public License
--- along with Kayicoy. If not, see <https://www.gnu.org/licenses/>.

local utils = require "src/utils"
local data = require "src/data"
local ngx = require "ngx"

local locks = ngx.shared.locks;

--------------------------------------------------------------------------------
-- Database Connection Cleanup
--
-- This function closes the main shared database connection. We use a shared
-- dict lock to make sure only one NGINX worker runs the cleanup.
--
local function database_connection_cleanup ()
   local ok, err = locks:add('database_connection_cleanup', true)
   if not ok and err == "exists" then return nil end
   utils.log(ngx.INFO, "Closing database connection...")
   data:close_db()
end

database_connection_cleanup()
