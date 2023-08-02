module http::handlers;
import std::io;

def OnError = fn void(anyfault, HTTPRequest* req, HTTPResponse* resp);

// StaticHandler turns a filesystem directory into an HTTPHandler,
// serving the files listed in the directory.
struct StaticHandler
{
	Path root;
	HTTPHandler on_error;
}

fn void StaticHandler.init(&self)
{
	// TODO set on_error if null
}

fn HTTPHandler StaticHandler.as_httphandler(&self)
{
	return { .fns = &fshandler_interface, .data = self };
}

HTTPHandlerInterface fshandler_interface = {
	.handle_fn = fn(h, req, resp) => ((StaticHandler*)h.data).handle(req, resp),
};

fn void StaticHandler.handle(&self, HTTPRequest* req, HTTPResponse* resp)
{
	Path! file_name = self.root.append(req.url.path, mem::temp());
	if (catch err = file_name)
	{
		self.on_error.handle(req, resp) ?? (void){};
		return;
	}
	File! f = file::open(file_name.as_str(), "r");
	if (catch err = f)
	{
		self.on_error.handle(req, resp);
		return;
	}
	resp.status = 200;
	resp.body = f.as_stream();
}