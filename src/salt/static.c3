module http::handlers;
import std::io;

def OnError = fn void(anyfault, HTTPRequest* req, HTTPResponse* resp);

$assert File.sizeof == uptr.sizeof;

// StaticHandler turns a filesystem directory into an HTTPHandler,
// serving the files listed in the directory.
struct StaticHandler
{
	Path root;
	String index;
	HTTPHandler on_error;
}

fn void StaticHandler.init(&self,
	String root,
	String index = "index.html",
	HTTPHandler on_error = handlers::on_error.as_httphandler())
{
	*self = {
		.root = { root, path::DEFAULT_PATH_ENV },
		.index = index,
		.on_error = on_error,
	};
}

fn HTTPHandler StaticHandler.as_httphandler(&self)
{
	return { .fns = &fshandler_interface, .data = self };
}

HTTPHandlerInterface fshandler_interface = {
	.handle_fn = fn(h, ctx, req, resp) => ((StaticHandler*)h.data).handle(ctx, req, resp),
};

fn void StaticHandler.handle(&self, void* context, HTTPRequest* req, HTTPResponse* resp)
{
	Path! file_name = self.root.append(req.url.path, mem::temp());
	if (req.url.path.ends_with("/")) file_name = file_name.append(self.index, mem::temp());
	if (catch err = file_name)
	{
		io::printfn("root=%s req.path=%s: %s", self.root.as_str(), req.url.path, err);
		resp.status = 500;
		@ok(self.on_error.handle(req, resp));
		return;
	}
	File! f = file::open(file_name.as_str(), "r");
	if (catch err = f)
	{
		io::printfn("%s: %s", file_name.as_str(), err);
		resp.status = 500;
		@ok(self.on_error.handle(req, resp));
		return;
	}
	resp.status = 200;
	resp.body = ((StaticFile)f).as_stream();
}

def StaticFile = distinct File;

fn Stream StaticFile.as_stream(self)
{
	return { .fns = &staticfile_stream, .data = bitcast(self, void*) };
}

StreamInterface staticfile_stream = {
	.read_fn = fn(s, bytes) => (bitcast(s.data, File)).read(bytes),
	.close_fn = fn(s) => (bitcast(s.data, File)).close(),
};