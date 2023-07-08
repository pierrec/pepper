module http::request;
import std::io;
import scanner;
import util;

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
    HTTPMethod method;
    Url        url;
    HTTPProto  proto;
    HTTPHeader header;
    HTTPBody   body;
}

fault HTTPRequestError
{
    INVALID_STATUSLINE,
    INVALID_METHOD,
    INVALID_PATH,
    INVALID_PROTO,
    INVALID_HEADER,
    INVALID_CONTENTLENGTH,
}

fn String HTTPProto.as_str(self)
{
    switch (self)
    {
        case HTTP1_0: return "HTTP/1.0";
        case HTTP1_1: return "HTTP/1.1";
    }
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
    req.header.init();
}

fn void! HTTPRequest.free(&req, Allocator* using = mem::heap())
{
    req.url.free(using)!;
    req.header.free(using)!;
    using.free(req.body.data)!;
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
    //io::printfn("headers processed");

    if (!sc.scan('\n')!) return HTTPRequestError.INVALID_HEADER?;
    if (sc.as_str() != "\r") return HTTPRequestError.INVALID_HEADER?;

    // Body.
    if (try clen = req.header.get("Content-Length"))
    {
        usz! limit = clen.to_uint();
        if (catch limit) return HTTPRequestError.INVALID_CONTENTLENGTH?;

        char[] remaining = sc.remaining_bytes();
        if (limit < remaining.len) return HTTPRequestError.INVALID_CONTENTLENGTH?;

        remaining = util::dup_bytes(remaining, req.body.data, using)!;
        req.body.init(remaining, src, limit - remaining.len);
    }
    //io::printfn("body processed");
}

fn usz! HTTPRequest.write_to(&req, Stream dst)
{
    usz written;

    DString str;
    str.tinit();
    str.printf("%s %s %s\r\n", req.method, req.url.path, req.proto.as_str());
    written += dst.write(str.as_str())!;

    written += req.header.write_to(dst)!;
    //written += req.body.as_stream().copy_to(dst)!;

    return written;
}