module http::dial;
import std::io;
import std::net;
import libc;

enum Network : char (int domain, int type)
{
    TCP  (os::AF_INET, net::SOCK_STREAM),
    TCP6 (os::AF_INET6, net::SOCK_STREAM),
    UDP  (os::AF_INET, net::SOCK_DGRAM),
    UDP6 (os::AF_INET6, net::SOCK_DGRAM),
}

fault SocketError
{
    ADDRINFO,
    DIAL,
    LISTEN,
    ACCEPT,
    WRITE,
    READ,
}

struct Socket
{
    NativeSocket sock;
}

fn Socket! dial(Network network, String host, String port)
{
    AddrInfo* ai = addrinfo(network, host, port)!;
    defer os::freeaddrinfo(ai);
    while (ai)
    {
        NativeSocket sockfd = os::socket(ai.ai_family, ai.ai_socktype, ai.ai_protocol);
        if (sockfd > 0)
        {
            int errcode = os::connect(sockfd, ai.ai_addr, ai.ai_addrlen);
            // Keep the first successful connection.
            if (errcode == 0) return { .sock = sockfd };
        }
        ai = ai.ai_next;
    }
    return SocketError.DIAL?;
}

fn Stream Socket.as_stream(Socket* s)
{
    return { .fns = &socket_interface, .data = s };
}

StreamInterface socket_interface = {
    .read_fn = fn(s, char[] bytes) => ((Socket*)s.data).read(bytes) @inline,
    .write_fn = fn(s, char[] bytes) => ((Socket*)s.data).write(bytes) @inline,
    .close_fn = fn(s) => ((Socket*)s.data).close(),
};

fn usz! Socket.read(Socket* s, char[] bytes)
{
    isz n = libc::read(s.sock, bytes.ptr, bytes.len);
    if (n < 0) return SocketError.READ?;
    return (usz)n;
}

fn usz! Socket.write(Socket* s, char[] bytes)
{
    isz n = libc::write(s.sock, bytes.ptr, bytes.len);
    if (n < 0) return SocketError.WRITE?;
    return (usz)n;
}

fn void! Socket.close(Socket* s)
{
    s.sock.close()!;
}

struct Listener
{
    Socket socket;
	Socklen_t ai_addrlen;
	// TODO proper way to get the maximum size of sockaddr_storage
	// https://learn.microsoft.com/en-us/previous-versions/windows/desktop/legacy/ms740504(v=vs.85)
	char[128] ai_addr_storage;
}

fn void! Listener.init(Listener* ln, Network network, String host, String port, int backlog = 10)
{
    AddrInfo* ai = addrinfo(network, host, port)!;
    defer os::freeaddrinfo(ai);
    for (;ai;ai = ai.ai_next)
    {
        // Keep the first successful connection.
        NativeSocket sockfd = os::socket(ai.ai_family, ai.ai_socktype, ai.ai_protocol);
        if (sockfd < 0) continue;
        int errcode = os::bind(sockfd, ai.ai_addr, ai.ai_addrlen);
        if (errcode != 0) continue;
        errcode = os::listen(sockfd, backlog);
        if (errcode != 0) continue;

        *ln = {
            .socket = { .sock = sockfd },
            .ai_addrlen = ai.ai_addrlen,
        };
        mem::copy(&ln.ai_addr_storage, (void*)ai.ai_addr, ai.ai_addrlen);
        return;
    }
    return SocketError.LISTEN?;
}

fn Socket! Listener.accept(Listener* ln)
{
    NativeSocket sockfd = os::accept(ln.socket.sock, (SockAddrPtr)&ln.ai_addr_storage, &ln.ai_addrlen);
    //io::printfn(">> socket=%d accept sockfd=%d", ln.socket.sock, sockfd);
    if (sockfd < 0) return SocketError.ACCEPT?;
    return { .sock = sockfd };
}

fn void! Listener.close(Listener* ln)
{
    ln.socket.close()!;
}

fn AddrInfo*! addrinfo(Network network, String host, String port)
{
    ZString zhost = host.zstr_tcopy();
    ZString zport = port.zstr_tcopy();
    AddrInfo hints = { .ai_family = network.domain, .ai_socktype = network.type };
    AddrInfo* res;
    int errcode = os::getaddrinfo(zhost, zport, &hints, &res);
    if (errcode != 0) return SocketError.ADDRINFO?;
    return res;
}