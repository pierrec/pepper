module http;
import std::collections::enummap;
import std::collections::list;
import std::io;
import std::sort;
import http::handlers;
import http::stringmap;

const HTTP_ROUTER_LOG = true;

const DYN_START_TAG = "{";
const DYN_END_TAG = "}";


fault HTTPRouterError
{
	DUPLICATE_ROUTE,
	INVALID_ROUTE,
	INVALID_DYNAMIC_ROUTE,
}

def HTTPRouteList = List(<HTTPRouteInternal>);
def HTTPRouteMap = EnumMap(<HTTPMethod, HTTPRouteList>);
def StringList = List(<String>);

struct HTTPRouter
{
	Allocator* allocator;
	HTTPRouteMap routes;
	HTTPHandler on_error;
	HTTPContext context;
}

def PathData = Map(<4>);

struct HTTPContext
{
	PathData path_data;
}

struct HTTPRoute
{
	HTTPMethod method;
	String route;
	HTTPHandler handler;
}

struct HTTPRouteInternal @private
{
	String[] sub_routes;
	HTTPHandler handler;
}

/**
 * Routes are processed in the order in which they are supplied, meaning that the
 * first matching one will trigger its handle and stop.
 * @require routes.len > 0
 **/
fn void! HTTPRouter.init(&self,
	HTTPHandler on_error,
	Allocator* allocator,
	HTTPRoute ...routes)
{
	if (!on_error.fns || !on_error.data) on_error = handlers::on_error.as_httphandler();
	*self = { .allocator = allocator, .on_error = on_error };
	foreach (i, r : routes)
	{
		if (r.route == "") return HTTPRouterError.INVALID_ROUTE?;
		if (i > 0)
		{
			HTTPRoute prev = routes[i - 1];
			if (r.method == prev.method && r.route == prev.route) return HTTPRouterError.DUPLICATE_ROUTE?;
		}
		$if HTTP_ROUTER_LOG:
			io::printfn("ROUTER init method=%s route=%s", r.method, r.route);
		$endif
		HTTPRouteList* list = self.routes.get_ref(r.method);
		if (list.len() == 0) list.init(.using = allocator);
		String[] sub_routes = {|
			StringList sub_list;
			sub_list.init(.using = allocator);
			String s = r.route;
			while (true)
			{
				usz! start = s.index_of(DYN_START_TAG);
				if (catch start)
				{
					sub_list.push(s);
					return sub_list.array_view();
				}
				sub_list.push(s[:start]);
				s = s[start + DYN_START_TAG.len..];
				usz! end = s.index_of(DYN_END_TAG);
				if (catch end) return HTTPRouterError.INVALID_DYNAMIC_ROUTE?;
				sub_list.push(s[:end].trim());
				s = s[end + DYN_END_TAG.len..];
			}
		|}!;
		$if HTTP_ROUTER_LOG:
			io::printf("%s: sub path elements:", r.route);
			foreach (s : sub_routes)
			{
				io::printf(" <<%s>>", s);
			}
			io::printfn("");
		$endif
		list.push({ .sub_routes = sub_routes, .handler = r.handler });
	}

	$if HTTP_ROUTER_LOG:
		foreach (m : HTTPMethod.values)
		{
			io::printfn("%s -> %d", m, self.routes[m].len());
		}
	$endif
}

fn void! HTTPRouter.free(&self)
{
	if (self.allocator)
	{
		foreach (r : self.routes.values)
		{
			r.free();
		}
		*self = {};
	}
}

fn HTTPHandler HTTPRouter.as_httphandler(&self)
{
	return { .fns = &httprouter_interface, .data = self, .context = &self.context };
}

HTTPHandlerInterface httprouter_interface = {
	.handle_fn = fn(h, ctx, req, resp) => ((HTTPRouter*)h.data).handle(h.context, req, resp),
};

fn void! HTTPRouter.handle(&self, HTTPContext* ctx, HTTPRequest* req, HTTPResponse* resp)
{
	if (resp.status != 200)
	{
		self.on_error.handle(ctx, req, resp)!;
		return;
	}

	HTTPRouteList routes = self.routes.get(req.method);
	$if HTTP_ROUTER_LOG:
		io::printfn("found %d potential routes for method %s", routes.len(), req.method);
	$endif
	if (routes.len() == 0)
	{
		resp.status = 405;
		resp.header.set("Allow", req.method.nameof)!;
		self.on_error.handle(ctx, req, resp)!;
		return;
	}
	String path = req.url.path;
	$if HTTP_ROUTER_LOG:
		io::printfn("incoming request method=%s route=%s", req.method, path);
	$endif
	foreach ROUTES: (r : routes)
	{
		String p = path;
		String[] sub_routes = r.sub_routes;
		self.context.path_data.clear();
		while (sub_routes.len)
		{
			String sub_path = sub_routes[0];
			if (!p.starts_with(sub_path))
			{
				continue ROUTES;
			}
			sub_routes = sub_routes[1..];
			p = p[sub_path.len..];
			if (sub_routes.len)
			{
				String key = sub_routes[0];
				sub_routes = sub_routes[1..];
				String value = {|
					String next = sub_routes[0];
					if (sub_routes.len == 0 || next.len == 0) return p;
					if (try i = p.index_of(next))
					{
						defer p = p[i..];
						return p[:i];
					}
					return "";
				|};
				self.context.path_data.set(key, value);
			}
		}
		$if HTTP_ROUTER_LOG:
			io::printfn("%s: match found: %s, keys=%d", path, r.sub_routes, self.context.path_data.len);
			self.context.path_data.@each(; String key, String value)
			{
				io::printfn("key=%s value=%s", key, value);
			};
		$endif
		r.handler.handle(ctx, req, resp)!;
		return;
	}
	$if HTTP_ROUTER_LOG:
		io::printfn("%s: no route", path);
	$endif
	resp.status = 404;
	self.on_error.handle(ctx, req, resp)!;
}