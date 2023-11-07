# TESmartKVM

This is just a quick hack I put together, if anyone wants to make this a real package, be my guest.

Usage:
```
julia> connect(TESmartKVM.Device(ip"192.168.1.10", 5000))

julia> c.input = 5 # Switch input

julia> c.input # Read current input
0x05
```