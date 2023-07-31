module http;
import std::io;
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

enum HTTPProto : char (String name)
{
    HTTP1_0 ("HTTP/1.0"),
    HTTP1_1 ("HTTP/1.1"),
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

fn void HTTPRequest.init(&req)
{
    *req = {};
    req.header.init();
}

fn void! HTTPRequest.free(&req, Allocator* using = mem::heap())
{
//    req.url.free(using)!;
//    req.header.free(using)!;
//    using.free(req.body.data)!;
}

fn void! HTTPRequest.read_from(&req, Stream src, Allocator* using = mem::heap())
{
    char[MAX_HEADER_LINE] buf;
    Scanner sc;
    sc.init(src, buf[..]);

    // Status line.
    char[] line = scan(&sc, "\r\n", HTTPError.INVALID_REQUEST)!;
	//io::printfn("REQUEST line=%s", line);
	usz i = index_of(line, ' ', HTTPError.INVALID_REQUEST)!;
    HTTPMethod method = match_enum(HTTPMethod, line[:i])!;

    line = line[i + 1..];
	i = index_of(line, ' ', HTTPError.INVALID_REQUEST)!;
    req.url.init((String)line[:i])!;

    line = line[i + 1..];
	req.proto = match_enum(HTTPProto, line)!;

    // Headers.
    req.header.scan(&sc, using)!;

    // Body.
    if (try clen = req.header.get("Content-Length"))
    {
        usz! limit = clen.to_uint();
        if (catch limit) return HTTPRequestError.INVALID_CONTENTLENGTH?;

        char[] remaining = sc.flush();
        if (limit < remaining.len) return HTTPRequestError.INVALID_CONTENTLENGTH?;

        remaining = util::dup_bytes(remaining, req.body.data, using)!;
        req.body.init(remaining, src, limit - remaining.len);
    }
}

fn usz! HTTPRequest.write_to(&req, Stream dst)
{
    usz written;

    DString str;
    str.tinit();
    str.printf("%s %s %s\r\n", req.method, req.url.path, req.proto.name);
    written += dst.write(str.as_str())!;

    written += req.header.write_to(dst)!;
    //written += req.body.as_stream().copy_to(dst)!;

    return written;
}

macro match_enum($Type, data)
{
	foreach (i, v : $Type.values)
	{
		String s;
		$if $Type.associated.len:
			s = v.name;
		$else
			s = $Type.names[i];
		$endif
		if (s == data) return v;
	}
	return HTTPError.INVALID_REQUEST?;
}