module http::header;
import std::ascii;
import std::io;
import scanner;
import stringmap;

const MAX_NAME_LEN = 32;

fault HTTPHeaderError
{
    HEADER_FULL,
    HEADER_NAME_TOO_LONG,
    INVALID_HEADER_NAME,
    INVALID_HEADER,
    TOO_MANY_HEADERS,
}

// https://www.rfc-editor.org/rfc/rfc7230.html#section-2.1
def HTTPHeaderMap = StringMap(<String, 9>);

struct HTTPHeader
{
    HTTPHeaderMap data;
}

fn void HTTPHeader.init(&h)
{
    h.data.init();
}

fn void! HTTPHeader.free(&h, Allocator* using = mem::heap())
{
    h.data.@walk(; String name, String value)
    {
        using.free(value)!;
    };
}

fn String! HTTPHeader.get(&h, String name)
{
    char[MAX_NAME_LEN] buf;
    name = canonicalize(name, buf[..])!;
    return h.data.get(name);
}

fn void! HTTPHeader.set(&h, String name, String value)
{
    if (value.len == 0) return;
    char[MAX_NAME_LEN] buf;
    name = canonicalize(name, buf[..])!;
    if (catch h.data.set(name, value)) return HTTPHeaderError.HEADER_FULL?;
}

fn void! HTTPHeader.del(&h, String name)
{
    char[MAX_NAME_LEN] buf;
    name = canonicalize(name, buf[..])!;
    h.data.del(name);
}

// https://www.rfc-editor.org/rfc/rfc7230.html#section-3.2.4
fn void! HTTPHeader.scan(&h, Scanner *sc, Allocator* using = mem::heap())
{
    while (sc.scan(':')!)
    {
        String bytes = sc.as_str();
        String name = String.tcopy(bytes);
        // Check that the line ends with `\r\n`.
        if (!sc.scan('\n')!) return HTTPHeaderError.INVALID_HEADER?;
        bytes = sc.as_str();
        if (bytes.len < 2 || bytes[^1] != '\r') return HTTPHeaderError.INVALID_HEADER?;
        // Remove optional white space (OWS).
        bytes = bytes.trim();
        String value = String.copy(bytes, using);
        h.set(name, value)!;
    }
}

fn usz! HTTPHeader.write_to(&h, Stream stream)
{
    usz n;
    h.data.@walk(; String name, String value)
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
    if (s.len > canon.len) return HTTPHeaderError.HEADER_NAME_TOO_LONG?;
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
                return HTTPHeaderError.INVALID_HEADER_NAME?;
        }
        canon[i] = c;
    }
    return (String)canon[:s.len];
}