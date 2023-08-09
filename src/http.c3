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

def HTTPHandleFn = fn void (HTTPHandler, void *context, HTTPRequest *req, HTTPResponse *resp);

struct HTTPHandlerInterface
{
	HTTPHandleFn handle_fn;
}

fn void HTTPHandler.handle(self, void *ctx, HTTPRequest* req, HTTPResponse* resp) @inline
{
	self.fns.handle_fn(self, ctx, req, resp);
}

const LogLevel LOG_LEVEL = INFO;

enum LogLevel
{
	NONE,
	INFO,
	WARNING,
	ERROR,
	DEBUG,
}

macro void log(LogLevel $level, Stream writer, String format, args...)
{
	$if (LOG_LEVEL != NONE && $level <= LOG_LEVEL):
		io::printf("[%s] ", $level);
		io::printfn(format, ...args);
	$endif
}