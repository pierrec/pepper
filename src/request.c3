module http;
import std::io;
import http::url;

// https://www.rfc-editor.org/rfc/rfc7230.html#section-3.1.1
struct HTTPRequest
{
    HTTPMethod method;
    Url        url;
    HTTPProto  proto;
    HTTPHeader header;
    HTTPBody   body;
}

fn void! HTTPRequest.read_from(&self, Scanner* sc, Stream src)
{
    // Status line.
    char[] line = scan(sc, "\r\n", HTTPError.INVALID_REQUEST)!;
	$if HTTP_SERVER_LOG:
		io::printfn("REQUEST line=%s", line);
	$endif
	usz i = index_of(line, ' ', HTTPError.INVALID_REQUEST)!;
    self.method = match_enum(HTTPMethod, line[:i])!;

    line = line[i + 1..];
	i = index_of(line, ' ', HTTPError.INVALID_REQUEST)!;
	String raw_url = (String)line[:i];
	self.url.init(raw_url)!;

    line = line[i + 1..];
	self.proto = match_enum(HTTPProto, line)!;

    // Headers.
    self.header.scan(sc)!;

    // Body.
    usz limit;
    char[] remaining = sc.flush();
    if (try clen = self.header.get("Content-Length"))
    {
        usz! l = clen.to_uint();
        if (catch l) return HTTPError.INVALID_REQUEST?;
        limit = l;
		if (limit < remaining.len) return HTTPError.INVALID_REQUEST?;
        limit -= remaining.len;
        // No need to copy remaining as the scanner is no longer in use.
    }
    else
    {
		if (remaining.len > 0) return HTTPError.INVALID_REQUEST?;
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

    written += self.header.write_stream(dst)!;
    written += self.body.as_stream().copy_to(dst)!;

    return written;
}

/**
 * On requests with a method of POST, PUT or PATCH, parse the body for
 * form values and return them.
 **/
fn FormData! HTTPRequest.parse_form(&self, Allocator* allocator)
{
	switch (self.method)
	{
		case POST:
		case PUT:
		case PATCH:
			FormData fd;
			fd.init(self.body.as_stream(), allocator)!;
			return fd;
		default:
			return {};
	}
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
	.write_stream_fn = fn(s, dst) => ((HTTPBody*)s.data).write_stream(dst),
};

fn usz! HTTPBody.write_stream(&self, Stream writer)
{
	usz n;
	if (self.data.len)
	{
		n += writer.write(self.data)!;
		self.data = {};
	}
	n += self.reader.as_stream().copy_to(writer)!;
	return n;
}

struct FormData
{
	Allocator* allocator;
	String data;
}

fn void! FormData.init(&self, Stream reader, Allocator* allocator)
{
	ByteWriter bw;
	bw.init(.using = allocator);
	reader.copy_to(bw.as_stream())!;
	String data = url::url_decode(bw.as_str());
	*self = { .allocator = allocator, .data = data };
}

fn void! FormData.free(&self)
{
	if (self.allocator)
	{
		self.allocator.free(self.data)!;
		*self = {};
	}
}

fn String! FormData.get(self, String name)
{
	if (name.len == 0) return SearchResult.MISSING?;
	String s = self.data;
	while (true)
	{
		usz start = s.index_of_char('=')!;
		String key = s[:start];
		s = s[start + 1..];
		usz! end = s.index_of_char('&');
		if (catch end) return key == name ? s : SearchResult.MISSING?;
		if (key == name) return s[:end];
		s = s[end + 1..];
	}
}