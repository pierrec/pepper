module template;
import std::io;

struct StreamTextTemplate
{
	Allocator* allocator;
	String template;
	String start;
	String end;
}

/**
 * @require tag_start != tag_end
 **/
fn void! StreamTextTemplate.init(&self,
	Stream reader,
	String tag_start = DEFAULT_START_TAG,
	String tag_end = DEFAULT_END_TAG,
	Allocator* using = mem::heap())
{
	ByteWriter bw;
	bw.init(.using = using);
	reader.copy_to(bw.as_stream())!;
	*self = { .allocator = using, .template = bw.as_str(), .start = tag_start, .end = tag_end };
}

fn void! StreamTextTemplate.init_from_string(&self,
	String template,
	String tag_start = DEFAULT_START_TAG,
    String tag_end = DEFAULT_END_TAG)
{
	*self = { .template = template, .start = tag_start, .end = tag_end };
}

fn bool StreamTextTemplate.is_initialized(&self) @inline
{
	return !(!self.allocator);
}

fn void! StreamTextTemplate.free(&self) @inline
{
	if (self.allocator)
	{
		self.allocator.free(self.template)!;
		*self = {};
	}
}

macro usz! StreamTextTemplate.@render(self, Stream writer; @body(name, n))
{
	usz n;
	String t = self.template;
	while (true)
	{
		usz! start = t.index_of(self.start);
		if (catch start)
		{
			n += writer.write(t)!;
			return n;
		}
		n += writer.write(t[:start])!;
		t = t[start + self.start.len..];
		usz end = t.index_of(self.end)!;
		String name = t[:end].trim();
		@body(name, n);
		t = t[end + self.end.len..];
	}
	return n;
}