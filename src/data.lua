--------------------------------------------------------------------------------
---- data.lua -- Main Data Layer

--- Copyright (C) 2021 Kayisoft, Inc.

--- Author: Mohammad Matini <mohammad.matini@outlook.com>
--- Maintainer: Mohammad Matini <mohammad.matini@outlook.com>

--- Description: This file contains the the data layer for the consent
--- request API. It allows inserting new consent requests into the database,
--- and querying previous request records.

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

local data = {}

local config = require "secrets/config"
local database = require "src/database"

--------------------------------------------------------------------------------
--                              Database Setup
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- Every NGINX worker will load this file once, and thus will have its own
-- database object containing a unique SQLite database connection.
--
local db = database:init_db(config.datastore_path)

--------------------------------------------------------------------------------
--                              Data Functions
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
function data.insert_consent_request (id, service, email_hash)
   local result = db:exec([[INSERT INTO consent_requests
     (id, service_name, email_hash, agreed) VALUES (?, ?, ?, FALSE);
     ]], id, service, email_hash)[1]

   return result and result["rows inserted"] or 0
end

--------------------------------------------------------------------------------
--
function data.get_consent_request (id, service_name)
   return db:exec([[SELECT * FROM consent_requests
     WHERE id = ? AND service_name = ?;]],
      id, service_name)[1]
end

--------------------------------------------------------------------------------
--
function data.approve_consent_request (id)
   local result = db:exec([[UPDATE consent_requests
     SET agreed = TRUE, updated_at = CURRENT_TIMESTAMP
     WHERE id = ?;]], id)[1]
   return result and result["rows updated"] or 0
end

--------------------------------------------------------------------------------
--
function data.cleanup ()
   return db:close_db()
end

return data
