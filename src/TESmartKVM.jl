"""
    TESmartKVM

This package contains minimal support code to control a remote TESmart KVM switch using
the documented protocol [1] as well as the undocumented extensions from [2] for changing
ip and port.

[1] https://support.tesmart.com/hc/en-us/articles/10270214101913-Download-Protocols
[2] https://github.com/pschmitt/tesmart.sh/blob/master/tesmart.sh
"""
module TESmartKVM

using Sockets

# TODO: Could support RS232
struct Device
    ip::IPAddr
    port::UInt16
end

abstract type Connection end
struct TCPConnection <: Connection
    dev::Device
    socket::TCPSocket
end

function rpc!(c::TCPConnection, cmd::NTuple{6, UInt8})
    write(getfield(c, :socket), cmd)
    tuple(read(getfield(c, :socket), 6)...)
end

function rpc!(c::TCPConnection, s::String)
    write(getfield(c, :socket), s)
    reply = String(read(getfield(c, :socket), 2))
    @assert reply == "OK"
    return nothing
end

function ip_query!(c::TCPConnection, s::String)
    write(getfield(c, :socket), s)
    reply = String(read(getfield(c, :socket), 19))
end

function Base.getproperty(c::TCPConnection, s::Symbol)
    if s === :input
        reply = rpc!(c, (0xAA, 0xBB, 0x03, 0x10, 0x00, 0xEE))
        @assert reply[1:4] == (0xaa, 0xbb, 0x03, 0x11)
        @assert reply[6] == 0x16
        # The read is zero-indexed in the protocol. For consistency, both with
        # julia and the labeling on the device, we use 1 indexing everywhere
        return reply[5] + 1
    elseif s === :muted
        error("We do not know how to query this")
    elseif s === :ip
        reply = ip_query!(c, "IP?")
        @assert reply[1:3] == "IP:"
        @assert reply[end] == ';'
        return parse(IPv4, reply[4:end])
    elseif s === :gateway
        reply = ip_query!(c, "GW?")
        @assert reply[1:3] == "GW:"
        @assert reply[end] == ';'
        return parse(IPv4, reply[4:end])
    elseif s === :netmask
        reply = ip_query!(c, "MA?")
        @assert reply[1:3] == "MA:"
        @assert reply[end] == ';'
        return parse(IPv4, reply[4:end])
    elseif s === :port
        reply = ip_query!(c, "PT?")
        @assert reply[1:3] == "PT:"
        @assert reply[end] == ';'
        return parse(UInt16, reply[4:end])
    end
end

function Base.setproperty!(c::TCPConnection, s::Symbol, v)
    if s === :input
        ui = UInt8(v::Integer)
        reply = rpc!(c, (0xAA, 0xBB, 0x03, 0x01, ui, 0xEE))
        @assert reply[1:4] == (0xaa, 0xbb, 0x03, 0x11)
        @assert reply[6] == 0x16
        # The read is zero-indexed in the protocol. For consistency, both with
        # julia and the labeling on the device, we use 1 indexing everywhere
        @assert reply[5] == ui
        return ui
    elseif s === :muted
        write(c.socket, (0xAA, 0xBB, 0x03, 0x02, v ? 0x01 : 0x00, 0xEE))
    elseif s === :active_input_detection
        write(c.socket, (0xAA, 0xBB, 0x03, 0x81, v ? 0x01 : 0x00, 0xEE))
    elseif s === :ip
        v::IPv4Addr
        rpc!(c, "IP: $v;")
    elseif s === :gateway
        v::IPv4Addr
        rpc!(c, "GW: $v;")
    elseif s === :netmask
        # TOOD: Julia should probably have a dedicated netmask type
        v::IPv4Addr
        rpc!(c, "MA: $v;")
    elseif s === :port
        rpc!(c, "PT: $(string(v::UInt16, base=10));")
    end
end

function Sockets.connect(d::Device)
    TCPConnection(Sockets.connect(d.ip, d.port))
end

end
