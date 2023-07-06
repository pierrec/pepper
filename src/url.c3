module http::url;
import std::ascii;

struct Url
{
    String raw;
    String scheme;
    String host; // host or host:port
    String user;
    String password;
    String path;
    String query; // includes the ? prefix
    String fragment;
}

fault UrlError
{
    INVALID_SCHEME,
}

fn void! Url.free(&self, Allocator* using = mem::heap())
{
    using.free(self.raw)!;
}

fn void! Url.init(&self, String data, bool path_only = false)
{
    *self = { .raw = data };
    if (try fragment_index = data.index_of("#"))
    {
        self.fragment = data[fragment_index + 1..];
        data = data[:fragment_index];
    }
    if (!path_only)
    {
        if (try scheme_index = data.index_of(":"))
        {
            String scheme = data[:scheme_index];
            // Scheme: [a-zA-Z][a-zA-Z0-9+.-]*
            if (scheme.len == 0 || !ascii::is_alpha(scheme[0])) return UrlError.INVALID_SCHEME?;
            foreach (c : scheme[1..])
            {
                if (!ascii::is_alnum(c)) return UrlError.INVALID_SCHEME?;
                if (!string::char_in_set(c, "+.-")) return UrlError.INVALID_SCHEME?;
            }
            scheme.convert_ascii_to_lower();
            self.scheme = scheme;
            data = data[scheme_index + 1..];
        }
    }
    if (try query_index = data.index_of("?"))
    {
        self.query = data[query_index..];
        data = data[:query_index];
    }
    if (try path_index = data.index_of("/"))
    {
        self.path = data[path_index..];
        data = data[:path_index];
    }
    if (!path_only)
    {
        if (try auth_index = data.index_of("@"))
        {
            String credentials = data[:auth_index];
            if (try pass_index = credentials.index_of(":"))
            {
                self.password = credentials[pass_index + 1..];
                credentials = credentials[:pass_index];
            }
            self.user = credentials;
            self.host = data[auth_index + 1..];
        }
        else
        {
            self.host = data;
        }
    }
}