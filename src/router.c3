module http;
import std::io;
import std::sort;
import std::collections::enummap;
import std::collections::list;
import http::handlers;
import http::stringmap;

const HTTP_ROUTER_LOG = false;

def HTTPRouteList = List(<HTTPRouteInternal>);
def HTTPRouteMap = EnumMap(<HTTPMethod, HTTPRouteList>);
def HTTPRouteStringMap = Map(<4>);

struct HTTPRouter
{
	HTTPRouteMap routes;
	HTTPHandler no_route;
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
	HTTPRouteStringMap values;
}

fn bool HTTPRoute.less(r1, HTTPRoute r2)
{
	// NB. routes need to be sorted in descending order to match longest ones first.
	return !(r1.method < r2.method || (r1.method == r2.method && builtin::cmp(r1.route, r2.route) < 0));
}

/**
 * @require routes.len > 0
 **/
fn void! HTTPRouter.init(&self, HTTPHandler no_route, HTTPRoute ...routes)
{
	quicksort(routes);
	HTTPRouteMap map;
	map.init({});
	foreach (i, r : routes)
	{
		if (r.route == "") return HTTPError.INVALID_ROUTE?;
		if (i > 0 && r.route == routes[i - 1].route) return HTTPError.DUPLICATE_ROUTE?;
		$if HTTP_ROUTER_LOG:
			io::printfn("ROUTER init method=%s route=%s", r.method, r.route);
		$endif
		HTTPRouteList* list = map.get_ref(r.method);
		list.push({ .route = r.route, .handler = r.handler });
	}
	if (!no_route.data)
	{
		no_route = handlers::no_route.as_httphandler();
	}
	*self = { .routes = map, .no_route = no_route };
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
	String path = req.url.path;
	$if HTTP_ROUTER_LOG:
		io::printfn("incoming request method=%s route=%s", req.method, path);
	$endif
	HTTPRouteList routes = self.routes.get(req.method);
	$if HTTP_ROUTER_LOG:
		io::printfn("found %d potential routes for method %s", routes.len(), req.method);
	$endif
	if (routes.len() == 0)
	{
		resp.status = 405;
		self.no_route.handle(req, resp)!;
		return;
	}
	// TODO speed up the lookup
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
	self.no_route.handle(req, resp)!;
}