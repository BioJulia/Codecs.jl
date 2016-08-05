OSX/Linux: [![Build Status](https://travis-ci.org/dcjones/Codecs.jl.svg?branch=master)](https://travis-ci.org/dcjones/Codecs.jl) </br>
pkg.julialang.org: [![Codecs](http://pkg.julialang.org/badges/Codecs_0.3.svg)](http://pkg.julialang.org/?pkg=Codecs) </br>
pkg.julialang.org: [![Codecs](http://pkg.julialang.org/badges/Codecs_0.4.svg)](http://pkg.julialang.org/?pkg=Codecs)  </br>
pkg.julialang.org: [![Codecs](http://pkg.julialang.org/badges/Codecs_0.5.svg)](http://pkg.julialang.org/?pkg=Codecs)  </br>
Windows: [![Build status](https://ci.appveyor.com/api/projects/status/3fbti63h06xx024t/branch/master?svg=true)](https://ci.appveyor.com/project/randyzwitch/codecs-jl/branch/master) </br>


# Codecs

Basic data encoding and decoding protocols.

Currently implemented protocols: Base64, Zlib, Binary Coded Decimal.

## Synopsis

```julia
using Codecs

data = "Hello World!"
encoded = encode(Base64, encode(Zlib, data))
println(bytestring(encoded))
```

Output:
```
eNrzSM3JyVcIzy/KSVEEABxJBD4=
```

(Wow, that's inefficient.)


```julia
decoded = decode(Zlib, decode(Base64, encoded))
println(bytestring(decoded))
```

Output:
```
Hello World!
```

BCD is for encoding integers:
```julia
i = 2013
encoded = encode(BCD, i)
println(encoded)
encoded = encode(BCD, i, true)  # big endian digit order
println(encoded)
```

Output:
```
[0x31,0x02]
[0x20,0x13]
```
