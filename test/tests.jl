#

const data = [1,4,7,9,11,17,243,5247]
const data8 = convert(Vector{UInt8}, reinterpret(UInt8, data))
const data_s = String(copy(data8))

function test_encoding(T)
    en_vec = encode(T, data8)
    @test encode(T, data_s) == en_vec
    en_str = String(copy(en_vec))
    @test decode(T, en_vec) == data8
    @test decode(T, en_str) == data8
end

test_encoding(Base64)
test_encoding(Zlib)

for i in data
    @test decode(BCD, encode(BCD, i)) == i
    @test decode(BCD, encode(BCD, i, true), true) == i
end

@test isa(Codecs.zlib_version(), String)
