module http;
import std::ascii;
import std::io;
import stringmap;

const MAX_NAME_LEN = 32;
const MAX_HEADERS = 256;

fault HTTPError
{
    HEADER_FULL,
    HEADER_NAME_TOO_LONG,
    INVALID_HEADER_NAME,
    INVALID_HEADER,
    TOO_MANY_HEADERS,
	INVALID_REQUEST,
}

// https://www.rfc-editor.org/rfc/rfc7230.html#section-2.1
def HTTPHeaderMap = StringMap(<String, 9>);

struct HTTPHeader
{
    HTTPHeaderMap data;
}

fn void HTTPHeader.init(&self)
{
    self.data.init();
}

fn void! HTTPHeader.free(&self, Allocator* using = mem::heap())
{
    self.data.@walk(; String name, String value)
    {
        using.free(value)!;
    };
}

fn String! HTTPHeader.get(&self, String name)
{
    char[MAX_NAME_LEN] buf;
    name = canonicalize(name, buf[..])!;
    return self.data.get(name);
}

fn void! HTTPHeader.set(&self, String name, String value)
{
    if (value.len == 0) return;
    char[MAX_NAME_LEN] buf;
    name = canonicalize(name, buf[..])!;
    if (catch self.data.set(name, value)) return HTTPError.HEADER_FULL?;
}

fn void! HTTPHeader.del(&self, String name)
{
    char[MAX_NAME_LEN] buf;
    name = canonicalize(name, buf[..])!;
    self.data.del(name);
}

// https://www.rfc-editor.org/rfc/rfc7230.html#section-3.2.4
fn void! HTTPHeader.scan(&self, Scanner *sc, Allocator* using = mem::heap())
{
    for (usz h = 0; h < MAX_HEADERS; h++)
    {
		char[] bytes = scan(sc, "\r\n", HTTPError.INVALID_HEADER)!;
		if (bytes.len == 0) return;
		usz i = index_of(bytes, ':', HTTPError.INVALID_HEADER)!;
		String name = String.tcopy((String)bytes[:i]);
		String value = String.copy((String)bytes[i + 1..], using);
		self.set(name, value)!;
		io::printfn("HEADER %s=%s", name, value);
    }
    return HTTPError.TOO_MANY_HEADERS?;
}

fn usz! HTTPHeader.write_to(&self, Stream stream)
{
    usz n;
    self.data.@walk(; String name, String value)
    {
        n += stream.write(name)!;
        n += stream.write(":")!;
        n += stream.write(value)!;
        n += stream.write("\r\n")!;
    };
    n += stream.write("\r\n")!;
    return n;
}

macro HTTPHeader.@walk(list; @body(name, value))
{
    list.data.@walk(; String name, String value)
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
fn String! canonicalize(String s, char[] canon)
{
    if (s.len > canon.len) return HTTPError.HEADER_NAME_TOO_LONG?;
    bool with_hyphen = true;
    foreach (i, c : s)
    {
        switch
        {
            case ascii::is_alnum(c):
                c = with_hyphen ? ascii::to_upper(c) : ascii::to_lower(c);
                with_hyphen = false;
            case c == '-':
                with_hyphen = true;
            case string::char_in_set(c, "!#$%&'*+.^_`|~"):
                break;
            default:
                return HTTPError.INVALID_HEADER_NAME?;
        }
        canon[i] = c;
    }
    return (String)canon[:s.len];
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