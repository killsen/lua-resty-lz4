--[[
    ljlz4 - LZ4 library for LuaJIT - https://github.com/CheyiLin/ljlz4

    The MIT License (MIT)

    Copyright (c) 2014-2021 Cheyi Lin <cheyi.lin@gmail.com>

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]]

local type = type
local bit = require("bit")
local ffi = require("ffi")
local ffi_typeof = ffi.typeof
local ffi_sizeof = ffi.sizeof
local ffi_copy = ffi.copy
local ffi_string = ffi.string

local _M = { _VERSION = "1.0.0" }

local clz4 = ffi.load("lz4")

ffi.cdef [[
    int LZ4_versionNumber(void);
    int LZ4_compressBound(int);
    int LZ4_compress (const char *, char *, int);
    int LZ4_compressHC (const char *, char *, int);
    int LZ4_decompress_safe (const char *, char *, int, int);

    typedef struct {
        uint32_t sig;
        uint32_t len;
    } lz4_hdr_t;
]]

local buf_ct = ffi_typeof("char[?]")

local hdr_ct = ffi_typeof("lz4_hdr_t")
local hdr_len = ffi_sizeof(hdr_ct)

local lz4_signature = 0x1b4c5a34    -- '\x1bLZ4' (network-order)

-- local function throw_error(fmt, ...)
--    error(string.format(fmt, ...))
-- end

-- check compatibility
-- local lz4_version = clz4.LZ4_versionNumber()
-- if lz4_version < 10300 then
--       throw_error("incompatible lz4 library version (%d)", lz4_version)
-- end

local htonl, ntohl
if ffi.abi("le") then
    -- little-endian
    htonl = bit.bswap
else
    -- big-endian, same as network-order, do nothing
    htonl = function (b) return b end
end
ntohl = htonl    -- reverse is the same

local function lz4_hdr_write(buf, len)
    if ffi_sizeof(buf) < hdr_len then
        return nil, "invalid buffer length"
    end

    local hdr = hdr_ct()
    hdr.sig = htonl(lz4_signature)
    hdr.len = htonl(len)
    ffi_copy(buf, hdr, hdr_len)

    return true
end

local function lz4_hdr_read(src)
    if #src < hdr_len then
        return nil, "invalid source length"
    end

    local hdr = hdr_ct()
    ffi_copy(hdr, src, hdr_len)
    hdr.sig = ntohl(hdr.sig)
    hdr.len = ntohl(hdr.len)

    if hdr.sig ~= lz4_signature then
        return nil, "lz4 signature mismatch"
    end

    return hdr
end

local function lz4_compress_core(src, clz4_compressor)
    local dst_len = clz4.LZ4_compressBound(#src)
    local dst_buf = buf_ct(hdr_len + dst_len)

    local ok, errmsg = lz4_hdr_write(dst_buf, #src)
    if not ok then
        return nil, errmsg
    end

    local compress_len = clz4_compressor(src, dst_buf + hdr_len, #src)
    if compress_len > 0 then
        return ffi_string(dst_buf, compress_len + hdr_len)
    else
        return nil, "compression failed"
    end
end

local function lz4_decompress_core(src, dst_len)
    local dst_buf = buf_ct(dst_len)
    local decompress_len = clz4.LZ4_decompress_safe(src, dst_buf, #src, dst_len)
    if decompress_len > 0 then
        return ffi_string(dst_buf, decompress_len)
    else
        return nil, "decompression failed"
    end
end

-- 版本
function _M.version()
-- @return : number
    return clz4.LZ4_versionNumber()
end

-- 压缩
function _M.compress_hdr(src, level)
-- @src     : string
-- @level ? : number
-- @return  : dst?: string, err?: string

    if type(src) ~= "string" or #src == 0 then
        return nil, "invalid source (is nil or is a empty string)"
    end

    -- ref: https://github.com/Cyan4973/lz4/blob/master/programs/lz4io.c#L308
    if type(level) ~= "number" or level < 3 then
        return lz4_compress_core(src, clz4.LZ4_compress)
    else
        return lz4_compress_core(src, clz4.LZ4_compressHC)
    end
end

-- 解压
function _M.decompress_hdr(src)
-- @src     : string
-- @return  : dst?: string, err?: string

    if type(src) ~= "string" or #src == 0 then
        return nil, "invalid source (is nil or is a empty string)"
    end

    local hdr, errmsg = lz4_hdr_read(src)
    if not hdr then
        return nil, errmsg
    end

    return lz4_decompress_core(src:sub(hdr_len + 1), hdr.len)
end

-- 压缩
function _M.compress(src)
-- @src     : string
-- @return  : dst?: string, err?: string

    if type(src) ~= "string" or #src == 0 then
        return nil, "invalid source (is nil or is a empty string)"
    end

    local dst_len = clz4.LZ4_compressBound(#src)
    local dst_buf = buf_ct(dst_len)

    local compress_len = clz4.LZ4_compress(src, dst_buf, #src)
    if compress_len > 0 then
        return ffi_string(dst_buf, compress_len)
    else
        return nil, "compression failed"
    end
end

-- 解压
function _M.decompress(src, dst_len)
-- @src         : string
-- @dst_len    : number
-- @return      : dst?: string, err?: string

    if type(src) ~= "string" or #src == 0 then
        return nil, "invalid source (is nil or is a empty string)"
    end

    if type(dst_len) ~= "number" or dst_len <= 0 then
        return nil, "dst_len must be greater then zreo"
    end

    return lz4_decompress_core(src, dst_len)
end

return _M
