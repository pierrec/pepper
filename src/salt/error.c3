module http::handlers;
import std::io;
import template::text;

struct HTTPError
{
	String status;
	String status_message;
	String path;
}

def HTTPHandlerHTTPErrorTextTemplate = TextTemplate(<HTTPError>);

/**
 * on_error is the default handler for HTTP errors.
 **/
HTTPHandlerHTTPError on_error;

static initialize
{
	on_error.init();
}

const DEFAULT_ERROR_TEMPLATE = `<html>
	<head>
		<title>{{path}}</title>
	</head>
	<body>
		<h1>{{status}} {{status_message}}</h1>
	</body>
</html>`;

struct HTTPHandlerHTTPError
{
	HTTPHandlerHTTPErrorTextTemplate template;
}

fn void HTTPHandlerHTTPError.init(&self, String template = DEFAULT_ERROR_TEMPLATE)
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

fn void HTTPHandlerHTTPError.handle(&self, HTTPContext* ctx, HTTPRequest* req, HTTPResponse* resp)
{
	self.template.data = {
		.status = resp.status.as_str(),
		.status_message = resp.status.as_message(),
		.path = req.url.path,
	};
	resp.body = self.template.as_stream();
}