
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
