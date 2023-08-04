module http::handlers::texttemplate(<Type>);
import template::text;

def TextTemplate = TextTemplate(<Type>);

// TextTemplateHandler turns a TextTemplate into an HTTPHandler.
struct TextTemplateHandler
{
	TextTemplate template;
}

fn void! TextTemplateHandler.init(&self, String template)
{
	self.template.init(template)!;
}

fn HTTPHandler TextTemplateHandler.as_httphandler(&self)
{
	return { .fns = &texthandler_interface, .data = self };
}

HTTPHandlerInterface texthandler_interface = {
	.handle_fn = fn(h, ctx, req, resp) => ((TextTemplateHandler*)h.data).handle((HTTPContext*)ctx, req, resp),
};

fn void TextTemplateHandler.handle(&self, HTTPContext* ctx, HTTPRequest* req, HTTPResponse* resp)
{
	resp.status = 200;
	resp.body = self.template.as_stream();
}