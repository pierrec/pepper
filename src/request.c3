module http;
import std::io;

// https://www.rfc-editor.org/rfc/rfc7230.html#section-3.1.1
struct HTTPRequest
{
    HTTPMethod method;
    Url        url;
    String     proto;
    char       proto_major;
    char       proto_minor;
    HTTPHeader header;
    char[]     body;
}

fault HTTPRequestError
{
    INVALID_STATUSLINE,
    INVALID_METHOD,
    INVALID_URL,
    INVALID_PROTO,
}

fn void HTTPRequest.free(HTTPRequest* req)
{
    req.header.free();
}

fn usz! HTTPRequest.write_to(HTTPRequest* req, Stream out)
{
    // https://www.rfc-editor.org/rfc/rfc7230.html#section-3
    // https://www.rfc-editor.org/rfc/rfc7230.html#section-3.1.1
    DString msg;
    msg.tinit(req.method.name.len + req.url.path.len + req.header.size + 8);
    defer msg.free();
    msg.printf("%s %s %s/%d.%d\r\n", req.method.name, req.url.path, req.proto, req.proto_major, req.proto_minor);

    Stream msg_stream = msg.as_stream();
    usz written = req.header.write_to(msg_stream)!;

    written += out.write(msg.str())!;
    written += out.write(req.body)!;
    return written;
}

fn usz! HTTPRequest.parse(HTTPRequest* req, String str)
{
    usz! eol = str.index_of("\r\n");
    if (catch eol) return HTTPResponseError.INVALID_STATUSLINE?;
    String line = str[:eol];
    str = str[eol+2:];
    do METHOD:
    {
        foreach (m, name : HTTPMethod.names)
        {
            if (line.starts_with(name) && line.len > name.len && line[name.len] == ' ')
            {
                line = line[name.len+1:];
                req.method = (HTTPMethod)m;
                break METHOD;
            }
        }
        return HTTPRequestError.INVALID_METHOD?;
    };
    Cut c;
    c = cut(line, ' ');
    String url = c.before;
    if (url.len == 0) return HTTPRequestError.INVALID_URL?;
    line = c.after;
    // TODO parse url

    switch
    {
        case line.starts_with(HTTP10):
            req.proto = HTTP10;
            req.proto_major = '1';
            req.proto_minor = '0';
        case line.starts_with(HTTP11):
            req.proto = HTTP11;
            req.proto_major = '1';
            req.proto_minor = '1';
        default:
            return HTTPRequestError.INVALID_PROTO?;
    }
    line = line[req.proto.len:];

    usz hn = req.header.parse(str)!;
    req.body = hn < str.len ? str[hn:] : "";
}