
module Codecs

import Iterators.partition

export encode, decode, Base64, Zlib

abstract Codec


function encode{T <: Codec}(codec::Type{T}, s::String)
    encode(codec, convert(Vector{Uint8}, s))
end


# RFC3548/RFC4648 base64 codec

abstract Base64 <: Codec

const base64_tbl = Uint8[
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
    'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
    'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',
    'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
    'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
    'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
    'w', 'x', 'y', 'z', '0', '1', '2', '3',
    '4', '5', '6', '7', '8', '9', '+', '/']

const base64_pad = uint8('=')


function encode(::Base64, input::Vector{Uint8})
    n = length(input)
    if n == 0
        return Array(Uint8, 0)
    end

    m = int(4 * ceil(n / 3))
    output = Array(Uint8, m)

    for (i, (u, v, w)) in enumerate(partition(input, 3))
        output[4 * (i - 1) + 1] =
            base64_tbl[1 + u >> 2]
        output[4 * (i - 1) + 2] =
            base64_tbl[1 + ((u << 4) | (v >> 4)) & 0b00111111]
        output[4 * (i - 1) + 3] =
            base64_tbl[1 + ((v << 2) | (w >> 6)) & 0b00111111]
        output[4 * (i - 1) + 4] =
            base64_tbl[1 + w & 0b00111111]
    end

    if n % 3 == 1
        output[end - 3] = base64_tbl[1 + input[end] >> 2]
        output[end - 2] = base64_tbl[1 + (input[end] << 4) & 0b00111111]
        output[end - 1] = base64_pad
        output[end - 0] = base64_pad
    elseif n % 3 == 2
        output[end - 3] = base64_tbl[1 + input[end - 1] >> 2]
        output[end - 2] =
            base64_tbl[1 + ((input[end - 1] << 4) | (input[end] >> 4)) & 0b00111111]
        output[end - 1] =
            base64_tbl[1 + (input[end] << 2) & 0b00111111]
        output[end] = base64_pad
    end

    output
end

# TODO: decode



# Zlib/Gzip

abstract Zlib <: Codec

const Z_NO_FLUSH      = 0
const Z_PARTIAL_FLUSH = 1
const Z_SYNC_FLUSH    = 2
const Z_FULL_FLUSH    = 3
const Z_FINISH        = 4
const Z_BLOCK         = 5
const Z_TREES         = 6

const Z_OK            = 0
const Z_STREAM_END    = 1
const Z_NEED_DICT     = 2
const ZERRNO          = -1
const Z_STREAM_ERROR  = -2
const Z_DATA_ERROR    = -3
const Z_MEM_ERROR     = -4
const Z_BUF_ERROR     = -5
const Z_VERSION_ERROR = -6


# The zlib z_stream structure.
type z_stream
    next_in::Ptr{Uint8}
    avail_in::Uint32
    total_in::Uint

    next_out::Ptr{Uint8}
    avail_out::Uint32
    total_out::Uint

    msg::Ptr{Uint8}
    state::Ptr{Void}

    zalloc::Ptr{Void}
    zfree::Ptr{Void}
    opaque::Ptr{Void}

    data_type::Int32
    adler::Uint
    reserved::Uint

    function z_stream()
        strm = new()
        strm.next_in   = C_NULL
        strm.avail_in  = 0
        strm.total_in  = 0
        strm.next_out  = C_NULL
        strm.avail_out = 0
        strm.total_out = 0
        strm.msg       = C_NULL
        strm.state     = C_NULL
        strm.zalloc    = C_NULL
        strm.zfree     = C_NULL
        strm.opaque    = C_NULL
        strm.data_type = 0
        strm.adler     = 0
        strm.reserved  = 0
        strm
    end
end


function zlib_version()
    ccall((:zlibVersion, :libz), Ptr{Uint8}, ())
end


function encode(::Type{Zlib}, input::Vector{Uint8}, level::Integer)
    if !(1 <= level <= 9)
        error("Invalid zlib compression level.")
    end

    strm = z_stream()
    ret = ccall((:deflateInit_, :libz),
                Int32, (Ptr{z_stream}, Int32, Ptr{Uint8}, Int32),
                &strm, level, zlib_version(), sizeof(z_stream))

    if ret != Z_OK
        error("Error initializing zlib deflate stream.")
    end

    strm.next_in = input
    strm.avail_in = length(input)
    strm.total_in = length(input)
    output = Array(Uint8, 0)
    outbuf = Array(Uint8, 1024)
    ret = Z_OK

    while ret != Z_STREAM_END
        strm.avail_out = length(outbuf)
        strm.next_out = outbuf
        flush = strm.avail_in == 0 ? Z_FINISH : Z_NO_FLUSH
        ret = ccall((:deflate, :libz),
                    Int32, (Ptr{z_stream}, Int32),
                    &strm, flush)
        if ret != Z_OK && ret != Z_STREAM_END
            error("Error in zlib deflate stream ($(ret)).")
        end

        if length(outbuf) - strm.avail_out > 0
            append!(output, outbuf[1:(length(outbuf) - strm.avail_out)])
        end
    end

    ret = ccall((:deflateEnd, :libz), Int32, (Ptr{z_stream},), &strm)
    if ret == Z_STREAM_ERROR
        error("Error: zlib deflate stream was prematurely freed.")
    end

    output
end


function encode(::Type{Zlib}, input::String, level::Integer)
    encode(Zlib, convert(Vector{Uint8}, input), level)
end


encode(::Type{Zlib}, input::Vector{Uint8}) = encode(Zlib, input, 9)


function decode(::Type{Zlib}, input::Vector{Uint8})
    strm = z_stream()
    ret = ccall((:inflateInit_, :libz),
                Int32, (Ptr{z_stream}, Ptr{Uint8}, Int32),
                &strm, zlib_version(), sizeof(z_stream))

    if ret != Z_OK
        error("Error initializing zlib inflate stream.")
    end

    strm.next_in = input
    strm.avail_in = length(input)
    strm.total_in = length(input)
    output = Array(Uint8, 0)
    outbuf = Array(Uint8, 1024)
    ret = Z_OK

    while ret != Z_STREAM_END
        strm.next_out = outbuf
        strm.avail_out = length(outbuf)
        ret = ccall((:inflate, :libz),
                    Int32, (Ptr{z_stream}, Int32),
                    &strm, Z_NO_FLUSH)
        if ret != Z_OK && ret != Z_STREAM_END
            error("Error in zlib inflate stream ($(ret)).")
        end

        if length(outbuf) - strm.avail_out > 0
            append!(output, outbuf[1:(length(outbuf) - strm.avail_out)])
        end
    end

    ret = ccall((:inflateEnd, :libz), Int32, (Ptr{z_stream},), &strm)
    if ret == Z_STREAM_ERROR
        error("Error: zlib inflate stream was prematurely freed.")
    end

    output
end


end # module Codecs

