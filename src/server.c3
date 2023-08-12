module http;
import std::io;
import std::net;
import std::thread;
import std::collections::list;

const MAX_HEADERS_SIZE = 8 << 10;
const READ_BUFFER_SIZE = 4 << 10;
const WRITE_BUFFER_SIZE = 4 << 10;

def HTTPServerClientList = List(<HTTPServerClient>);

struct HTTPServer
{
	Listener listener;
	HTTPServerClientList clients;
}

struct HTTPServerClient
{
	Thread thread;
	Socket sock;
	HTTPServerConfig* config;
}

struct HTTPServerConfig
{
	HTTPHandler handler;
	SocketOption[] options;
}

fn void! HTTPServer.init(&self, String host, String port, int backlog = 100)
{
	log(INFO, io::stderr().as_stream(), "listening on %s:%s", host, port);
	self.listener.init(TCP, host, port, backlog, REUSEADDR, REUSEPORT)!;
}

fn void! HTTPServer.close(&self)
{
}

/**
 * All options are applied to incoming connections.
 **/
fn void! HTTPServer.serve(&self, HTTPHandler handler, SocketOption... options)
{
	HTTPServerConfig config = {handler, options};
	while (true)
	{
		Socket! client_sock = self.listener.accept();
		if (catch err = client_sock)
		{
			log(ERROR, io::stderr().as_stream(), "Server accept(): %s", err);
		}
		self.clients.push({ .sock = client_sock, .config = &config });
		HTTPServerClient* client = self.clients.last();
		client.init();
		// TODO remove client upon completion
	}
}

fn void HTTPServerClient.init(&self)
{
	if (catch err = self.thread.create((ThreadFn)&HTTPServerClient.serve, self))
	{
		log(ERROR, io::stderr().as_stream(), "Client thread::create(): %s", err);
		return;
	}
}

fn int HTTPServerClient.serve(&self)
{
	defer @ok(self.sock.close());
	foreach (o : self.config.options)
	{
		if (catch self.sock.set_option(o)) return 1;
	}

	char[READ_BUFFER_SIZE] read_buffer @noinit;
	char[WRITE_BUFFER_SIZE] write_buffer @noinit;
	ReadBuffer read_buf;
	ReadBuffer write_buf;
	read_buf.init(self.sock.as_stream(), read_buffer[..]);
	write_buf.init(self.sock.as_stream(), write_buffer[..]);

	char[MAX_HEADERS_SIZE] buffer @noinit;
	LimitReader sock_limit;
	sock_limit.init(read_buf.as_stream(), buffer.len);
	Scanner sc;
	sc.init(sock_limit.as_stream(), buffer[..]);

	HTTPRequest req;
	HTTPResponse resp;
	do
	{
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
		self.config.handler.handle(null, &req, &resp);
		if (catch resp.write_stream(self.sock.as_stream())) return 2;
	} while (req.next());
	return 0;
}