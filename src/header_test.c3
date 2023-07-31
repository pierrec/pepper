module http::header_test @test;
import http;
import std::io;
import std::collections::list;

def List = list::List(<String[2]>);

fn void header()
{
    String[2][] tcases = {
        {"name1", "value1"},
        {"name2", "value2"},
        {"name3", "value3"},
        {"name4", "value4"},
        {"name5", "value5"},
        {"name6", "value6"},
    };
    HTTPHeader header;
    foreach (tc : tcases)
    {
        String name = tc[0];
        String value = tc[1];
        if (try v = header.get(name)) assert(false, "header %s should not exist", name);
        header.set(name, value)!!;
        String v = header.get(name)!!;
        assert(v == value, "got '%s'; want '%s'", v, value);
    }
}

fn void header_scan()
{
    ByteReader br;
    br.init("name1:value1\r\nname2:value2\r\n\r\n");
    char[128] buffer;
    Scanner sc;
    sc.init(br.as_stream(), buffer[..]);

    HTTPHeader header;
    header.init(mem::temp());
    header.scan(&sc)!!;
    assert(header.get("name1")! == "value1");
    assert(header.get("name2")! == "value2");

    List list;
    header.@walk(; String k, String v)
    {
        list.push({k, v});
    };
    assert(equals(list.array_view(), String[2][]{ {"Name1", "value1"}, {"Name2", "value2"} }));
}