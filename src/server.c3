module http;
import std::io;
import std::net;

struct HTTPServer
{
	Listener listener;
}

def HTTPHandlerFn = fn void (HTTPHandler, HTTPRequest *req, HTTPResponse *resp);
struct HTTPHandlerInterface
{
	HTTPHandlerFn handler_fn;
}

struct HTTPHandler
{
	HTTPHandlerInterface *fns;
	void* data;
}

fn void! HTTPServer.init(&srv, String address, int backlog = 100)
{
	String host = address;
	String port = "80";
	if (try i = address.index_of_char(':'))
	{
		host = address[:i];
		port = address[i + 1..];
	}
	srv.listener.init(TCP, host, port, backlog, REUSEADDR, REUSEPORT)!;
}

/**
 * All options are applied to incoming connections.
 **/
fn void! HTTPServer.serve(&srv, HTTPHandler handler, SocketOption... options)
{
	while (true)
	{
		Socket client_sock = srv.listener.accept()!;
		if (catch err = serve_client(client_sock, options, handler)) io::printfn("serve error: %s", err);
	}
}

fn void! serve_client(Socket sock, SocketOption[] options, HTTPHandler handler)
{
	defer sock.close()!!;
	foreach (o : options) sock.set_option(o)!;

	char[512 << 10] buffer;
	ArenaAllocator arena;
	arena.init(buffer[..]);

	HTTPRequest req;
	req.init(&arena);
	req.read_from(sock.as_stream())!;

	HTTPResponse resp;
	resp.init(&arena);

	if (HTTPHandlerFn func = handler.fns.handler_fn) func(handler, &req, &resp);
	resp.write_to(sock.as_stream())!;
}