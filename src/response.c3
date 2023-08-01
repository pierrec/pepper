module http;
import std::io;
import std::collections::list;

// https://developer.mozilla.org/en-US/docs/Web/HTTP/Status
// Status code values are in the following ranges:
// Informational responses (100 – 199)
// Successful responses (200 – 299)
// Redirection messages (300 – 399)
// Client error responses (400 – 499)
// Server error responses (500 – 599)
def HTTPStatusCode = ushort;

fn bool HTTPStatusCode.is_valid(self)
{
    return self - 100 < 500;
}

// https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml
const String[*] CODES  = {
	[100 - 100] = "Continue",
	[101 - 100] = "Switching Protocols",
	[102 - 100] = "Processing",
	[103 - 100] = "Early Hints",
	[200 - 100] = "OK",
	[201 - 100] = "Created",
	[202 - 100] = "Accepted",
	[203 - 100] = "Non-Authoritative Information",
	[204 - 100] = "No Content",
	[205 - 100] = "Reset Content",
	[206 - 100] = "Partial Content",
	[207 - 100] = "Multi-Status",
	[208 - 100] = "Already Reported",
	[226 - 100] = "IM Used",
	[300 - 100] = "Multiple Choices",
	[301 - 100] = "Moved Permanently",
	[302 - 100] = "Found",
	[303 - 100] = "See Other",
	[304 - 100] = "Not Modified",
	[305 - 100] = "Use Proxy",
	[306 - 100] = "(Unused)",
	[307 - 100] = "Temporary Redirect",
	[308 - 100] = "Permanent Redirect",
	[400 - 100] = "Bad Request",
	[401 - 100] = "Unauthorized",
	[402 - 100] = "Payment Required",
	[403 - 100] = "Forbidden",
	[404 - 100] = "Not Found",
	[405 - 100] = "Method Not Allowed",
	[406 - 100] = "Not Acceptable",
	[407 - 100] = "Proxy Authentication Required",
	[408 - 100] = "Request Timeout",
	[409 - 100] = "Conflict",
	[410 - 100] = "Gone",
	[411 - 100] = "Length Required",
	[412 - 100] = "Precondition Failed",
	[413 - 100] = "Content Too Large",
	[414 - 100] = "URI Too Long",
	[415 - 100] = "Unsupported Media Type",
	[416 - 100] = "Range Not Satisfiable",
	[417 - 100] = "Expectation Failed",
	[418 - 100] = "(Unused)",
	[421 - 100] = "Misdirected Request",
	[422 - 100] = "Unprocessable Content",
	[423 - 100] = "Locked",
	[424 - 100] = "Failed Dependency",
	[425 - 100] = "Too Early",
	[426 - 100] = "Upgrade Required",
	[428 - 100] = "Precondition Required",
	[429 - 100] = "Too Many Requests",
	[431 - 100] = "Request Header Fields Too Large",
	[451 - 100] = "Unavailable For Legal Reasons",
	[500 - 100] = "Internal Server Error",
	[501 - 100] = "Not Implemented",
	[502 - 100] = "Bad Gateway",
	[503 - 100] = "Service Unavailable",
	[504 - 100] = "Gateway Timeout",
	[505 - 100] = "HTTP Version Not Supported",
	[506 - 100] = "Variant Also Negotiates",
	[507 - 100] = "Insufficient Storage",
	[508 - 100] = "Loop Detected",
	[510 - 100] = "Not Extended (OBSOLETED)",
	[511 - 100] = "Network Authentication Required",
	[599 - 100] = "",
};

fn String HTTPStatusCode.as_str(self)
{
	if (!self.is_valid()) return "";
    return CODES[self - 100];
}

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

fn usz! HTTPResponse.write_to(&self, Stream dst)
{
	if (!self.status.is_valid()) return HTTPResponseError.INVALID_STATUS?;

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