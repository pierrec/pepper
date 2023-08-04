module stringmap_test @test;
import http::stringmap;

def Map = Map(<4>);

fn void! test_map()
{
	Map map;

	assert(map.len == 0);

	assert(!map.has("foo"));
	map.set("foo", "bar");
	assert(map.has("foo"));
	assert(map.get("foo")! == "bar");

	assert(!map.has("foz"));
	map.set("foz", "baz");
	assert(map.has("foz"));
	assert(map.get("foz")! == "baz");

	map.@each(; String key, String value)
	{
		switch (key)
		{
			case "foo":
				assert(value == "bar");
			case "foz":
				assert(value == "baz");
			default:
				assert(false);
		}
	};

	map.clear();
	assert(!map.has("foo"));
	assert(!map.has("foz"));
	assert(map.len == 0);
}