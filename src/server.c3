module http;
import std::io;
import std::net;

const HTTP_SERVER_LOG = false;

struct HTTPServer
{
	Listener listener;
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
		if (catch err = serve_client(client_sock, options, handler))
		{
		}
	}
}

fn void! serve_client(Socket sock, SocketOption[] options, HTTPHandler handler)
{
	defer sock.close()!!;
	foreach (o : options) sock.set_option(o)!;

	char[MAX_HEADERS * MAX_HEADER_LINE] buffer @noinit;
	ArenaAllocator arena;
	arena.init(buffer[..]);

	HTTPRequest req;
	req.init(&arena);
	req.read_from(sock.as_stream())!;

	HTTPResponse resp;
	resp.init(&arena);

	if (catch err = handler.handle(&req, &resp))
	{
		io::printfn("[%s] %s %s", req.method, req.url.path, err);
		return;
	}
	resp.write_to(sock.as_stream())!;
}