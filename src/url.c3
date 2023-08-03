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
        if (try scheme_index = data.index_of("://"))
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
            data = data[scheme_index + 3..];
        }
    }
    if (try query_index = data.index_of_char('?'))
    {
        self.query = url_decode(data[query_index..]);
        data = data[:query_index];
    }
    if (try path_index = data.index_of_char('/'))
    {
        self.path = url_decode(data[path_index..]);
        data = data[:path_index];
    }
    if (self.path == "") self.path = "/";
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

fn String! Url.get(&self, String name)
{
	if (self.query.len == 0) return SearchResult.MISSING?;
	FormData fd;
	fd.data = self.query[1..];
	return fd.get(name);
}

macro bool Url.equals(&self, Url other)
{
	$foreach ($m : Url.membersof)
		if (self.$eval($m.nameof) != other.$eval($m.nameof)) return false;
	$endforeach
	return true;
}

/**
 * Decode the content of `s` in-place.
 **/
fn String url_decode(String s)
{
	if (s.len < 3) return s;
	for (usz i = 0; i < s.len - 2; i++)
	{
		if (try i = s.index_of_char('%'))
		{
			if (i == s.len - 2) break;
			char c1 = s[i + 1];
			char c2 = s[i + 2];
			switch
			{
				case c1 == '2' && (c2.is_digit() || string::char_in_set(c2, "ABCF")):
				case c1 == '3' && string::char_in_set(c2, "ABDF"):
				case c1 == '4' && c2 == '0':
				case c1 == '5' && (c2 == 'B' || c2 == 'D'):
					break;
				default:
					continue;
			}
			char c = (c1 - '0') << 4;
			switch
			{
				case c2.is_digit():
					c |= c2 - '0';
				case c2.is_alpha():
					c |= c2 - 'A';
				default:
					continue;
			}
			s[i] = c;
			usz n = s.len - 2;
			s[i + 1:n] = s[i + 3:n];
			s = s[:n];
		}
	}
	return s;
}