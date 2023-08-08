module text_test;
import template::text;
import std::io;

def Tmpl = TextTemplate(<Data>);

struct Data
{
	String user;
	String world;
	bool ok;
}

fn void! test_render_notag() @test
{
	String tmpl = "hello world";
	Tmpl t;
	t.init(tmpl, .using = mem::temp())!;
	defer t.free()!!;

	ByteWriter bw;
	bw.tinit();

	t.write_stream(bw.as_stream())!;
	assert(bw.as_str() == tmpl, "got '%s'; want '%s'", bw.as_str(), tmpl);
}

fn void! test_render_tag1() @test
{
	String tmpl = "hello world and {{user}}";
	Tmpl t;
	t.data = { .user = "Joe" };
	t.init(tmpl, .using = mem::temp())!;
	defer t.free()!!;

	ByteWriter bw;
	bw.tinit();

	t.write_stream(bw.as_stream())!;
	assert(bw.as_str() == "hello world and Joe", "got '%s'; want '%s'", bw.as_str(), "hello world and Joe");
}

def FooTmpl = TextTemplate(<Foo>);
def BarTmpl = TextTemplate(<Bar>);
def Callback = text::Callback(<Bar>);

struct Foo
{
	String foo;
	BarTmpl* bar;
}

struct Bar
{
	String bar;
	Callback cb;
}

fn usz! Bar.iter(&self, Stream writer)
{
	usz n;
	for (usz i = 0; i < 3; i++)
	{
		char[8] buf;
		char[] s = io::bprintf(buf[..], "#%d# ", i)!;
		n += writer.write(s)!;
	}
	return n;
}

fn void! test_render_template() @test
{
	String bar_tmpl = "##{{bar}}##";
	BarTmpl bt;
	bt.data = { .bar = "BAR" };
	bt.init(bar_tmpl, .using = mem::temp())!;
	defer bt.free()!!;

	String foo_tmpl = "<<{{foo}} | {{bar}}>>";
	FooTmpl ft;
	ft.data = { .foo = "FOO", .bar = &bt };
	ft.init(foo_tmpl, .using = mem::temp())!;
	defer ft.free()!!;

	ByteWriter bw;
	bw.tinit();

	ft.write_stream(bw.as_stream())!;
	assert(bw.as_str() == "<<FOO | ##BAR##>>", "got '%s'; want '%s'", bw.as_str(), "<<FOO | ##BAR##>>");
}

fn void! test_render_template_iter() @test
{
	String bar_tmpl = "{{cb}}";
	BarTmpl bt;
	bt.data = { .cb = &Bar.iter };
	bt.init(bar_tmpl, .using = mem::temp())!;
	defer bt.free()!!;

	ByteWriter bw;
	bw.tinit();

	bt.write_stream(bw.as_stream())!;
	assert(bw.as_str() == "#0# #1# #2# ", "got '%s'; want '%s'", bw.as_str(), "#0# #1# #2# ");
}

fn void! test_read_from_string()
{
	String tmpl = "hello {{world}} and {{user}}";
	Tmpl t;
	t.init(tmpl, .using = mem::temp())!;
	defer t.free()!!;

	ByteWriter bw;
	bw.tinit();

	Data data;
	bool ok = t.read_from_string("hello Monde and Joe", &data);
	assert(ok);
	assert(data.user == "Joe");
	assert(data.world == "Monde");
}