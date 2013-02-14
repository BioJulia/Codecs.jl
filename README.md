
# Codecs

Basic data encoding and decoding protocols.

Currently implemented protocols: Base64, Zlib.

## Synopsis

```julia
using Codecs

data = "Hello World!"
encoded = encode(Base64, encode(Zlib, data))
println(bytestring(encoded))
```

```
eNrzSM3JyVcIzy/KSVEEABxJBD4=
```

(Wow, that's inefficient.)


```julia
decoded = decode(Zlib, decode(Base64, encoded))
println(bytestring(decoded))
```

```
Hello World!
```


