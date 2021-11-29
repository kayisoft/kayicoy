--------------------------------------------------------------------------------
---- crypto.lua -- Cryptographic Tools

--- Copyright (C) 2021 Kayisoft, Inc.

--- Author: Mohammad Matini <mohammad.matini@outlook.com>
--- Maintainer: Mohammad Matini <mohammad.matini@outlook.com>

--- Description: This file contains some bindings to `libsodium', and some
--- simple wrappers around them.

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

local crypto = {}

local ffi = require "ffi"
local sodium = ffi.load "sodium"

--------------------------------------------------------------------------------
--                              Crypto Parameters
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- Derived from recommended values in libsodium's docs and header files.
--
local crypto_pwhash_STRBYTES = 128
local crypto_pwhash_MEMLIMIT_MIN = 8192
local crypto_opslimit = 3

--------------------------------------------------------------------------------
--                              CFFI Declarations
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- libsodium CFFI function declarations that we're currently using. Check
-- the library's header files if you need additional functions later. Just
-- copy-paste them here, and you're good to go.
--
ffi.cdef [[
int sodium_init(void);
uint32_t randombytes_random(void);

int crypto_pwhash_str(char out[],
                      const char * const passwd,
                      unsigned long long passwdlen,
                      unsigned long long opslimit,
                      size_t memlimit);

int crypto_pwhash_str_verify(const char str[],
                             const char * const passwd,
                             unsigned long long passwdlen);
]]

--------------------------------------------------------------------------------
--                              Sodium Wrappers
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
function crypto.random()
   assert(sodium.sodium_init() >= 0, "ERROR: Failed to initialize crypto library")
   return sodium.randombytes_random()
end

--------------------------------------------------------------------------------
--
function crypto.hash_secret(secret)
   assert(sodium.sodium_init() >= 0, "ERROR: Failed to initialize crypto library")
   local hashed_secret = ffi.new("char [?]", crypto_pwhash_STRBYTES)
   local hash_ret = sodium.crypto_pwhash_str(
      hashed_secret, secret, secret:len(),
      crypto_opslimit, crypto_pwhash_MEMLIMIT_MIN)

   if hash_ret ~= 0 then error("ERROR: Failed to hash secret") end

   return ffi.string(hashed_secret)
end

--------------------------------------------------------------------------------
--
function crypto.verify_hashed_secret(hash, secret)
   assert(sodium.sodium_init() >= 0, "ERROR: Failed to initialize crypto library")
   local ver_ret = sodium.crypto_pwhash_str_verify(hash, secret, secret:len())
   return ver_ret == 0
end

return crypto
