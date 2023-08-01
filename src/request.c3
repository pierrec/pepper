module http;
import std::io;

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
    char[MAX_HEADER_LINE] buf;
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

fn void HTTPRequest.init(&self, Allocator* allocator)
{
    *self = {};
    self.header.init(allocator);
}

fn void! HTTPRequest.read_from(&self, Stream src)
{
    Scanner sc;
    sc.init(src, self.buf[..]);

    // Status line.
    char[] line = scan(&sc, "\r\n", HTTPError.INVALID_REQUEST)!;
	$if HTTP_SERVER_LOG:
		io::printfn("REQUEST line=%s", line);
	$endif
	usz i = index_of(line, ' ', HTTPError.INVALID_REQUEST)!;
    HTTPMethod method = match_enum(HTTPMethod, line[:i])!;

    line = line[i + 1..];
	i = index_of(line, ' ', HTTPError.INVALID_REQUEST)!;
	String raw_url = ((String)line[:i]).copy(self.header.allocator);
	self.url.init(raw_url)!;

    line = line[i + 1..];
	self.proto = match_enum(HTTPProto, line)!;

    // Headers.
    self.header.scan(&sc)!;

    // Body.
    usz limit;
    char[] remaining = sc.flush();
    if (try clen = self.header.get("Content-Length"))
    {
        usz! l = clen.to_uint();
        if (catch l) return HTTPRequestError.INVALID_CONTENTLENGTH?;
        limit = l;
		if (limit < remaining.len) return HTTPRequestError.INVALID_CONTENTLENGTH?;
        limit -= remaining.len;
        // No need to copy remaining as the scanner is no longer in use.
    }
    else
    {
		if (remaining.len > 0) return HTTPRequestError.INVALID_CONTENTLENGTH?;
    }
	self.body.init(remaining, src, limit);
}

fn usz! HTTPRequest.write_to(&self, Stream dst)
{
    usz written;

    DString str;
    str.tinit();
    str.printf("%s %s %s\r\n", self.method, self.url.path, self.proto.name);
    written += dst.write(str.as_str())!;

    written += self.header.write_to(dst)!;
    written += self.body.as_stream().copy_to(dst)!;

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

struct HTTPBody
{
	char[] data;
	LimitReader reader;
}

fn void HTTPBody.init(&self, char[] data, Stream reader, usz limit)
{
	*self = { .data = data };
	self.reader.init(reader, limit);
}

fn Stream HTTPBody.as_stream(&self)
{
	return { .fns = &bodyreader_interface, .data = self };
}

StreamInterface bodyreader_interface = {
	.read_fn = fn(s, bytes) => ((HTTPBody*)s.data).read(bytes),
};

fn usz! HTTPBody.read(&self, char[] bytes)
{
	usz n;
	if (self.data.len)
	{
		n = min(bytes.len, self.data.len);
		bytes[:n] = self.data[:n];
		self.data = self.data[n..];
		bytes = bytes[n..];
	}
	n += self.reader.read(bytes)!;
	return n;
}