
n = [1,4,7,9,11,17,243,5247]

@test reinterpret(Int, decode(Base64, encode(Base64, reinterpret(Uint8, n)))) == n

for i in n
    @test decode(BCD, encode(BCD, i)) == i
    @test decode(BCD, encode(BCD, i, true), true) == i
end
