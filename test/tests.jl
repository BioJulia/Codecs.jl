using Codecs
using Base.Test

n = [1,4,7,9,11,17,243,5247]
for i in n
    @test decode(BCD, encode(BCD, i)) == i
    @test decode(BCD, encode(BCD, i, true), true) == i
end
