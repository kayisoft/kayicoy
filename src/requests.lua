--------------------------------------------------------------------------------
---- consent-requests.lua -- Main API Logic

--- Copyright (C) 2021 Kayisoft, Inc.

--- Author: Mohammad Matini <mohammad.matini@outlook.com>
--- Maintainer: Mohammad Matini <mohammad.matini@outlook.com>

--- Description: This file contains the main logic for the consent request
--- API. It allows creating new consent requests, and querying the status of
--- previous requests.

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
local utils = require "src/utils"

local respond = utils.respond
local reject = utils.reject
local method = ngx.req.get_method()

--------------------------------------------------------------------------------
-- POST New Consent Request
--
-- Create a new consent request. This will trigger an Email to be sent to
-- the user's supplied email, and will respond to the caller with the new
-- consent request ID. Save the ID for later querying.
-- 
-- POST /api/parental-consent-requests
-- Body: { "email": "test@example.com" }
-- Response: 201 { "id": "jEAlpofWeeRY" }
--
function create_consent_request ()
   local data = utils.parse_request_body()
   local id = utils.generate_request_id()
   local email = data.email

   local valid_email_p, validation_error = utils.validate_email(email)
   if not valid_email_p then
      reject(422, validation_error
             and ("Invalid Email: "..email.." "..validation_error)
             or "Missing Email")
   end

   utils.send_consent_request_email(email)
   respond(201, {id = id})
end

--------------------------------------------------------------------------------
-- GET Consent Request Status
-- 
-- Get a previously created consent request by ID. Use this to check later
-- whether the user had agreed to the request, or not.
--     
-- GET /api/parental-consent-requests/{id}
-- Response: 200 { "id": "jEAlpofWeeRY", "agreed": false }
--
function get_consent_request()
   local id = utils.parse_request_id()
   if not id or not utils.validate_request_id(id) then
      reject(404, "Consent Request Not Found")
   end
   local id = id:upper()

   respond(200, {id = id, agreed = false})
end

--------------------------------------------------------------------------------
-- HTTP METHOD DISPATCH
--
if method == "POST" then create_consent_request()
elseif method == "GET" then get_consent_request()
else reject(405, "Method Not Allowed: Only GET or POST")
end
