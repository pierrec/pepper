module http::handlers;
import std::io;
import http::handlers::texttemplate;

def Handler = TextTemplateHandler(<Data>);

struct Data
{
	String user;
}

fn int main(String[] args)
{
	//do_client();
	do_server();
return 0;
}

//fn void do_client()
//{
//    HTTPClient client;
//    HTTPRequest req = {
//        .method = GET,
//        .url = { .host = "www.example.com:80", .path = "/" },
//        .proto = HTTP1_0,
//    };
//    HTTPResponse resp;
//    resp.init();
//    client.do_request(&req, &resp)!!;
//    //io::printn(resp.status);
//    io::printn(resp.body);
//}

fn void do_server()
{
	HTTPServer server;
	server.init("localhost:8081", 1000)!!;
	//Handler h;
	//h.init("hello {{user}}", { "Joe" })!!;
	StaticHandler h;
	h.init("/Users/pierre/sandbox/src/git.sr.ht/pierrec/c3/pepper");
	FileTemplateHandler fth;
	defer @ok(fth.free());
	fth.init("/Users/pierre/sandbox/src/git.sr.ht/pierrec/c3/pepper/resources/module.html")!!;

	HTTPRouter r;
	r.init({}, mem::temp(),
		{ POST, "/", fth.as_httphandler() },
		{ GET, "/", fth.as_httphandler() },
		{ GET, "/resources", h.as_httphandler() },
		//{ GET, "/doc/{module}", fth.as_httphandler() },
		{ GET, "/doc/{module}/{id}/type", fth.as_httphandler() })!!;

	server.serve(r.as_httphandler())!!;
}