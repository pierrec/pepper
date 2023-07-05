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
def HTTPHeaderMap = distinct StringMap<String, 9>;
struct HTTPHeader
{
    HTTPHeaderMap data;
}

fn void HTTPHeader.init(&h)
{
    h.data.init();
}

fn void HTTPHeader.free(&h)
{
    h.data.@walk(; String name, String value)
    {
        mem::free(value);
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
fn void! HTTPHeader.scan(&h, Scanner *sc)
{
    while (sc.scan(':')!)
    {
        char[] bytes = sc.bytes();
        String name = String.tcopy((String)bytes);
        if (!sc.scan('\n')!) return HTTPHeaderError.INVALID_HEADER?;
        bytes = sc.bytes();
        if (bytes.len < 2 || bytes[^1] != '\r') return HTTPHeaderError.INVALID_HEADER?;
        String value = String.copy((String)bytes[:^1]);
        h.set(name, value)!;
    }
}

fn usz! HTTPHeader.write(&h, Stream stream)
{
    usz n;
    h.data.@walk(; String name, String value)
    {
        stream.write(name)!;
        stream.write(":")!;
        stream.write(value)!;
        stream.write("\r\n")!;
    };
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