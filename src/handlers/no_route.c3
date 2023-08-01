module http::handlers;
import std::io;
import template::text;

struct NoRoute
{
	String status;
	String status_message;
}

def HTTPHandlerNoRouteTextTemplate = TextTemplate(<NoRoute>);

// no_route is the basic default no route HTTPHandler.
HTTPHandlerNoRoute no_route;

static initialize
{
	no_route.init();
}

struct HTTPHandlerNoRoute
{
	HTTPHandlerNoRouteTextTemplate template;
}

fn void HTTPHandlerNoRoute.init(&self, String template = "<h1>{{status}}</h1><h2>{{status_message}}</h2>")
{
	self.template.init(template, {})!!;
}

fn HTTPHandler HTTPHandlerNoRoute.as_httphandler(&self)
{
	return { .fns = &httpnoroute_interface, .data = self };
}

HTTPHandlerInterface httpnoroute_interface = {
	.handle_fn = fn(h, req, resp) => ((HTTPHandlerNoRoute*)h.data).handle(req, resp),
};

fn void! HTTPHandlerNoRoute.handle(&self, HTTPRequest* req, HTTPResponse* resp)
{

	self.template.data = { resp.status.as_str(), resp.status.as_message() };
	resp.body = self.template.as_stream();
}