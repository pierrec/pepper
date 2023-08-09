module http;
import std::io;
import std::net;

const MAX_HEADERS_SIZE = 8 << 10;
const READ_BUFFER_SIZE = 4 << 10;
const WRITE_BUFFER_SIZE = 4 << 10;

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
	log(INFO, io::stderr().as_stream(), "listening on %s:%s", host, port);
	srv.listener.init(TCP, host, port, backlog, REUSEADDR, REUSEPORT)!;
}

/**
 * All options are applied to incoming connections.
 **/
fn void! HTTPServer.serve(&srv, HTTPHandler handler, SocketOption... options)
{
	while (true)
	{
		Socket! client_sock = srv.listener.accept();
		if (catch err = client_sock)
		{
			log(ERROR, io::stderr().as_stream(), "[%s] accept(): %s", err);
		}
		if (catch err = serve_client(client_sock, options, handler))
		{
			log(ERROR, io::stderr().as_stream(), "[%s] serve_client(): %s", err);
		}
	}
}

fn void! serve_client(Socket sock, SocketOption[] options, HTTPHandler handler)
{
	defer sock.close()!!;
	foreach (o : options) sock.set_option(o)!;

	char[READ_BUFFER_SIZE] read_buffer @noinit;
	char[WRITE_BUFFER_SIZE] write_buffer @noinit;
	ReadBuffer read_buf;
	ReadBuffer write_buf;
	read_buf.init(sock.as_stream(), read_buffer[..]);
	write_buf.init(sock.as_stream(), write_buffer[..]);

	char[MAX_HEADERS_SIZE] buffer @noinit;
	LimitReader sock_limit;
	sock_limit.init(read_buf.as_stream(), buffer.len);
	Scanner sc;
	sc.init(sock_limit.as_stream(), buffer[..]);

	HTTPRequest req;
	HTTPResponse resp;
	resp.init();
	if (catch req.read_from(&sc, write_buf.as_stream()))
	{
		case HTTPError.INVALID_REQUEST:
			resp.status = 400;
		case SearchResult.MISSING:
			resp.status = 431;
		default:
			resp.status = 500;
	}

	handler.handle(null, &req, &resp);
	resp.write_stream(sock.as_stream())!;
}