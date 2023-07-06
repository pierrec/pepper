module http::request;
import std::io;
import scanner;

const MAX_HEADER_LINE = 1024;

enum HTTPMethod : char
{
    GET,
    HEAD,
    POST,
    PUT,
    DELETE,
    CONNECT,
    OPTIONS,
    TRACE,
    PATCH,
}

enum HTTPProto : char
{
    HTTP1_0,
    HTTP1_1,
}

// https://www.rfc-editor.org/rfc/rfc7230.html#section-3.1.1
struct HTTPRequest
{
    Allocator* allocator;
    HTTPMethod method;
    Url        url;
    HTTPProto  proto;
    HTTPHeader header;
    Stream     body;
}

fault HTTPRequestError
{
    INVALID_STATUSLINE,
    INVALID_METHOD,
    INVALID_PATH,
    INVALID_PROTO,
    INVALID_HEADER,
}

fn HTTPMethod! to_method(String data) @local
{
    foreach (i, m : HTTPMethod.names)
    {
        if (m == data) return (HTTPMethod)i;
    }
    return SearchResult.MISSING?;
}

fn void HTTPRequest.init(&req)
{
    *req = {};
}

fn void! HTTPRequest.free(&req, Allocator* using = mem::heap())
{
    req.url.free(using)!;
    req.header.free(using)!;
}

fn void! HTTPRequest.read_from(&req, Stream src, Allocator* using = mem::heap())
{
    char[MAX_HEADER_LINE] buf;
    Scanner sc;
    sc.init(src, buf[..]);

    // Status line.
    if (!sc.scan(' ')!) return HTTPRequestError.INVALID_METHOD?;
    HTTPMethod! method = to_method(sc.as_str());
    if (catch method) return HTTPRequestError.INVALID_METHOD?;
    req.method = method;
    if (!sc.scan(' ')!) return HTTPRequestError.INVALID_PATH?;
    String str = sc.as_str().copy(using);
    req.url.init(str)!;
    if (!sc.scan('\n')!) return HTTPRequestError.INVALID_PROTO?;
    String proto = sc.as_str();
    switch (proto)
    {
        case "HTTP/1.0\r":
            req.proto = HTTPProto.HTTP1_0;
        case "HTTP/1.1\r":
            req.proto = HTTPProto.HTTP1_1;
        default:
            return HTTPRequestError.INVALID_PROTO?;
    }

    // Headers.
    req.header.scan(&sc, using)!;
    if (!sc.scan('\n')!) return HTTPRequestError.INVALID_HEADER?;
    if (sc.as_str() != "\r") return HTTPRequestError.INVALID_HEADER?;

    // Body.
    String rest = sc.as_str().copy(using);
    req.body = BodyReader{ .data = rest, .reader = src }.as_stream();
}

struct BodyReader
{
    char[] data;
    Stream reader;
}

fn Stream BodyReader.as_stream(&self)
{
    return { .fns = &bodyreader_interface, .data = &self };
}

fn usz! BodyReader.read(&self, char[] bytes)
{
    usz n = min(bytes.len, self.data.len);
    bytes[:n] = self.data[:n];
    self.data = self.data[n..];
    bytes = bytes[n..];
    if (bytes.len > 0) n += self.reader.read(bytes)!;
    return n;
}

StreamInterface bodyreader_interface = {
    . read_fn = fn(s, char[] bytes) => ((BodyReader*)s.data).read(bytes),
};