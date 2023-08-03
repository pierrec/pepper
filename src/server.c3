module http;
import std::io;
import std::net;

const HTTP_SERVER_LOG = false;
const MAX_HEADERS_SIZE = 16 << 10;

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

	char[MAX_HEADERS_SIZE] buffer @noinit;
	Scanner sc;
	sc.init(sock.as_stream(), buffer[..]);

	HTTPRequest req;
	HTTPResponse resp;
	resp.init();
	if (catch req.read_from(&sc, sock.as_stream()))
	{
		case HTTPError.INVALID_REQUEST:
			resp.status = 400;
		case SearchResult.MISSING:
			resp.status = 431;
		default:
			resp.status = 500;
	}

	if (catch err = handler.handle(&req, &resp))
	{
		io::printfn("[%s] %s %s", req.method, req.url.path, err);
		return;
	}
	resp.write_stream(sock.as_stream())!;
}