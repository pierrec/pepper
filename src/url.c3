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

fn void! Url.init(&self, String data, bool path_only = false)
{
    *self = { .raw = data };
    if (try fragment_index = data.index_of_char('#'))
    {
        self.fragment = data[fragment_index + 1..];
        data = data[:fragment_index];
    }
    if (!path_only)
    {
        if (try scheme_index = data.index_of_char(':'))
        {
            String scheme = data[:scheme_index];
            // Scheme: [a-zA-Z][a-zA-Z0-9+.-]*
            if (scheme.len == 0 || !scheme[0].is_alpha()) return UrlError.INVALID_SCHEME?;
            foreach (c : scheme[1..])
            {
                if (!c.is_alnum() && !string::char_in_set(c, "+.-")) return UrlError.INVALID_SCHEME?;
            }
			scheme.convert_ascii_to_lower();
            self.scheme = scheme;
            data = data[scheme_index + 1..];
        }
    }
    if (try query_index = data.index_of_char('?'))
    {
        self.query = data[query_index..];
        data = data[:query_index];
    }
    if (try path_index = data.index_of_char('/'))
    {
        self.path = data[path_index..];
        data = data[:path_index];
    }
    if (!path_only)
    {
        if (try auth_index = data.index_of_char('@'))
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