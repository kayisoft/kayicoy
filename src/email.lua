--------------------------------------------------------------------------------
---- email.lua -- Email Processing Tools

--- Copyright (C) 2021 Kayisoft, Inc.

--- Author: Mohammad Matini <mohammad.matini@outlook.com>
--- Maintainer: Mohammad Matini <mohammad.matini@outlook.com>

--- Description: This file contains various tools and utilities for Email
--- processing and manipulation, using SMTP and IMAP.

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

local email = {}

local config = require "secrets/config"
local shell = require "resty.shell"
local utils = require "src/utils"
local data = require "src/data"
local ngx = require "ngx"

local logerr = utils.logerr
local log = utils.log

--------------------------------------------------------------------------------
-- Process unread consent Emails
--------------------------------------------------------------------------------
--
-- Check for unseen Email replies, then process them by checking for valid
-- consent request IDs in their subject lines, and updating the database
-- with their agreement.
--
function email.process_unread_emails ()
   -- Check for Unread Emails ----------------------------------
   log("Checking Emails...")
   local unseen_emails = email.run_imap_command("INBOX?UNSEEN")
   if not unseen_emails then return nil end
   local count = 0

   -- Process New Emails ---------------------------------------
   for unseen_email_id in unseen_emails:gmatch("[0-9]+") do
      local email_subject = email.run_imap_command(
         "INBOX;UID="..unseen_email_id.."/;SECTION=HEADER.FIELDS%20(SUBJECT)")
      if not email_subject then return nil end

      local request_id = ngx.re.match(email_subject, "\\[([a-fA-F0-9]{16})\\]", "joix")[1]
      if request_id then
         local resolved = data.approve_consent_request(request_id)
         if not resolved then
            logerr("ERROR: Unknow error when approving requests", resolved)
            return nil
         end

         count = count + resolved
      end
   end

   log(count == 0 and "Nothing to Resolve" or "Resolved: "..count)
   return count
end

--------------------------------------------------------------------------------
-- Send consent request Email
--------------------------------------------------------------------------------
--
-- Send an Email requesting parental consent to `to_email` using cURL in a
-- child process, non-blocking to NGINX. The Email will contain the request
-- ID in its subject line, which is critical for later processing by our
-- background workers after the customer replies to the Email.
--
function email.send_consent_request_email (to_email, request_id, service)
   -- Prepare cURL Command -------------------------------------
   local q = utils.quote_shell_arg
   local curl_command = {
      "curl", "--silent", "--ssl-reqd", "--url", q(config.smtp_server),
      "--mail-from", q(config.sender_email),
      "--mail-rcpt", q(to_email),
      "--user", q(config.smtp_credentials),
      "--upload-file", "-"
   }

   -- Fill Message Template ------------------------------------
   local message = {
      "From: ", config.sender_name, " ", "<",config.sender_email,">", "\n",
      "To: ", "<",to_email,">", "\n",
      "Subject: ", "Kayisoft Consent Request ["..request_id.."]", "\n",
      "Date: ", ngx.utctime(), "\n\n", [[
Dear Kayisoft User,

Your child attempted to use our service ]]..service..[[.
This Service requires parental consent, as it collects various
personal information about the child. If you consent to allowing
your child to use our service, then please reply to this Email.

Please do not modify the subject (i.e. title) of this Email. The
ID between two brackets [ID] is required to make sure we serve
your request correctly. Otherwise your child's login may fail.

If you refuse to give consent, then please ignore this Email.
]]
   }

   -- Run Sub-Shell Process ------------------------------------
   local command = table.concat(curl_command, " ")
   local stdin = table.concat(message)
   local timeout = 5000  -- 5 seconds
   local max_size = 5120  -- 5KiB

   local ok, stdout, stderr, reason, status =
      shell.run(command, stdin, timeout, max_size)

   if not ok then
      logerr("FAILED TO SEND EMAIL: ", stdout, stderr, reason, status)
      utils.reject(500, "Internal Server Error")
   end
end

--------------------------------------------------------------------------------
-- Run cURL-based IMAP commands
--------------------------------------------------------------------------------
--
-- This function accepts URL-based cURL IMAP commands, _not_ pure IMAP
-- commands. For example: `INBOX;UID=12/;SECTION=HEADER.FIELDS%20(SUBJECT)'
--
function email.run_imap_command (url_command)
   local q = utils.quote_shell_arg
   local curl_command = {
      "curl", "--silent", "--url", q(config.imap_server.."/"..url_command),
      "--user", q(config.imap_credentials)
   }

   local command = table.concat(curl_command, " ")
   local timeout = 10000  -- 10 seconds
   local max_size = 51200 -- 50KiB

   local ok, stdout, stderr, reason, status =
      shell.run(command, nil, timeout, max_size)

   if not ok then
      logerr("FAILED TO RUN IMAP COMMAND: ",
          command, stdout, stderr, reason, status)
      return nil
   end

   return stdout
end

return email
