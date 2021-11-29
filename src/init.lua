--------------------------------------------------------------------------------
---- init.lua -- System Initialization Code

--- Copyright (C) 2021 Kayisoft, Inc.

--- Author: Mohammad Matini <mohammad.matini@outlook.com>
--- Maintainer: Mohammad Matini <mohammad.matini@outlook.com>

--- Description: This file contains the initialization code that will run on
--- NGINX boot, within NGINX's master process. Currently it mainly runs the
--- database migrations.

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

local config = require "secrets/config"
local database = require "src/database"

local locks = (require("ngx")).shared.locks

local utils = require "src/utils"
local log = utils.log


--------------------------------------------------------------------------------
-- Run Pending Database Migrations
--
-- To run the migration once only, we use a shared dict lock
--
local ok, err = locks:add('database_migration', true)
if ok then db:migrate_latest() end
