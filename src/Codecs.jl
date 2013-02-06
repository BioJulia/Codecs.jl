
module Codecs

import Iterators.partition

export base64, encode, decode

abstract Codec


encode(codec::Codec, s::String) = encode(codec, convert(Vector{Uint8}, s))


# RFC3548/RFC4648 base64 codec

type Base64 <: Codec end
const base64 = Base64()

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

# TODO: base64 variants, base32, base16, etc.

end # module Codecs

