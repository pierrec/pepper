module template;
import std::io;

const DEFAULT_START_TAG = "{{";
const DEFAULT_END_TAG = "}}";

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