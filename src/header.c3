module http;
import http::stringmap;
import std::io;

// https://www.rfc-editor.org/rfc/rfc7230.html#section-2.1

def HTTPHeaderMap = Map(<8>);

struct HTTPHeader
{
	HTTPHeaderMap data;
	CookieJar cookies;
}

// https://httpwg.org/specs/rfc6265.html#cookie

def CookieJar = Map(<6>);

fn String! HTTPHeader.get(&self, String name)
{
	assert(is_canonical(name), "%s", name);
	return self.data.get(name);
}

fn void! HTTPHeader.set(&self, String name, String value)
{
	assert(is_canonical(name), "%s", name);
	if (value.len == 0) return;
	self.data.set(name, value);
}

fn void! HTTPHeader.del(&self, String name)
{
	assert(is_canonical(name), "%s", name);
	self.data.del(name);
}

// https://www.rfc-editor.org/rfc/rfc7230.html#section-3.2.4
fn void! HTTPHeader.scan(&self, Scanner *sc)
{
	while (true)
	{
		char[] bytes = scan(sc, "\r\n", HTTPError.INVALID_REQUEST)!;
		if (bytes.len == 0) return;
		usz i = index_of(bytes, ':', HTTPError.INVALID_REQUEST)!;
		String name = (String)bytes[:i];
		canonicalize(name)!;
		String value = (String)bytes[i + 1..];
		self.set(name, value)!;
		log(DEBUG, io::stderr().as_stream(),
			"HEADER %s=%s", name, value);
		if (name == "Cookie")
		{
			self.cookies.clear();
			while (value.len > 0)
			{
				String cookie;
				if (try pair = value.index_of("; "))
				{
					cookie = value[:pair];
					value = value[pair + 2..];
				}
				else
				{
					cookie = value;
					value = "";
				}
				usz! cookie_idx = cookie.index_of_char('=');
				if (catch cookie_idx)
				{
					// Abort the parsing without error.
					break;
				}
				String cookie_name = cookie[:cookie_idx].trim();
				String cookie_value = cookie[cookie_idx + 1..];
				self.cookies.set(cookie_name, cookie_value);
			}
		}
	}
}

fn usz! HTTPHeader.write_stream(&self, Stream stream)
{
	usz n;
	self.data.@each(; String name, String value)
	{
		n += stream.write(name)!;
		n += stream.write(":")!;
		n += stream.write(value)!;
		n += stream.write("\r\n")!;
	};
	n += stream.write("\r\n")!;
	return n;
}

macro HTTPHeader.@each(list; @body(name, value))
{
	list.data.@each(; String name, String value)
	{
		@body(name, value);
	};
}

/*
 * Canonicalize the input _in place_ and return whether it was successful.
 * It fails if s contains any invalid character.
 * See https://www.rfc-editor.org/rfc/rfc7230.html#appendix-B
 * tchar = "!" / "#" / "$" / "%" / "&" / "'" / "*" / "+" / "-" / "." /
       "^" / "_" / "`" / "|" / "~" / DIGIT / ALPHA
 * Canonicalization converts the input as follow:
 * accept-encodING => Accept-Encoding
 */
fn void! canonicalize(String s)
{
	bool with_hyphen = true;
	foreach (&c : s)
	{
		switch
		{
			case c.is_alnum():
				if (with_hyphen && c.is_lower())
				{
					*c = c.to_upper();
				}
				else if (!with_hyphen && c.is_upper())
				{
					*c = c.to_lower();
				}
				with_hyphen = false;
			case *c == '-':
				with_hyphen = true;
			case string::char_in_set(*c, "!#$%&'*+.^_`|~"):
				break;
			default:
				return HTTPError.INVALID_REQUEST?;
		}
	}
}

fn bool is_canonical(String s)
{
	bool with_hyphen = true;
	foreach (c : s)
	{
		switch
		{
			case c.is_alnum():
				if (with_hyphen && c.is_lower())
				{
					return false;
				}
				else if (!with_hyphen && c.is_upper())
				{
					return false;
				}
				with_hyphen = false;
			case c == '-':
				with_hyphen = true;
			case string::char_in_set(c, "!#$%&'*+.^_`|~"):
				break;
			default:
				return false;
		}
	}
	return true;
}

macro char[]! scan(sc, pattern, e)
{
	char[]! bytes = sc.scan(pattern);
	if (catch err = bytes)
	{
		case SearchResult.MISSING:
			return e?;
		default:
			return err?;
	}
	return bytes;
}

macro usz! index_of(bytes, c, e)
{
	usz! i = array::index_of(bytes, c);
	if (catch err = i)
	{
		case SearchResult.MISSING:
			return e?;
		default:
			return err?;
	}
	return i;
}