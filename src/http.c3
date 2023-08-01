module http;
import std::io;

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

fault HTTPError
{
	INVALID_HEADER_NAME,
	INVALID_HEADER,
	TOO_MANY_HEADERS,
	INVALID_REQUEST,
	DUPLICATE_ROUTE,
	INVALID_ROUTE,
}

struct HTTPHandler
{
	HTTPHandlerInterface *fns;
	void* data;
}

def HTTPHandleFn = fn void! (HTTPHandler, HTTPRequest *req, HTTPResponse *resp);

struct HTTPHandlerInterface
{
	HTTPHandleFn handle_fn;
}

fn void! HTTPHandler.handle(self, HTTPRequest* req, HTTPResponse* resp) @inline
{
	if (HTTPHandleFn func = self.fns.handle_fn) return func(self, req, resp);
	return IoError.UNSUPPORTED_OPERATION?;
}