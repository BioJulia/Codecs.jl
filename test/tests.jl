
n = [1,4,7,9,11,17,243,5247]
@test decode(Base64, encode(Base64, reinterpret(UInt8, n))) == reinterpret(UInt8, n)

for i in n
    @test decode(BCD, encode(BCD, i)) == i
    @test decode(BCD, encode(BCD, i, true), true) == i
end
