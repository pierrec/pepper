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
	[100 - 100] = "100Continue",
	[101 - 100] = "101Switching Protocols",
	[102 - 100] = "102Processing",
	[103 - 100] = "103Early Hints",
	[200 - 100] = "200OK",
	[201 - 100] = "201Created",
	[202 - 100] = "202Accepted",
	[203 - 100] = "203Non-Authoritative Information",
	[204 - 100] = "204No Content",
	[205 - 100] = "205Reset Content",
	[206 - 100] = "206Partial Content",
	[207 - 100] = "207Multi-Status",
	[208 - 100] = "208Already Reported",
	[226 - 100] = "226IM Used",
	[300 - 100] = "300Multiple Choices",
	[301 - 100] = "301Moved Permanently",
	[302 - 100] = "302Found",
	[303 - 100] = "303See Other",
	[304 - 100] = "304Not Modified",
	[305 - 100] = "305Use Proxy",
	[306 - 100] = "306(Unused)",
	[307 - 100] = "307Temporary Redirect",
	[308 - 100] = "308Permanent Redirect",
	[400 - 100] = "400Bad Request",
	[401 - 100] = "401Unauthorized",
	[402 - 100] = "402Payment Required",
	[403 - 100] = "403Forbidden",
	[404 - 100] = "404Not Found",
	[405 - 100] = "405Method Not Allowed",
	[406 - 100] = "406Not Acceptable",
	[407 - 100] = "407Proxy Authentication Required",
	[408 - 100] = "408Request Timeout",
	[409 - 100] = "409Conflict",
	[410 - 100] = "410Gone",
	[411 - 100] = "411Length Required",
	[412 - 100] = "412Precondition Failed",
	[413 - 100] = "413Content Too Large",
	[414 - 100] = "414URI Too Long",
	[415 - 100] = "415Unsupported Media Type",
	[416 - 100] = "416Range Not Satisfiable",
	[417 - 100] = "417Expectation Failed",
	[418 - 100] = "418(Unused)",
	[421 - 100] = "421Misdirected Request",
	[422 - 100] = "422Unprocessable Content",
	[423 - 100] = "423Locked",
	[424 - 100] = "424Failed Dependency",
	[425 - 100] = "425Too Early",
	[426 - 100] = "426Upgrade Required",
	[428 - 100] = "428Precondition Required",
	[429 - 100] = "429Too Many Requests",
	[431 - 100] = "431Request Header Fields Too Large",
	[451 - 100] = "451Unavailable For Legal Reasons",
	[500 - 100] = "500Internal Server Error",
	[501 - 100] = "501Not Implemented",
	[502 - 100] = "502Bad Gateway",
	[503 - 100] = "503Service Unavailable",
	[504 - 100] = "504Gateway Timeout",
	[505 - 100] = "505HTTP Version Not Supported",
	[506 - 100] = "506Variant Also Negotiates",
	[507 - 100] = "507Insufficient Storage",
	[508 - 100] = "508Loop Detected",
	[510 - 100] = "510Not Extended (OBSOLETED)",
	[511 - 100] = "511Network Authentication Required",
	[599 - 100] = "",
};

fn String HTTPStatusCode.as_str(self)
{
	if (!self.is_valid()) return "";
    return CODES[self - 100][:3];
}

fn String HTTPStatusCode.as_message(self)
{
	if (!self.is_valid()) return "";
    return CODES[self - 100][3..];
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

fn void HTTPResponse.init(&self)
{
	*self = { .status = 200, .proto = HTTP1_1 };
}

fn usz! HTTPResponse.write_stream(&self, Stream dst)
{
	defer @ok(self.body.close());
	if (!self.status.is_valid()) return HTTPResponseError.INVALID_STATUS?;

	//self.header.set("Connection", "close")!;

	usz written;

	DString status;
	status.tinit();
	status.printf("%s %d %s\r\n", self.proto.name, self.status, self.status);
	written += dst.write(status.as_str())!;

	written += self.header.write_stream(dst)!;
	written += self.body.copy_to(dst)!;

	return written;
}