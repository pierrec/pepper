module http::handlers::texttemplate(<Type>);
import std::io;
import template;

// FileTemplateHandler turns a TextTemplate file into an HTTPHandler.
struct FileTemplateHandler
{
	String file_path;
	String start;
	String end;
	bool cached;
	StreamTextTemplate template;
	FormData data;
	Url url;
	HTTPHandler on_error;
}

fn void! FileTemplateHandler.init(&self,
	String file_path,
	String tag_start = template::DEFAULT_START_TAG,
	String tag_end = template::DEFAULT_END_TAG,
	bool cached = true,
	HTTPHandler on_error = handlers::on_error.as_httphandler())
{
	*self = {
		.file_path = file_path,
		.start = tag_start, .end = tag_end,
		.cached = cached,
		.on_error = on_error,
	};
}

fn HTTPHandler FileTemplateHandler.as_httphandler(&self)
{
	return { .fns = &filetemplatehandler_interface, .data = self };
}

HTTPHandlerInterface filetemplatehandler_interface = {
	.handle_fn = fn(h, req, resp) => ((FileTemplateHandler*)h.data).handle(req, resp),
};

fn void FileTemplateHandler.handle(&self, HTTPRequest* req, HTTPResponse* resp)
{
	Allocator* allocator = mem::temp();
	FormData! data = req.parse_form(allocator);
	if (catch err = data)
	{
		io::printfn("%s: %s", self.file_path, err);
		resp.status = 500;
		@ok(self.on_error.handle(req, resp));
		return;
	}
	self.data = data;
	self.url = req.url;

	if (!self.cached || !self.template.is_initialized())
	{
		File! f = file::open(self.file_path, "r");
		if (catch err = f)
		{
			io::printfn("%s: %s", self.file_path, err);
			resp.status = 500;
			@ok(self.on_error.handle(req, resp));
			return;
		}
		defer @ok(f.close());
		if (catch err = self.template.init(f.as_stream(), self.start, self.end, allocator))
		{
			io::printfn("%s: %s", self.file_path, err);
			resp.status = 500;
			@ok(self.on_error.handle(req, resp));
			return;
		}
	}
	resp.status = 200;
	resp.body = self.as_stream();
}

fn Stream FileTemplateHandler.as_stream(&self)
{
	return { .fns = &filestream_interface, .data = self };
}

StreamInterface filestream_interface = {
	.write_stream_fn = fn(s, writer) => ((FileTemplateHandler*)s.data).write_stream(writer),
	.close_fn = fn(s) => ((FileTemplateHandler*)s.data).close(),
};

fn usz! FileTemplateHandler.write_stream(&self, Stream writer)
{
	return self.template.@render(writer; String name, usz n)
	{
		String value = self.data.get(name) ?? self.url.get(name) ?? "";
		n += writer.write(value)!;
	};
}

fn void! FileTemplateHandler.close(&self)
{
	if (!self.cached) self.template.free()!;
}