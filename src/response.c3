module http::response;
import std::io;
import std::collections::list;

// https://www.rfc-editor.org/rfc/rfc7230.html#section-3.1.2
struct HTTPResponse
{
    HTTPStatusCode status;
    HTTPProto      proto;
    HTTPHeader     header;
    isz            content_length;
    Stream         body;
}

fault HTTPResponseError
{
    INVALID_PROTO,
    INVALID_PROTO_MAJOR,
    INVALID_PROTO_MINOR,
    INVALID_STATUS,
    INVALID_STATUSLINE,
    PARSE_ERROR,
}

fn void HTTPResponse.init(HTTPResponse* resp)
{
    *resp = { .status = 200, .proto = HTTP1_1 };
    resp.header.init();
}

fn void! HTTPResponse.free(&resp, Allocator* using = mem::heap())
{
    resp.header.del("Connection")!!;
    resp.header.free(using)!;
}

fn usz! HTTPResponse.write_to(&resp, Stream dst)
{
    if (!resp.status.is_valid()) return HTTPResponseError.INVALID_STATUS?;

    // NB. remove the here-added headers in free().
    resp.header.set("Connection", "close")!;

    usz written;

    DString status;
    status.tinit();
    status.printf("%s %d %s\r\n", resp.proto.name, resp.status, resp.status);
    written += dst.write(status.as_str())!;

    written += resp.header.write_to(dst)!;
    written += resp.body.copy_to(dst)!;

    return written;
}