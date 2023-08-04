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
	INVALID_REQUEST,
	TOO_MANY_HEADERS,
}

struct HTTPHandler
{
	HTTPHandlerInterface *fns;
	void* data;
	void* context;
}

def HTTPHandleFn = fn void! (HTTPHandler, void *context, HTTPRequest *req, HTTPResponse *resp);

struct HTTPHandlerInterface
{
	HTTPHandleFn handle_fn;
}

fn void! HTTPHandler.handle(self, void *ctx, HTTPRequest* req, HTTPResponse* resp) @inline
{
	if (HTTPHandleFn func = self.fns.handle_fn) return func(self, ctx, req, resp);
	return IoError.UNSUPPORTED_OPERATION?;
}