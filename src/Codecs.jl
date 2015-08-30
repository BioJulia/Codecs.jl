VERSION >= v"0.4.0-dev+6641" && __precompile__()

module Codecs

using Compat


export encode, decode, Base64, Zlib, BCD

abstract Codec


function encode{T <: Codec}(codec::Type{T}, s::String)
    encode(codec, convert(Vector{Uint8}, s))
end


function decode{T <: Codec}(codec::Type{T}, s::String)
    decode(codec, convert(Vector{Uint8}, s))
end


# RFC3548/RFC4648 base64 codec

abstract Base64 <: Codec

const b64enc_tbl = Uint8[
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
    'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
    'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',
    'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
    'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
    'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
    'w', 'x', 'y', 'z', '0', '1', '2', '3',
    '4', '5', '6', '7', '8', '9', '+', '/']

const base64_pad = @compat UInt8('=')
const sentinel = typemax(Uint8)

const b64dec_tbl = fill(sentinel, 256)
for (val, ch) in enumerate(b64enc_tbl)
    b64dec_tbl[ch] = val - 1
end

function base64dec(c::Uint8)
    v = b64dec_tbl[c]
    if v == sentinel
        error("Invalid base64 symbol: $(char(c))")
    end
    v
end

function encode(::Type{Base64}, input::Vector{Uint8})
    n = length(input)
    if n == 0
        return Array(Uint8, 0)
    end

    m = @compat Int(4 * ceil(n / 3))
    output = Array(Uint8, m)

    k = 1
    for ii = 1:3:length(input)-2
        u, v, w = input[ii], input[ii+1], input[ii+2]
        output[k]     = b64enc_tbl[  (u >> 2)                     + 1]
        output[k + 1] = b64enc_tbl[(((u << 4) | (v >> 4)) & 0x3f) + 1]
        output[k + 2] = b64enc_tbl[(((v << 2) | (w >> 6)) & 0x3f) + 1]
        output[k + 3] = b64enc_tbl[  (w                   & 0x3f) + 1]
        k += 4
    end

    if n % 3 == 1
        output[end - 3] = b64enc_tbl[ (input[end] >> 2)         + 1]
        output[end - 2] = b64enc_tbl[((input[end] << 4) & 0x3f) + 1]
        output[end - 1] = base64_pad
        output[end]     = base64_pad
    elseif n % 3 == 2
        output[end - 3] = b64enc_tbl[  (input[end - 1] >> 2)      + 1]
        output[end - 2] = b64enc_tbl[(((input[end - 1] << 4) |
                                       (input[end] >> 4)) & 0x3f) + 1]
        output[end - 1] = b64enc_tbl[ ((input[end] << 2) & 0x3f)  + 1]
        output[end] = base64_pad
    end

    output
end


function decode(::Type{Base64}, input::Vector{Uint8})
    n = length(input)
    if n == 0
        return Array(Uint8, 0)
    end

    if n % 4 != 0
        warn("Length of Base64 input is not a multiple of four.")
    end

    m = 3 * div(n,  4)
    if input[end] == base64_pad
        m -= 1
    end
    if input[end - 1] == base64_pad
        m -= 1
    end
    output = Array(Uint8, m)

    k = 1
    @inbounds for ii = 1:4:length(input)-4
        # This loop is performance-critical, so inline base64dec and consolidate into a single branch point for error-checking
        u = b64dec_tbl[input[ii]]
        v = b64dec_tbl[input[ii + 1]]
        w = b64dec_tbl[input[ii + 2]]
        z = b64dec_tbl[input[ii + 3]]
        if u | v | w | z == sentinel
            if u == sentinel
                error("Invalid base64 symbol: $(char(input[ii]))")
            elseif v == sentinel
                error("Invalid base64 symbol: $(char(input[ii + 1]))")
            elseif w == sentinel
                error("Invalid base64 symbol: $(char(input[ii + 2]))")
            else
                error("Invalid base64 symbol: $(char(input[ii + 3]))")
            end
        end
        output[k]     = (u << 2) | (v >> 4)
        output[k + 1] = (v << 4) | (w >> 2)
        output[k + 2] = (w << 6) | z
        k += 3
    end

    u = input[end-3]
    v = input[end-2]
    w = input[end-1]
    z = input[end]
    u = base64dec(u)
    v = base64dec(v)


    if w == base64_pad && z == base64_pad
        output[end] = (u << 2) | (v >> 4)
    elseif z == base64_pad
        w = base64dec(w)
        output[end - 1] = (u << 2) | (v >> 4)
        output[end]     = (v << 4) | (w >> 2)
    else
        w = base64dec(w)
        z = base64dec(z)
        output[end - 2] = (u << 2) | (v >> 4)
        output[end - 1] = (v << 4) | (w >> 2)
        output[end]     = (w << 6) | z
    end

    output
end

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


@unix_only const libz = "libz"
@windows_only const libz = "zlib1"


# The zlib z_stream structure.
type z_stream
    next_in::Ptr{Uint8}
    avail_in::Cuint
    total_in::Culong

    next_out::Ptr{Uint8}
    avail_out::Cuint
    total_out::Culong

    msg::Ptr{Uint8}
    state::Ptr{Void}

    zalloc::Ptr{Void}
    zfree::Ptr{Void}
    opaque::Ptr{Void}

    data_type::Cint
    adler::Culong
    reserved::Culong

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
    ccall((:zlibVersion, libz), Ptr{Uint8}, ())
end


function encode(::Type{Zlib}, input::Vector{Uint8}, level::Integer)
    if !(1 <= level <= 9)
        error("Invalid zlib compression level.")
    end

    strm = z_stream()
    ret = ccall((:deflateInit_, libz),
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
        ret = ccall((:deflate, libz),
                    Int32, (Ptr{z_stream}, Int32),
                    &strm, flush)
        if ret != Z_OK && ret != Z_STREAM_END
            error("Error in zlib deflate stream ($(ret)).")
        end

        if length(outbuf) - strm.avail_out > 0
            append!(output, outbuf[1:(length(outbuf) - strm.avail_out)])
        end
    end

    ret = ccall((:deflateEnd, libz), Int32, (Ptr{z_stream},), &strm)
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
    ret = ccall((:inflateInit_, libz),
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
        ret = ccall((:inflate, libz),
                    Int32, (Ptr{z_stream}, Int32),
                    &strm, Z_NO_FLUSH)
        if ret == Z_DATA_ERROR
            error("Error: input is not zlib compressed data.")
        elseif ret != Z_OK && ret != Z_STREAM_END
            error("Error in zlib inflate stream ($(ret)).")
        end

        if length(outbuf) - strm.avail_out > 0
            append!(output, outbuf[1:(length(outbuf) - strm.avail_out)])
        end
    end

    ret = ccall((:inflateEnd, libz), Int32, (Ptr{z_stream},), &strm)
    if ret == Z_STREAM_ERROR
        error("Error: zlib inflate stream was prematurely freed.")
    end

    output
end


# Packed binary-coded decimal (BCD) integers
# Two decimal digits per byte, each represented with 4 bits

abstract BCD <: Codec

function encode(::Type{BCD}, i::Integer, bigendian::Bool = false)
    if i < 0
        error("Integer must not be negative")
    end
    ndig = ndigits(i)
    ndig += isodd(ndig)
    v = digits(i, 10, ndig)
    nbytes = @compat trunc(Integer, ndig/2)
    out = Array(Uint8, nbytes)
    dj = 1-2*bigendian
    for i = 1:nbytes
        j = bigendian*length(v) + dj*2*(i-1) + 1-bigendian
        out[i] = (v[j]<<4) | v[j+dj]
    end
    return out
end

function decode(::Type{BCD}, v::Vector{Uint8}, bigendian::Bool = false)
    ret = 0
    if bigendian
        for i = 1:length(v)
            ret = 100*ret + 10 * (@compat Int(v[i]>>>4)) + (@compat Int(v[i]&0x0f))
        end
    else
        for i = length(v):-1:1
            ret = 100*ret + (@compat Int(v[i]>>>4)) + 10 * (@compat Int(v[i]&0x0f))
        end
    end
    return ret
end


end # module Codecs
