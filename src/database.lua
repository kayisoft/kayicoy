--------------------------------------------------------------------------------
---- database.lua -- Low-Level Database Access

--- Copyright (C) 2021 Kayisoft, Inc.

--- Author: Mohammad Matini <mohammad.matini@outlook.com>
--- Maintainer: Mohammad Matini <mohammad.matini@outlook.com>

--- Description: This file contains some bindings to the SQLite database
--- library, and some simple wrappers around them, in addition to a basic
--- database migration system.

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

local db = {}

local ffi = require "ffi"
local sqlite = ffi.load "sqlite3"
local migrations = require "src/migrations"
local utils = require "src/utils"
local ngx = require "ngx"

local locks = ngx.shared.locks
local logerr = utils.logerr
local log = utils.log

--------------------------------------------------------------------------------
--                              Return Codes
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- SQLite return codes that we're using. Check the library's header file
-- `sqlite.h' if you face some unknown ones later, or need them.
--
local SQLITE_OK         =  0   -- Successful result
local SQLITE_BUSY       =  5   -- The database file is locked
local SQLITE_ROW        = 100  -- sqlite3_step() has another row ready
local SQLITE_DONE       = 101  -- sqlite3_step() has finished executing
local SQLITE_CONFIG_LOG =  16  -- xFunc, void*

--------------------------------------------------------------------------------
--                              CFFI Declarations
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- SQLite CFFI function declarations that we're currently using. Check the
-- library's header file `sqlite.h' if you need additional functions
-- later. Just copy-paste them here, and you're good to go.
--
ffi.cdef [[
typedef struct sqlite3 sqlite3;
typedef struct sqlite3_stmt sqlite3_stmt;

int sqlite3_open(
  const char *filename,   /* Database filename (UTF-8) */
  sqlite3 **ppDb          /* OUT: SQLite db handle */
);

int sqlite3_prepare_v2(
  sqlite3 *db,            /* Database handle */
  const char *zSql,       /* SQL statement, UTF-8 encoded */
  int nByte,              /* Maximum length of zSql in bytes. */
  sqlite3_stmt **ppStmt,  /* OUT: Statement handle */
  const char **pzTail     /* OUT: Pointer to unused portion of zSql */
);

int sqlite3_config(int, ...);
int sqlite3_close_v2(sqlite3*);
int sqlite3_step(sqlite3_stmt*);
int sqlite3_clear_bindings(sqlite3_stmt*);
int sqlite3_reset(sqlite3_stmt *pStmt);
int sqlite3_finalize(sqlite3_stmt *pStmt);
int sqlite3_column_count(sqlite3_stmt *pStmt);
int sqlite3_bind_text(sqlite3_stmt*,int,const char*,int,void(*)(void*));

const char *sqlite3_errmsg(sqlite3*);
const char *sqlite3_column_name(sqlite3_stmt*, int N);

const unsigned char *sqlite3_column_text(sqlite3_stmt*, int iCol);
]]

--------------------------------------------------------------------------------
--                              SQLite Wrappers
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- SQLite error callback function
--------------------------------------------------------------------------------
--
-- This function is cast to a C function pointer to be compatible with
-- SQLite's logging configuration. It is passed to `sqlite3_config()' when
-- configuring `SQLITE_CONFIG_LOG'. It simply passes the error codes and
-- messages to our own logging facilities.
--
local error_log_callback = ffi.cast(
   "void (*)(void *pArg, int iErrCode, const char *zMsg)",
   function (_, err_code, message)
      logerr("ERROR: SQLite error (" .. err_code .. "): " ..
             ffi.string(message) .. "\n")
end)

--------------------------------------------------------------------------------
-- Initialize new SQLite database object
--------------------------------------------------------------------------------
--
-- This function initializes a new database object, containing a newly
-- opened connection to an SQLite database file. It also configures the
-- SQLite library to use our logging functions if it hadn't been before.
--
function db:init_db (path)
   if self.connection then
      -- If we already have a connection, then this is not the first time we
      -- were called, and so we can just return our own object immediately.
      return self
   end

   -- Configure Library ----------------------------------------
   -- We can only run SQLite3_config before the SQLite library is
   -- initialized. When OpenResty's Lua cache is disabled, the init
   -- functions are run on every request. We can't have them call
   -- sqlite3_config again and again, so we use a lock to prevent that.
   local lock_key = 'database_configured'
   local locked, err = locks:add(lock_key, true)

   if locked then local config_ret = sqlite.sqlite3_config(
         SQLITE_CONFIG_LOG, error_log_callback, nil)
      assert(config_ret == SQLITE_OK, "ERROR: Failed to configure database")
   else
      assert(err == "exists", "ERROR: Failed to lock ("..lock_key.."): "..err)
   end

   -- Initialize Connection ------------------------------------
   local db_handle = ffi.new("sqlite3*[1]") -- pointer-to-pointer to sqlite3
   local open_ret = sqlite.sqlite3_open(path, db_handle)
   assert(open_ret == SQLITE_OK, -- db_handle[0] dereferences the outer pointer
          "ERROR: Failed to open database: " ..
          ffi.string(sqlite.sqlite3_errmsg(db_handle[0]))..'['..open_ret..']')

   -- Create Database Object -----------------------------------
   local obj = {
      connection = db_handle[0],
      -- Just in case we get out of scope and garbage-collected somehow.
      __gc = function (obj) if obj.connection then obj:close_db() end end
   }

   setmetatable(obj, self)
   self.__index = self
   return obj
end

--------------------------------------------------------------------------------
-- Close an SQLite database connection
--------------------------------------------------------------------------------
--
-- This function closes the database connection of the current database
-- object, replacing it with `nil'. The database object is useless after
-- that, and can be discarded. Note that we attempt to close the connection
-- on garbage-collection if the database object ever got out of scope.
--
function db:close_db ()
   -- The v2 function will return OK even if it could not close the database
   -- immediately. Instead, it will mark the connection as zombie, and close
   -- it when it is appropriate. So, probably no need to check for
   -- errors. Worst case, the WAL saves us :]
   sqlite.sqlite3_close_v2(self.connection)
   self.connection = nil
end

--------------------------------------------------------------------------------
-- Execute an SQLite query
--------------------------------------------------------------------------------
--
-- This function executes the passed SQL statement, and accepts a variable
-- number of parameterized arguments that will be bound in order to the SQL
-- statement. Note that this function can only handle one SQL statement at a
-- time, and will ignore any additional statements passed in the same SQL
-- string. If the SQL query returned results, then the function returns a
-- table of records, each record is in-turn a table, containing its columns
-- as keys to their returned values. For example:
--
--     db:exec("SELECT id, name FROM my_table;")
--
-- will return:
--
--     {
--       {id = "1", name = "John"},
--       {id = "2", name = "Sam"},
--       ...
--     }
--
function db:exec (sql_string, ...)
   -- Prepare Statement ----------------------------------------
   -- Using -1 as nByte means read until NUL terminator.
   local statement_handle = ffi.new("sqlite3_stmt*[1]")
   local prep_ret = sqlite.sqlite3_prepare_v2(
      self.connection, sql_string, -1,
      statement_handle, nil)

   assert(prep_ret == SQLITE_OK, "ERROR: Could not compile SQL: "..prep_ret)

   local statement = statement_handle[0]
   local res, done = {}, false

   -- Bind Parameters ------------------------------------------
   for i = 1, select("#", ...) do
      local str = tostring(select(i, ...))
      -- Using -1 as nByte means read until NUL terminator.
      local bind_ret = sqlite.sqlite3_bind_text(statement, i, str, -1, nil)
      assert(bind_ret == SQLITE_OK, "ERROR: Could not bind SQL parameters: " ..
             bind_ret)
   end

   -- Execute Statement ----------------------------------------
   repeat
      local step_ret = sqlite.sqlite3_step(statement)
      if step_ret == SQLITE_ROW  then
         local row = {}
         for i = 0, sqlite.sqlite3_column_count(statement) - 1 do
            row[ffi.string(sqlite.sqlite3_column_name(statement, i))] =
               ffi.string(sqlite.sqlite3_column_text(statement, i))
         end
         table.insert(res, row)
      elseif step_ret == SQLITE_BUSY then ngx.sleep(0.002)
      elseif step_ret == SQLITE_DONE then done = true
      else error("ERROR: Could not exec SQL query, err: " .. step_ret)
      end
   until done

   -- Cleanup --------------------------------------------------
   sqlite.sqlite3_clear_bindings(statement)
   sqlite.sqlite3_reset(statement)
   sqlite.sqlite3_finalize(statement)
   return res
end

--------------------------------------------------------------------------------
--                              Migration Tools
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
-- Run pending database migrations
--------------------------------------------------------------------------------
--
-- Checks to see if there are any pending database migration that haven't
-- been run before, by comparing SQLite's `user_version' PRAGMA. If any such
-- migrations were found, the are run in order until no un-run migrations
-- are left.
--
function db:migrate_latest ()
   -- Check Versions -------------------------------------------
   local wanted_version = #migrations or
      error("ERROR: Failed to get latest migration version")

   local current_version = tonumber(
      self:exec("PRAGMA user_version;")[1]['user_version']
   ) or error("ERROR: Failed to get current database user_version")

   if current_version >= wanted_version then return end -- We are up-to-date

   -- Run Migrations -------------------------------------------
   for version = current_version + 1, wanted_version do
      local migration = migrations[version]
      self:exec_migration(migration)
   end

   log("All database migrations done.")
end

--------------------------------------------------------------------------------
-- Run a specific database migration
--------------------------------------------------------------------------------
--
-- If the migration contains multiple statements, then it is run in a
-- transaction, which is rolled-back if any errors occur. If the migration
-- is composed of a single statement, then it is run directly without a
-- transaction. The function also updates the database's `user_version'
-- PRAGMA value after running a migration successfully. Some PRAGMA
-- modifications cannot happen inside transactions, putting them alone in a
-- migration makes them work.
--
function db:exec_migration (migration)
   log("Running migration number: "..migration.id)
   if #migration.up == 1 then
   -- Single Statement Migrations ------------------------------
      local successful, err = pcall(self.exec, self, migration.up[1])
      if not successful then
         error("ERROR: Failed to run migration ("..
               migration.id.."): ".. err)
      end
   else
   -- Multi-Statement Migrations -------------------------------
      self:exec("BEGIN TRANSACTION")
      for index, statement in ipairs(migration.up) do
         local successful, err = pcall(self.exec, self, statement)
         if not successful then self:exec("ROLLBACK")
            error("ERROR: Failed to run migration ("..migration.id..") " ..
                  "statement ("..index..")"..err)
         end
      end

      self:exec("COMMIT")
   end

   -- Update `user_version' ------------------------------------
   local successful, err = pcall(
      self.exec, self, "PRAGMA user_version = "..migration.id..";")
   if not successful then self:exec("ROLLBACK")
      error("ERROR: Failed to update `user_version' " ..
            "PRAGMA after migration ("..migration.id..")\n"..err)
   end
end

return db
