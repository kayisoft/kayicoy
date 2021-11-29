--------------------------------------------------------------------------------
---- utils.lua -- Helper Functions & Utilities

--- Copyright (C) 2021 Kayisoft, Inc.

--- Author: Mohammad Matini <mohammad.matini@outlook.com>
--- Maintainer: Mohammad Matini <mohammad.matini@outlook.com>

--- Description: This file contains various helper functions and utilities
--- used by the consent request API. It includes tools to parse and validate
--- data, and some wrapper functions around NGINX's API.

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

local utils = {}

local ngx = require "ngx"
local cjson = require "cjson.safe"
cjson.decode_invalid_numbers(false)

--------------------------------------------------------------------------------
--                              NGINX Wrappers
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- Simple response function for the current NGINX request
--------------------------------------------------------------------------------
--
function utils.respond (status, message)
   ngx.status = status
   ngx.header["Content-Type"] = "application/json"
   ngx.say(cjson.encode(message))
   ngx.exit(status)
end

local respond = utils.respond   -- alias for use in this file

--------------------------------------------------------------------------------
-- Simple rejection function for the current NGINX request
--------------------------------------------------------------------------------
--
function utils.reject (status, message)
   respond(status, {message = message})
end

local reject = utils.reject     -- alias for use in this file

--------------------------------------------------------------------------------
-- Simple NGINX-friendly logging function
--------------------------------------------------------------------------------
--
function utils.log (...)
   if ngx then return ngx.log(ngx.NOTICE, ...)
   else return print(...) end
end

--------------------------------------------------------------------------------
-- Simple NGINX-friendly error logging function
--------------------------------------------------------------------------------
--
function utils.logerr (...)
   if ngx then return ngx.log(ngx.ERR, ...)
   else return print(...) end
end

local logerr = utils.logerr           -- alias for use in this file

--------------------------------------------------------------------------------
--                              Parsers & Validators
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- Parse & validate the current NGINX request JSON body
--------------------------------------------------------------------------------
--
function utils.parse_request_body ()
   if not ngx.req.get_headers()["Content-Type"]:match("application/json") then
      reject(415, "Unsupported Media Type: Only `application/json` is accepted")
   end

   ngx.req.read_body()
   local data, err = cjson.decode(ngx.req.get_body_data())
   if not data then reject(400, "Bad Request: " .. (err or ""))
   else return data end
end

--------------------------------------------------------------------------------
-- Parse request IDs from the current NGINX request URL
--------------------------------------------------------------------------------
--
function utils.parse_request_id ()
   local match, err = ngx.re.match(
      ngx.var.request_uri, "/parental-consent-requests/(.*$)", "joix")
   if match then return match[1] end
   if err then logerr(err)
      reject(500, "Internal Server Error")
   end

   return nil
end

--------------------------------------------------------------------------------
-- Validate request ID formatting; 16 hex characters
--------------------------------------------------------------------------------
--
function utils.validate_request_id (id)
   local id_regex = "^[a-fA-F0-9]{16}$"
   return ngx.re.find(id, id_regex, "joix")
end

--------------------------------------------------------------------------------
--                              Miscellaneous
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- Generate random request IDs; 16 hex characters, read from urandom
--------------------------------------------------------------------------------
--
function utils.generate_request_id ()
   local res, length = {}, 16
   local urand = assert (io.open ('/dev/urandom', 'rb'))
   local str = urand:read(length)
   urand:close()

   for i = 1, str:len() do res[i] = string.format("%x", str:byte(i) % 16) end
   return string.upper(table.concat(res))
end

--------------------------------------------------------------------------------
-- Convert SQLite numbers to booleans, SQLite uses raw numbers by default.
--------------------------------------------------------------------------------
--
function utils.num_to_bool (num) return tonumber(num) ~= 0 and true or false end

--------------------------------------------------------------------------------
-- Quote shell arguments
--------------------------------------------------------------------------------
--
-- Escape single quotes by replacing them with '\'', then wraps the whole
-- string in single quotes. Only single quotes require escaping, all other
-- shell constructs are not interpreted within sh single quote strings.
--
function utils.quote_shell_arg (str)
   return "'" .. str:gsub("'", "'\\\''") .. "'"
end

--------------------------------------------------------------------------------
--
-- Adapted from code by james2doyle <james2doyle@gmail.com>
-- https://gist.github.com/james2doyle/67846afd05335822c149
-- TODO: Throws error on "test@example.com@@", should fix later
--
function utils.validate_email (str)
   if str == nil or str:len() == 0 then return nil end
   if (type(str) ~= 'string') then return nil end

   local lastAt = str:find("[^%@]+$")

   -- Get the substring before '@' symbol
   local localPart = str:sub(1, (lastAt - 2))

   -- Get the substring after '@' symbol
   local domainPart = str:sub(lastAt, #str)

   -- we werent able to split the email properly
   if localPart == nil then
      return nil, "Local name is invalid"
   end

   if domainPart == nil or not domainPart:find("%.") then
      return nil, "Domain is invalid"
   end
   if string.sub(domainPart, 1, 1) == "." then
      return nil, "First character in domain cannot be a dot"
   end
   -- local part is maxed at 64 characters
   if #localPart > 64 then
      return nil, "Local name must be less than 64 characters"
   end
   -- domains are maxed at 253 characters
   if #domainPart > 253 then
      return nil, "Domain must be less than 253 characters"
   end
   -- somthing is wrong
   if lastAt >= 65 then
      return nil, "Invalid @ symbol usage"
   end
   -- quotes are only allowed at the beginning of a the local name
   local quotes = localPart:find("[\"]")
   if type(quotes) == 'number' and quotes > 1 then
      return nil, "Invalid usage of quotes"
   end
   -- no @ symbols allowed outside quotes
   if localPart:find("%@+") and quotes == nil then
      return nil, "Invalid @ symbol usage in local part"
   end
   -- no dot found in domain name
   if not domainPart:find("%.") then
      return nil, "No TLD found in domain"
   end
   -- only 1 period in succession allowed
   if domainPart:find("%.%.") then
      return nil, "Too many periods in domain"
   end
   if localPart:find("%.%.") then
      return nil, "Too many periods in local part"
   end
   -- just a general match
   if not str:match('[%w]*[%p]*%@+[%w]*[%.]?[%w]*') then
      return nil, "Email pattern test failed"
   end
   -- all our tests passed, so we are ok
   return true
end

return utils
