module scanner;
import std::io;

struct Scanner
{
    Stream src;
    char[] buf;
    usz anchor;
    usz split_idx;
    usz read_idx;
}

/**
 * Scanner provides a way to read delimited data (with newlines as the default).
 * @require buffer.len > 0 "Non-empty buffer required."
 **/
fn void Scanner.init(Scanner *sc, Stream src, char[] buffer)
{
    *sc = { .src = src, .buf = buffer };
}

/**
 * Scan the stream for the next split character and return whether it was found.
 **/
fn bool! Scanner.scan(Scanner *sc, char split = '\n')
{
    if (sc.read_idx == 0)
    {
        // First read.
        if (!sc.refill()!) return false;
    }
    usz n = sc.read_idx - sc.split_idx;
    char[] buf = sc.buf[sc.split_idx:n];
    if (try i = array::index_of(buf, split))
    {
        sc.anchor = sc.split_idx;
        sc.split_idx += i + 1;
        return true;
    }
    if (sc.split_idx == 0)
    {
       // Split character not found with maximized search, abort.
        sc.split_idx = sc.read_idx + 1;
        return false;
    }
    // Split character not found: maximize the search and try again.
    sc.buf[:n] = buf[..];
    sc.anchor = 0;
    sc.split_idx = 0;
    sc.read_idx = n;
    if (!sc.refill()!) return false;
    return sc.scan(split);
}

fn bool! Scanner.refill(Scanner *sc) @private
{
    usz n = sc.read_idx - sc.split_idx;
    sc.buf[:n] = sc.buf[sc.split_idx:n];
    sc.anchor = 0;
    sc.split_idx = 0;
    sc.read_idx = n;
    usz! nn = sc.src.read(sc.buf[sc.read_idx..]);
    if (catch err = nn)
    {
        case IoError.EOF:
            sc.split_idx = sc.read_idx + 1;
            return false;
        default:
            return err?;
    }
    sc.read_idx += nn;
    return true;
}

/**
 * Return the current matching bytes, excluding the split character.
 * The bytes may not be valid after the next scan.
 * At the end of a scan, the remaining bytes are returned.
 **/
fn char[] Scanner.bytes(Scanner *sc)
{
    usz n = sc.split_idx - sc.anchor;
    return sc.buf[sc.anchor:n-1];
}