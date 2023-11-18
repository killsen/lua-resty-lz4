# LUA-RESTY-LZ4

[LZ4](https://github.com/lz4/lz4) library for LuaJIT (FFI Binding)

## Compatibility

| Version | [LuaJIT 2.0](https://luajit.org/luajit.html) | [LuaJIT 2.1 (OpenResty)](https://github.com/openresty/luajit2) |
| ---------- | ------- | ------- |
| lz4 v1.9.3 | &check; | &check; |
| lz4 v1.8.3 | &check; | &check; |
| lz4 v1.7.5 | &check; | &check; |
| lz4 r131 | &check; | &check; |

## Usage

### Overview

```lua
local lz4 = require "resty.lz4"

local data = string.rep("hello lz4", 100)
ngx.say("#data : ", #data)

local compressed_data, err = lz4.compress(data)
local decompressed_data, err = lz4.decompress(compressed_data, #data)

ngx.say("#compressed_data : ", #compressed_data)
ngx.say("#decompressed_data : ", #decompressed_data)
ngx.say("decompressed_data == data : ", decompressed_data == data)

local compressed_data_hdr, err = lz4.compress_hdr(data)
local decompressed_data_hdr, err = lz4.decompress_hdr(compressed_data_hdr)

ngx.say("#compressed_data_hdr : ", #compressed_data_hdr)
ngx.say("#decompressed_data_hdr : ", #decompressed_data_hdr)
ngx.say("decompressed_data_hdr == data: ", decompressed_data_hdr == data)
```

### Compression

```lua
local compressed_data, err = lz4.compress(data)
local compressed_data_hdr, err = lz4.compress_hdr(data, compression_level)
```

### Decompression

```lua
local decompressed_data, err = lz4.decompress(compressed_data)
local decompressed_data_hdr, err = lz4.decompress_hdr(compressed_data_hdr)
```

## License

Copyright (c) 2014-2021 Cheyi Lin.
MIT licensed. See LICENSE for details.
