module stringmap(<Value, N>);
import std::hash::fnv32a;
import std::hash::fnv64a;
import std::io;

const MASK = (1 << N) - 1;

struct StringMap
{
    PackedStrings keys;
    HashMap values;
}

fn void StringMap.init(&self)
{
    self.keys.init();
    self.values.init();
}

fn bool StringMap.has(&self, String key)
{
    return self.values.has(key);
}

fn Value! StringMap.get(&self, String key)
{
    return self.values.get(key);
}

fn void! StringMap.set(&self, String key, Value value)
{
    defer catch self.values.del(key);
    self.values.set(key, value);
    self.keys.push(key)!;
}

fn void StringMap.del(&self, String key)
{
    self.keys.del(key);
    self.values.del(key);
}

macro StringMap.@walk(list; @body(k, v))
{
    @walk_packedstrings(list.keys; String k, usz start)
    {
        Value v = list.values.get(k)!!;
        @body(k, v);
    };
}

struct HashMap
{
    Entry[1 << N] data;
    usz len;
}

struct Entry
{
    uint hash;
    Value value;
}

fn void HashMap.init(&hm)
{
    *hm = {};
}

fn bool HashMap.has(&hm, String str)
{
    @walk_hashmap(hm, str; Entry e, ulong i, uint h)
    {
        if (e.hash == h) return true;
        if (e.hash == 0) return false;
    };
}

fn Value! HashMap.get(&hm, String key)
{
    @walk_hashmap(hm, key; Entry e, ulong i, uint h)
    {
        if (e.hash == h) return e.value;
        if (e.hash == 0) return SearchResult.MISSING?;
    };
}

fn bool HashMap.set(&hm, String key, Value value)
{
    @walk_hashmap(hm, key; Entry e, ulong i, uint h)
    {
        if (e.hash == 0)
        {
            hm.data[i] = { .hash = h, .value = value };
            hm.len++;
            return true;
        }
        if (e.hash == h)
        {
            hm.data[i].value = value;
            return false;
        }
    };
}

fn void HashMap.del(&hm, String key)
{
    @walk_hashmap(hm, key; Entry e, ulong i, uint h)
    {
        if (e.hash == h)
        {
            hm.data[i] = {};
            hm.len--;
            return;
        }
        if (e.hash == 0) return;
    };
}

macro @walk_hashmap(hm, str; @body(entry, i, h))
{
    uint h32 = fnv32a::encode(str);
    assert(h32 != 0, "%s", str);
    ulong h = fnv64a::encode(str);
    ulong step = (h>>(64 - N)) | 1;
    ulong i = h & MASK;
    while (true)
    {
        Entry entry = hm.data[i];
        @body(entry, i, h32);
        i = (i + step) & MASK;
    }
}

struct PackedStrings
{
    char[1 << N] data;
    usz last;
}

fn void PackedStrings.init(&self)
{
    *self = {};
}

/**
 * @require s.len > 0
 **/
fn void! PackedStrings.push(&self, char[] s)
{
    if (self.data.len - self.last < s.len + 1) return IoError.OVERFLOW?;
    self.data[self.last:s.len] = s[..];
    self.last += s.len + 1;
}

/**
 * @require s.len > 0
 **/
fn void PackedStrings.del(&self, char[] s)
{
    @walk_packedstrings(self; char[] str, usz start)
    {
        if (equals(str, s))
        {
            usz end = start + str.len + 1;
            usz n = self.last - end;
            self.data[start:n] = self.data[end:n];
            self.last -= str.len + 1;
            return;
        }
    };
}

macro @walk_packedstrings(list; @body(s, start))
{
    usz start;
    for (usz i = 0; i < list.last; i++)
    {
        if (list.data[i] != 0) continue;
        char[] s = list.data[start:i - start];
        @body((String)s, start);
        start = i + 1;
    }
}