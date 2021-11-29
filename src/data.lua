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
-- Initialize Worker Database Connection Object
--
-- Every NGINX worker will load this file once, and thus will have its own
-- database object containing a unique database connection.
--
local db = database:init_db(config.datastore_path)


--------------------------------------------------------------------------------
-- Insert a Consent Request to Database
--
function data.insert_consent_request (id, service, email_hash)
   return db:exec([[INSERT INTO consent_requests
     (id, service_name, email_hash, agreed)
     VALUES (?, ?, ?, FALSE);
   ]], id, service, email_hash)
end

--------------------------------------------------------------------------------
-- Select a Consent Request from Database by ID
--
function data.get_consent_request (id)
   return db:exec([[SELECT * FROM consent_requests WHERE id = ?;]], id)[1]
end

return data
