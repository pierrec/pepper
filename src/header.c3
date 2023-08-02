module http;
import http::stringmap;
import std::io;

// MAX_HEADERS is the maximum number of headers that can be parsed in a request.
// This is an arbitrary value only there to prevent DOS attacks.
const MAX_HEADERS = 16;
$assert MAX_HEADERS * 2 <= ushort.max;

// https://www.rfc-editor.org/rfc/rfc7230.html#section-2.1

def HTTPHeaderMap = Map(<8>);

struct HTTPHeader
{
	Allocator* allocator;
	HTTPHeaderMap data;
}

fn void HTTPHeader.init(&self, Allocator* allocator)
{
	*self = { .allocator = allocator };
	self.data.init();
}

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
	for (usz h = 0; h < MAX_HEADERS; h++)
	{
		char[] bytes = scan(sc, "\r\n", HTTPError.INVALID_REQUEST)!;
		if (bytes.len == 0) return;
		usz i = index_of(bytes, ':', HTTPError.INVALID_REQUEST)!;
		String name = ((String)bytes[:i]).copy(self.allocator);
		canonicalize(name)!;
		String value = ((String)bytes[i + 1..]).copy(self.allocator);
		self.set(name, value)!;
		$if HTTP_SERVER_LOG:
			io::printfn("HEADER %s=%s", name, value);
		$endif
	}
	return HTTPError.TOO_MANY_HEADERS?;
}

fn usz! HTTPHeader.write_to(&self, Stream stream)
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