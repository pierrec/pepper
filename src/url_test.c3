module http::url_test @test;
import http::url;
import std::io;

struct UrlTest
{
    String in;
    Url out;
}

fn void url_init()
{
    UrlTest[] tcases = {
    };
    foreach (tc : tcases)
    {
        Url url;
        url.init(tc.in)!!;
        io::printfn("%s", $defined($typeof(url).equals));
        //assert(equals(tc.out, url), "got '%s'; want '%s'", url, tc.out);
    }
}