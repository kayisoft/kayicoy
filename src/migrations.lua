--------------------------------------------------------------------------------
---- migrations.lua -- Database Migration Definitions

--- Copyright (C) 2021 Kayisoft, Inc.

--- Author: Mohammad Matini <mohammad.matini@outlook.com>
--- Maintainer: Mohammad Matini <mohammad.matini@outlook.com>

--- Description: This file contains database migration definitions in a
--- format processable by our database migration system. To create
--- additional database migrations, create a new migration object, and fill
--- its fields like previous ones do. WARNING: up and down migrations _MUST_
--- be a list of _single statement_ SQL strings. You cannot put multiple SQL
--- statements in the same string, only the first will be run, and the rest
--- will be ignored silently. Put a single statement in every string.
--- There's no limit on how many strings in the migration up or down list
--- though, so use that instead. Also, note that the `id' field and the
--- migration index in the `migrations' list must match exactly.

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

local migrations = {
   [1] = {
      id          = 1,
      date        = "2021-11-28T14:39:50Z",
      description = [[
        Configure WAL support.

          We have multiple writers from different NGINX workers, so using
          SQLite's WAL journal mode will help reduce SQLITE_BUSY responses.
          We have to execute this in a separate migration, because PRAGMA
          calls cannot happen inside open transactions.
      ]],
      up          = {"PRAGMA journal_mode = WAL;"},
      down        = {"PRAGMA journal_mode = DELETE;"}
   },

   [2] = {
      id          = 2,
      date        = "2021-11-28T14:40:00Z",
      description = "Apply the initial database scheme",
      up          = {[[
          CREATE TABLE IF NOT EXISTS consent_requests (
             id VARCHAR(16) PRIMARY KEY, service_name TEXT,
             email_hash TEXT, agreed BOOLEAN,
             created_at DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL,
             updated_at DATETIME DEFAULT CURRENT_TIMESTAMP NOT NULL);
      ]]},
      down        = {"DROP TABLE IF EXISTS consent_requests;"}
   },

   [3] = {
      id          = 3,
      date        = "2021-11-29T20:00:00Z",
      description = "Enable automatic changed record count",
      up          = {"PRAGMA count_changes = TRUE"},
      down        = {"PRAGMA count_changes = FALSE"}
   }
}

return migrations
