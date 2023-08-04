module http::handlers;
import std::io;
import template::text;

struct HTTPError
{
	String status;
	String status_message;
}

def HTTPHandlerHTTPErrorTextTemplate = TextTemplate(<HTTPError>);

// no_route is the basic default no route HTTPHandler.
HTTPHandlerHTTPError on_error;

static initialize
{
	on_error.init();
}

struct HTTPHandlerHTTPError
{
	HTTPHandlerHTTPErrorTextTemplate template;
}

fn void HTTPHandlerHTTPError.init(&self, String template = "<h1>{{status}}</h1><h2>{{status_message}}</h2>")
{
	self.template.init(template)!!;
}

fn HTTPHandler HTTPHandlerHTTPError.as_httphandler(&self)
{
	return { .fns = &httperror_interface, .data = self };
}

HTTPHandlerInterface httperror_interface = {
	.handle_fn = fn(h, ctx, req, resp) => ((HTTPHandlerHTTPError*)h.data).handle(ctx, req, resp),
};

fn void! HTTPHandlerHTTPError.handle(&self, void* context, HTTPRequest* req, HTTPResponse* resp)
{
	self.template.data = { resp.status.as_str(), resp.status.as_message() };
	resp.body = self.template.as_stream();
}