module http::url_test @test;
import http::url;
import std::io;
import testing;

struct UrlTest
{
    String in;
    Url out;
}

fn void! url_init()
{
    UrlTest[] tcases = {
    	{"/", { .raw = "/", .path = "/" }},
    	{"http://www.example.com", {
    		.raw = "http://www.example.com",
    		.scheme = "http", .host = "www.example.com", .path = "/"
    	}},
    	{"http://www.example.com/foo", {
			.raw = "http://www.example.com/foo",
			.scheme = "http", .host = "www.example.com", .path = "/foo",
		}},
		{"http://www.example.com/foo?bar=abc", {
			.raw = "http://www.example.com/foo?bar=abc",
			.scheme = "http", .host = "www.example.com", .path = "/foo", .query = "?bar=abc",
		}},
		{"http://www.example.com/foo#baz", {
			.raw = "http://www.example.com/foo#baz",
			.scheme = "http", .host = "www.example.com", .path = "/foo", .fragment = "baz",
		}},
		{"http://www.example.com/foo?bar=abc#baz", {
			.raw = "http://www.example.com/foo?bar=abc#baz",
			.scheme = "http", .host = "www.example.com", .path = "/foo", .query = "?bar=abc", .fragment = "baz",
		}},
		{"http://root@www.example.com", {
			.raw = "http://root@www.example.com",
			.scheme = "http", .host = "www.example.com", .user = "root", .path = "/"
		}},
		{"http://root:@www.example.com", {
			.raw = "http://root:@www.example.com",
			.scheme = "http", .host = "www.example.com", .user = "root", .path = "/"
		}},
		{"http://root:pass123@www.example.com", {
			.raw = "http://root:pass123@www.example.com",
			.scheme = "http", .host = "www.example.com", .user = "root", .password = "pass123", .path = "/"
		}},
    };
    foreach (tc : tcases)
    {
        Url url;
        url.init(tc.in)!;
        testing::assert_equal(url, tc.out);
    }
}

struct DecodeTest
{
    String in;
    String out;
}

fn void url_decode()
{
	DecodeTest[] tcases = {
		{"/foo/bar", "/foo/bar"},
		{"/foo%20bar%26baz", "/foo bar&baz"},
	};
    foreach (tc : tcases)
	{
		String s = tc.in.tcopy();
		String decoded = url::url_decode(s);
		testing::assert_equal(decoded, tc.out);
	}
}

struct QueryTest
{
    String query;
    String key;
    String value;
}

fn void! url_query()
{
	QueryTest[] tcases = {
		{"?foo=bar", "foo", "bar"},
		{"?foo=bar&foob=baz", "foo", "bar"},
		{"?foo=bar&foob=baz", "foob", "baz"},
	};
	foreach (tc : tcases)
	{
		Url u = { .query = tc.query };
		String value = u.get(tc.key)!;
		testing::assert_equal(value, tc.value, tc.query);
	}
}