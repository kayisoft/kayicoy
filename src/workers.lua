--------------------------------------------------------------------------------
---- workers.lua -- Functions to Run on NGINX Worker Shutdown

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

local ngx = require "ngx"
local data = require "src/data"
local utils = require "src/utils"
local config = require "secrets/config"

local logerr = utils.logerr
local locks = ngx.shared.locks
local interval = config.email_check_interval

-- The lock is held for the whole interval to prevent multiple workers from
-- running the same job simultaneously. We substract 1ms from the lock
-- expiration time to prevent a race condition with the next timer event.
local function check_consent_responses (premature)
   if premature then return end
   local lock_key = "check_consent_responses"
   local locked, err = locks:add(lock_key, true, interval - 0.001)
   if not locked then
      assert(err == "exists", "ERROR: Failed to lock ("..lock_key.."): "..err)
      return nil
   end

   data.check_email()
end

local handle, err = ngx.timer.every(interval, check_consent_responses)
if not handle then logerr("Failed to create timer: ", err) end
