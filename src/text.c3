module template;
import std::io;

struct Template
{
	TemplateInterface fns;
	void* data;
}

def WriteToFn = fn usz!(void*, Stream);
def ReadFromStringFn = fn bool(void*, String, void*);

struct TemplateInterface
{
	WriteToFn write_to;
	ReadFromStringFn read_from_string;
}

/**
 * @require Type.kindof == STRUCT
 **/
module template::text(<Type>);
import std::io;
import std::collections::list;

def TextTagList = List(<TextTag>);
def Callback = fn usz!(Type*, Stream);

fault TextError
{
	UNTERMINATED_TAG,
	EMPTY_TAG,
	MISSING_TAG,
	UNSUPPORTED_TAG,
}

enum TextTagKind: char
{
	STRING,
	TEMPLATE,
	CALLBACK,
}

struct TextTemplate
{
	Allocator* allocator;
	String template;
	TextTag[] tags;
	Type data;
}

struct TextTag
{
	usz start;
	usz end;
	TextTagKind kind;
	union {
		usz offset;
		Template template;
		Callback callback;
	}
}

/**
 * @require self.tags.len == 0 "template already initialized"
 * @require tag_start != tag_end
 * @require template.len > 0 "empty template"
 **/
fn void! TextTemplate.init(&self, String template, String tag_start = "{{", String tag_end = "}}", Allocator* using = mem::heap())
{
	TextTagList tags;
	String tmpl = template;
	Type data = self.data;
	while (true)
	{
		usz! start = tmpl.index_of(tag_start);
		if (catch start) break;
		tmpl = tmpl[start + tag_start.len..];

		usz! end = tmpl.index_of(tag_end);
		if (catch end) return TextError.UNTERMINATED_TAG?;
		String name = tmpl[:end].trim();
		if (name == "") return TextError.EMPTY_TAG?;
		// Check that the tag exists in the data struct.
		TextTag tag = {|
			$foreach ($m : Type.membersof)
				if (name == $m.nameof)
				{
					$switch
						$case $m.typeid == String.typeid:
							return TextTag{
								.kind = STRING,
								.offset = $m.offsetof,
							};
						$case $m.typeid == Callback.typeid:
							Callback cb = data.$eval($m.nameof);
							assert(cb, "Initialize %s.%s before calling init", Type.nameof, name);
							return TextTag{
								.kind = CALLBACK,
								.callback = cb,
							};
						$case $checks(data.$eval($m.nameof).as_template()):
							Template t = data.$eval($m.nameof).as_template();
							assert(t.data, "Initialize %s.%s before calling init", Type.nameof, name);
							return TextTag{
								.kind = TEMPLATE,
								.template = t,
							};
						$default:
							return TextError.UNSUPPORTED_TAG?;
					$endswitch
				}
			$endforeach
			io::printfn("MISSING_TAG: %s", name);
			return TextError.MISSING_TAG?;
		|}!;
		tmpl = tmpl[end + tag_end.len..];

		tag.start = start;
		tag.end = start + tag_start.len + end + tag_end.len;
		tags.push(tag);
	}

	*self = { .allocator = using, .template = template, .tags = tags.array_view(), .data = data };
}

fn void! TextTemplate.free(&self)
{
	self.allocator.free(self.tags)!;
	*self = {};
}

fn Stream TextTemplate.as_stream(&self)
{
	return { .fns = &texttemplate_interface, .data = self };
}

StreamInterface texttemplate_interface = {
	.write_stream_fn = fn(s, out) => ((TextTemplate*)s.data).write_to(out),
};

fn Template TextTemplate.as_template(&self)
{
    return { .fns = template_interface, .data = self };
}

TemplateInterface template_interface @private = {
    .write_to = fn (p, out) => ((TextTemplate*)p).write_to(out),
};

fn usz! TextTemplate.write_to(&self, Stream writer)
{
	usz n;
	usz pos;
	foreach (tag : self.tags)
	{
		n += writer.write(self.template[pos:tag.start])!;
		pos += tag.end;
		switch (tag.kind)
		{
			case STRING:
				uptr data_ptr = (uptr)&self.data + tag.offset;
				String* p = (String*)data_ptr;
				n += writer.write(*p)!;
			case TEMPLATE:
				Template t = tag.template;
				n += t.fns.write_to(t.data, writer)!;
			case CALLBACK:
				Callback cb = tag.callback;
				n += cb(&self.data, writer)!;
		}
	}
	n += writer.write(self.template[pos..])!;
	return n;
}

fn bool TextTemplate.read_from_string(&self, String str, Type* data)
{
	if (self.tags.len == 0) return str == self.template;
	TextTag tag0 = self.tags[0];
	String chunk = self.template[:tag0.start];
	if (!str.starts_with(chunk)) return false;
	str = str[chunk.len..];
	usz pos = tag0.end;
	foreach (tag : self.tags[1..])
	{
		assert(tag.kind == STRING);
		chunk = self.template[pos..tag.start - 1];
		assert(chunk.len > 0);
		usz! i = str.index_of(chunk);
		if (catch i) return false;
		uptr data_ptr = (uptr)data + tag.offset;
		String* p = (String*)data_ptr;
		*p = str[:i];
		str = str[i..];
		pos += tag.end;
	}
	return self.template[pos..] == str;
}