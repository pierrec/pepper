module http;
import http::handlers;
import http::handlers::texttemplate;
import std::io;

const DEFAULT_HOST = "localhost";
const DEFAULT_PORT = "8080";

fn void main(String[] args)
{
	String host = DEFAULT_HOST;
	String port = DEFAULT_PORT;
	for (usz i = 1; i < args.len; i++)
	{
		String arg = args[i];
		switch (arg)
		{
			case "-h":
				i++;
				if (i == args.len)
				{
					error("missing host");
					return;
				}
				host = args[i];
			case "-p":
				i++;
				if (i == args.len)
				{
					error("missing port");
					return;
				}
				port = args[i];
			default:
				error("invalid option '%s'", arg);
				return;
		}
	}
	start_server(host, port)!!;
}

fn void error(String msg, String... args)
{
	io::stderr().printfn(msg, args);
}

fn void usage()
{
	io::printf(`Usage: pepper [options]
where options can be:
	-h listening host (default=%s)
	-p listening port (default=%s)
`, DEFAULT_HOST, DEFAULT_PORT);
}

def TextTemplate = texttemplate::TextTemplate(<Data>);

struct Data
{
	int x;
}

fn void! start_server(String host, String port)
{
	HTTPServer server;
	server.init(host, port, 100, mem::temp())!;
	StaticHandler h;
	h.init("/Users/pierre/sandbox/src/git.sr.ht/pierrec/c3/pepper");
	FileTemplateHandler fth;
	defer @ok(fth.free());
	fth.init("/Users/pierre/sandbox/src/git.sr.ht/pierrec/c3/pepper/resources/module.html", .cached = false)!;
	TextTemplateHandler text;
	text.init("Hello world!!")!;

	HTTPRouter r;
	r.init({}, mem::temp(),
		{ GET, "/", text.as_httphandler() },
		{ POST, "/", fth.as_httphandler() },
		{ GET, "/doc/{module}/{id}/type", fth.as_httphandler() },
		{ GET, "/resources/", h.as_httphandler() },
		{ GET, "/doc/{module}", fth.as_httphandler() }
	)!!;

	server.serve(r.as_httphandler())!;
}