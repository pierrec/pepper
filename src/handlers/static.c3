module http::handlers;
import std::io;

def OnError = fn void(anyfault, HTTPRequest* req, HTTPResponse* resp);

// StaticHandler turns a filesystem directory into an HTTPHandler,
// serving the files listed in the directory.
struct StaticHandler
{
	Allocator* allocator;
	Path root;
	String index;
	HTTPHandler on_error;
}

fn void StaticHandler.init(&self,
	String root,
	String index = "index.html",
	Allocator* allocator = mem::heap(),
	HTTPHandler on_error = handlers::on_error.as_httphandler())
{
	*self = {
		.allocator = allocator,
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
	.handle_fn = fn(h, req, resp) => ((StaticHandler*)h.data).handle(req, resp),
};

fn void StaticHandler.handle(&self, HTTPRequest* req, HTTPResponse* resp)
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
	StaticFile*! fptr = self.allocator.alloc(StaticFile.sizeof);
	if (catch err = fptr)
	{
		resp.status = 500;
		@ok(self.on_error.handle(req, resp));
		return;
	}
	*fptr = { f, self.allocator };
	resp.status = 200;
	resp.body = fptr.as_stream();
}

struct StaticFile
{
	inline File file;
	Allocator* allocator;
}

fn void! StaticFile.close(&self)
{
	@ok(self.file.close());
	self.allocator.free(self);
}