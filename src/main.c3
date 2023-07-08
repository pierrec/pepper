module http;
import std::io;

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
    Handler h;
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
    ByteWriter dst;
    dst.tinit();
    req.write_to(dst.as_stream())!!;
    io::printfn(">>%s<<", dst.as_str());

    self.buf.index = 0;
    self.buf.bytes = "Hello world";
    resp.status = 200;
    resp.body = self.buf.as_stream();
}