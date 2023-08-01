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

const String[*] CODES  = {
	[100] = "Continue",
	[101] = "Switching Protocols",
	[102] = "Processing",
	[103] = "Early Hints",
	[200] = "OK",
	[201] = "Created",
	[202] = "Accepted",
	[203] = "Non-Authoritative Information",
	[204] = "No Content",
	[205] = "Reset Content",
	[206] = "Partial Content",
	[207] = "Multi-Status",
	[208] = "Already Reported",
	[226] = "IM Used",
	[300] = "Multiple Choices",
	[301] = "Moved Permanently",
	[302] = "Found",
	[303] = "See Other",
	[304] = "Not Modified",
	[305] = "Use Proxy",
	[306] = "(Unused)",
	[307] = "Temporary Redirect",
	[308] = "Permanent Redirect",
	[400] = "Bad Request",
	[401] = "Unauthorized",
	[402] = "Payment Required",
	[403] = "Forbidden",
	[404] = "Not Found",
	[405] = "Method Not Allowed",
	[406] = "Not Acceptable",
	[407] = "Proxy Authentication Required",
	[408] = "Request Timeout",
	[409] = "Conflict",
	[410] = "Gone",
	[411] = "Length Required",
	[412] = "Precondition Failed",
	[413] = "Content Too Large",
	[414] = "URI Too Long",
	[415] = "Unsupported Media Type",
	[416] = "Range Not Satisfiable",
	[417] = "Expectation Failed",
	[418] = "(Unused)",
	[421] = "Misdirected Request",
	[422] = "Unprocessable Content",
	[423] = "Locked",
	[424] = "Failed Dependency",
	[425] = "Too Early",
	[426] = "Upgrade Required",
	[428] = "Precondition Required",
	[429] = "Too Many Requests",
	[431] = "Request Header Fields Too Large",
	[451] = "Unavailable For Legal Reasons",
	[500] = "Internal Server Error",
	[501] = "Not Implemented",
	[502] = "Bad Gateway",
	[503] = "Service Unavailable",
	[504] = "Gateway Timeout",
	[505] = "HTTP Version Not Supported",
	[506] = "Variant Also Negotiates",
	[507] = "Insufficient Storage",
	[508] = "Loop Detected",
	[510] = "Not Extended (OBSOLETED)",
	[511] = "Network Authentication Required",
	[599] = "",
};

fn String HTTPStatusCode.as_str(self)
{
	if (!self.is_valid()) return "";
    // https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml
    return CODES[self];
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