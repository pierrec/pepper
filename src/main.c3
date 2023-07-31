module http;
import std::io;
import template::text;

def TextTemplate = TextTemplate(<Data>);

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
    TextHandler h;
    h.init("hello {{user}}!")!!;
    server.serve(h.as_httphandler())!!;
}

struct Handler
{
    ByteReader buf;
}

fn HTTPHandler Handler.as_httphandler(&self)
{
    return { .fns = &httphandler_interface, .data = self };
}

HTTPHandlerInterface httphandler_interface = {
    .handler_fn = fn(h, req, resp) => ((Handler*)h.data).handle(req, resp),
};

fn void Handler.handle(&self, HTTPRequest* req, HTTPResponse* resp)
{
    self.buf.index = 0;
    self.buf.bytes = "Hello world";
    resp.status = 200;
    resp.body = self.buf.as_stream();
}

struct TextHandler
{
	TextTemplate template;
}

fn void! TextHandler.init(&self, String template)
{
	self.template.init(template, { "Joe" })!;
}

fn HTTPHandler TextHandler.as_httphandler(&self)
{
    return { .fns = &texthandler_interface, .data = self };
}

HTTPHandlerInterface texthandler_interface = {
    .handler_fn = fn(h, req, resp) => ((TextHandler*)h.data).handle(req, resp),
};

fn void TextHandler.handle(&self, HTTPRequest* req, HTTPResponse* resp)
{
    resp.status = 200;
	resp.body = self.template.as_stream();
}