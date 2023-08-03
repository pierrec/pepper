module http;
import std::io;
import std::sort;
import std::collections::enummap;
import std::collections::list;
import http::handlers;

const HTTP_ROUTER_LOG = true;

def HTTPRouteList = List(<HTTPRouteInternal>);
def HTTPRouteMap = EnumMap(<HTTPMethod, HTTPRouteList>);

struct HTTPRouter
{
	Allocator* allocator;
	HTTPRouteMap routes;
	HTTPHandler on_error;
}

struct HTTPRoute
{
	HTTPMethod method;
	String route;
	HTTPHandler handler;
}

struct HTTPRouteInternal @private
{
	String route;
	HTTPHandler handler;
}

fn bool HTTPRoute.less(r1, HTTPRoute r2)
{
	// NB. routes need to be sorted in descending order to match longest ones first.
	return r1.method > r2.method || (r1.method == r2.method && string_compare_to(r1.route, r2.route) > 0);
}

/**
 * @require routes.len > 0
 **/
fn void! HTTPRouter.init(&self,
	HTTPHandler on_error = handlers::on_error.as_httphandler(),
	Allocator* allocator,
	HTTPRoute ...routes)
{
	quicksort(routes);
	*self = { .allocator = allocator, .on_error = on_error };
	foreach (i, r : routes)
	{
		if (r.route == "") return HTTPError.INVALID_ROUTE?;
		if (i > 0)
		{
			HTTPRoute prev = routes[i - 1];
			if (r.method == prev.method && r.route == prev.route) return HTTPError.DUPLICATE_ROUTE?;
		}
		$if HTTP_ROUTER_LOG:
			io::printfn("ROUTER init method=%s route=%s", r.method, r.route);
		$endif
		HTTPRouteList* list = self.routes.get_ref(r.method);
		if (list.len() == 0) list.init(.using = allocator);
		list.push({ .route = r.route, .handler = r.handler });
	}
}

fn void! HTTPRouter.free(&self)
{
	foreach (r : self.routes.values)
	{
		r.free();
	}
}

fn HTTPHandler HTTPRouter.as_httphandler(&self)
{
	return { .fns = &httprouter_interface, .data = self };
}

HTTPHandlerInterface httprouter_interface = {
	.handle_fn = fn(h, req, resp) => ((HTTPRouter*)h.data).handle(req, resp),
};

fn void! HTTPRouter.handle(&self, HTTPRequest* req, HTTPResponse* resp)
{
	if (resp.status != 200)
	{
		self.on_error.handle(req, resp)!;
		return;
	}
	$if HTTP_ROUTER_LOG:
		io::printfn("total num of routes=%d", self.routes.len());
		for (usz i = 0; i < self.routes.len(); i++)
		{
			HTTPMethod m = (HTTPMethod)i;
			io::printfn("%s -> %d", m, self.routes[m].len());
		}
	$endif

	HTTPRouteList routes = self.routes.get(req.method);
	$if HTTP_ROUTER_LOG:
		io::printfn("found %d potential routes for method %s", routes.len(), req.method);
	$endif
	if (routes.len() == 0)
	{
		resp.status = 405;
		resp.header.set("Allow", req.method.nameof)!;
	}
	else
	{
		String path = req.url.path;
		$if HTTP_ROUTER_LOG:
			io::printfn("incoming request method=%s route=%s", req.method, path);
		$endif
		foreach (r : routes)
		{
			String route = r.route;
			if (path.starts_with(route))
			{
				r.handler.handle(req, resp)!;
				return;
			}
		}
		$if HTTP_ROUTER_LOG:
			io::printfn("%s: no route", path);
		$endif
		resp.status = 404;
	}
	self.on_error.handle(req, resp)!;
}

fn int string_compare_to(String s1, String s2)
{
	if (s1.len != s2.len) return (int)(s1.len - s2.len);
	foreach (i, c1 : s1)
	{
		char c2 = s2[i];
		if (c1 == c2) continue;
		return (int)(c1 - c2);
	}
	return 0;
}