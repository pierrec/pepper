module http;
import std::io;

struct HTTPBody
{
	char[] data;
	LimitReader reader;
}

fn void HTTPBody.init(&self, char[] data, Stream reader, usz limit)
{
	*self = { .data = data };
	self.reader.init(reader, limit);
}

fn Stream HTTPBody.as_stream(&self)
{
	return { .fns = &bodyreader_interface, .data = self };
}

StreamInterface bodyreader_interface = {
	.read_fn = fn(s, bytes) => ((HTTPBody*)s.data).read(bytes),
};

fn usz! HTTPBody.read(&self, char[] bytes)
{
	usz n;
	if (self.data.len)
	{
		n = min(bytes.len, self.data.len);
		bytes[:n] = self.data[:n];
		self.data = self.data[n..];
		bytes = bytes[n..];
	}
	n += self.reader.read(bytes)!;
	return n;
}
