module http;
import std::collections::list;
import std::io;
import std::net;
import std::thread;
import std::thread::pool;

const MAX_HEADERS_SIZE = 8 << 10;
const READ_BUFFER_SIZE = 4 << 10;
const WRITE_BUFFER_SIZE = 4 << 10;

def ClientList = List(<Client>) @local;
def ThreadPool = ThreadPool(<4 + 1>);

struct HTTPServer
{
	Allocator* allocator;
	Listener listener;
	ThreadPool pool;
	HTTPHandler handler;
	SocketOption[] options;

	Mutex mu;
	ClientList clients;
}

struct Client
{
	HTTPServer* server;
	Socket sock;
}

fn void! HTTPServer.init(&self, String host, String port, int backlog = 100, Allocator* allocator)
{
	*self = { .allocator = allocator };
	self.mu.init()!;
	self.clients.init(.using = allocator);
	self.pool.init()!;
	log(INFO, io::stderr().as_stream(), "listening on %s:%s", host, port);
	self.listener.init(TCP, host, port, backlog, REUSEADDR, REUSEPORT)!;
}

fn void! HTTPServer.close(&self)
{
	if (self.allocator)
	{
		self.pool.stop_and_destroy()!;
		self.clients.free();
		self.mu.destroy()!;
		*self = {};
	}
}

/**
 * @require self.allocator != null
 * All options are applied to incoming connections.
 **/
fn void! HTTPServer.serve(&self, HTTPHandler handler, SocketOption... options)
{
	self.handler = handler;
	self.options = options;
	while (true)
	{
		Socket! client_sock = self.listener.accept();
		if (catch err = client_sock)
		{
			log(ERROR, io::stderr().as_stream(), "Server accept(): %s", err);
		}
		self.mu.lock()!!;
		self.clients.push({ self, client_sock })!!;
		Client* client = self.clients.last();
		self.mu.unlock()!!;
		//while (!self.pool.push((ThreadFn)&Client.serve, client)!!) {}
		self.pool.push((ThreadFn)&Client.serve, client)!!;
	}
}

fn int Client.serve(&self)
{
	defer @ok(self.sock.close());
	foreach (o : self.server.options)
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
		self.server.handler.handle(null, &req, &resp);
		if (catch resp.write_stream(self.sock.as_stream())) return 2;
	} while (req.next());
	return 0;
}