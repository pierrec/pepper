module http::header_test @test;
import http;
import std::io;
import std::collections::list;

def List = list::List(<String[2]>);

fn void header()
{
    String[2][] tcases = {
        {"Name1", "value1"},
        {"Name2", "value2"},
        {"Name3", "value3"},
        {"Name4", "value4"},
        {"Name5", "value5"},
        {"Name6", "value6"},
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

fn void! header_scan()
{
    ByteReader br;
    br.init("name1:value1\r\nname2:value2\r\n\r\n");
    char[128] buffer;
    Scanner sc;
    sc.init(br.as_stream(), buffer[..]);

    HTTPHeader header;
    header.scan(&sc)!;
    assert(header.get("Name1".tcopy())! == "value1");
    assert(header.get("Name2".tcopy())! == "value2");

    List list;
    header.@each(; String k, String v)
    {
        list.push({k, v});
    };
    assert(equals(list.array_view(), String[2][]{ {"Name1", "value1"}, {"Name2", "value2"} }));
}