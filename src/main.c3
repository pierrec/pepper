module pepper;
import std::collections::list;
import std::io;

// https://www.iana.org/assignments/http-fields/http-fields.txt
const SOURCE = "http-fields.txt";
const OUT = "header_std.c3";

def Strings = List<String>;

enum State
{
    FIND_START,
    EXTRACT_HEADER,
}

fn void main(String[] args)
{
    Strings headers;
    defer headers.free();
    parse_headers(&headers)!!;
    io::printfn("Found %d headers", headers.len());
    write_headers(&headers)!!;
}

fn void! parse_headers(Strings *headers)
{
    File f = file::open(SOURCE, "rb")!;
    defer f.close()!!;
    State state = State.FIND_START;
    while LOOP: (!f.eof())
    {
        @pool() {
            String line = (String)f.tgetline();
            switch (state)
            {
                case State.FIND_START:
                    if (line.contains("Field Name") && line.contains("Status"))
                    {
                        state = State.EXTRACT_HEADER;
                    }
                case State.EXTRACT_HEADER:
                    if (line.len == 0) break LOOP;
                    if (line.len > 1 && line[1] != ' ')
                    {
                        if (line[1] == '*') break;
                        line = line.trim();
                        if (try i = line.index_of(" "))
                        {
                            headers.push(line[:i].concat(""));
                        }
                    }
            }
        };
    }
}

fn void! write_headers(Strings *headers)
{
    File out = file::open(OUT, "w")!;
    defer out.close()!!;
    out.printn("module http;")!;
    out.printn("")!;
    out.print("const String[] STANDARD_HEADERS = {")!;
    foreach (i, h : headers.array_view())
    {
        if (i % 4 == 0) out.printn("  ")!;
        out.print("\"")!;
        out.print(h)!;
        out.print("\", ")!;
    }
    out.printn("")!;
    out.printn("};")!;
}