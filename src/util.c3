module util;

fn char[]! dup_bytes(char []in, char[] prev, Allocator* allocator)
{
    usz n = in.len;
    char* p = (char*)allocator.realloc(prev.ptr, n)!;
    char[] s = (char[])p[:n];
    s[..] = in[..];
    return s;
}