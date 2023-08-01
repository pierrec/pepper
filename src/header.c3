module http;
import std::hash::fnv64a;
import std::io;

// MAX_HEADERS is the maximum number of headers that can be parsed in a request.
// This is an arbitrary value only there to prevent DOS attacks.
const MAX_HEADERS = 256;

fault HTTPError
{
	INVALID_HEADER_NAME,
	INVALID_HEADER,
	TOO_MANY_HEADERS,
	INVALID_REQUEST,
}

// https://www.rfc-editor.org/rfc/rfc7230.html#section-2.1

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
	canonicalize(name)!;
	return self.data.get(name);
}

fn void! HTTPHeader.set(&self, String name, String value)
{
	if (value.len == 0) return;
	canonicalize(name)!;
	self.data.set(name, value);
}

fn void! HTTPHeader.del(&self, String name)
{
	canonicalize(name)!;
	self.data.del(name);
}

// https://www.rfc-editor.org/rfc/rfc7230.html#section-3.2.4
fn void! HTTPHeader.scan(&self, Scanner *sc)
{
	for (usz h = 0; h < MAX_HEADERS; h++)
	{
		char[] bytes = scan(sc, "\r\n", HTTPError.INVALID_HEADER)!;
		if (bytes.len == 0) return;
		usz i = index_of(bytes, ':', HTTPError.INVALID_HEADER)!;
		String name = ((String)bytes[:i]).copy(self.allocator);
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
	foreach (i, &c : s)
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
				return HTTPError.INVALID_HEADER_NAME?;
		}
	}
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

// Hash map definition.

const N = 9; // 256 * 2
const MASK = (1 << N) - 1;

$assert MAX_HEADERS * 2 <= ushort.max;

struct HTTPHeaderMap
{
    Entry[MAX_HEADERS * 2] data;
    ushort[MAX_HEADERS] keys;
    ushort len;
}

struct Entry
{
    String key;
    String value;
}

fn void HTTPHeaderMap.init(&self)
{
    *self = {};
}

fn bool HTTPHeaderMap.has(&self, String key)
{
    self.@walk(key; Entry e, ushort i)
    {
        if (e.key == key) return true;
        if (e.key == "") return false;
    };
}

fn String! HTTPHeaderMap.get(&self, String key)
{
    self.@walk(key; Entry e, ushort i)
    {
        if (e.key == key) return e.value;
        if (e.key == "") return SearchResult.MISSING?;
    };
}

fn bool HTTPHeaderMap.set(&self, String key, String value)
{
    self.@walk(key; Entry e, ushort i)
    {
        if (e.key == "")
        {
            self.data[i] = { .key = key, .value = value };
            self.keys[self.len] = i;
            self.len++;
            return true;
        }
        if (e.key == key)
        {
            self.data[i].value = value;
            return false;
        }
    };
}

fn void HTTPHeaderMap.del(&self, String key)
{
    self.@walk(key; Entry e, ushort i)
    {
        if (e.key == key)
        {
            self.data[i] = {};
            foreach (j, k : self.keys[:self.len])
            {
            	if (k == i)
            	{
            		self.keys[j] = self.keys[self.len - 1];
            		break;
            	}
            }
            self.len--;
            return;
        }
        if (e.key == "") return;
    };
}

macro HTTPHeaderMap.@walk(self, str; @body(entry, i)) @private
{
    ulong h = fnv64a::encode(str);
    ushort step = (ushort)(h >> (64 - N)) | 1;
    ushort i = (ushort)h & MASK;
    while (true)
    {
        Entry entry = self.data[i];
        @body(entry, i);
        i = (i + step) & MASK;
    }
}

macro HTTPHeaderMap.@each(self; @body(key, value)) @private
{
	foreach (k : self.keys[:self.len])
	{
		Entry e = self.data[k];
		@body(e.key, e.value);
	}
}