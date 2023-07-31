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

fn void HTTPResponse.init(&self, Allocator* allocator)
{
	*self = { .status = 200, .proto = HTTP1_1 };
	self.header.init(allocator);
}

fn void! HTTPResponse.free(&self)
{
	self.header.del("Connection")!!;
	self.header.free()!;
}

fn usz! HTTPResponse.write_to(&self, Stream dst)
{
	if (!self.status.is_valid()) return HTTPResponseError.INVALID_STATUS?;

	// NB. remove the here-added headers in free().
	self.header.set("Connection", "close")!;

	usz written;

	DString status;
	status.tinit();
	status.printf("%s %d %s\r\n", self.proto.name, self.status, self.status);
	written += dst.write(status.as_str())!;

	written += self.header.write_to(dst)!;
	written += self.body.copy_to(dst)!;

	return written;
}