module http::stringmap(<N>);
import std::hash::fnv64a;

// Hash map definition.

const MAX_ENTRIES = 1 << N;
const MASK = MAX_ENTRIES - 1;

struct Map
{
    Entry[MAX_ENTRIES * 2] data;
    ushort[MAX_ENTRIES] keys;
    ushort len;
}

struct Entry
{
    String key;
    String value;
}

fn void Map.reset(&self)
{
    *self = {};
}

fn bool Map.has(&self, String key)
{
    self.@walk(key; Entry e, ushort i)
    {
        if (e.key == key) return true;
        if (e.key == "") return false;
    };
}

fn String! Map.get(&self, String key)
{
    self.@walk(key; Entry e, ushort i)
    {
        if (e.key == key) return e.value;
        if (e.key == "") return SearchResult.MISSING?;
    };
}

fn bool Map.set(&self, String key, String value)
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

fn void Map.del(&self, String key)
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

macro Map.@walk(self, str; @body(entry, i)) @private
{
    ulong h = fnv64a::encode(str);
    ushort step = (ushort)(h >> (64 - (N + 1))) | 1;
    ushort i = (ushort)h & MASK;
    while (true)
    {
        Entry entry = self.data[i];
        @body(entry, i);
        i = (i + step) & MASK;
    }
}

macro Map.@each(self; @body(key, value))
{
	foreach (k : self.keys[:self.len])
	{
		Entry e = self.data[k];
		@body(e.key, e.value);
	}
}