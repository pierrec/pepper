module scanner_test @test;
import scanner;
import std::collections::list;
import std::io;

def Results = List<String>;

struct ScanTest
{
    String in;
    String[] out;
    String left_over;
}

fn void! scanner()
{
    ScanTest[] tcases = {
        {"a,b", {"a"}, "b"},
        {"a,b,", {"a", "b"}, ""},
        {"ab,c", {"ab"}, "c"},
        {"ab,cd,e", {"ab", "cd"}, "e"},
    };
    foreach (tc : tcases)
    {
        ByteReader br;
        br.init(tc.in);
        Scanner sc;
        char[16] buffer;
        sc.init(br.as_stream(), buffer[..]);

        Results results;
        while (sc.scan(',')!)
        {
            String str = (String)sc.bytes();
            results.push(str.tconcat(""));
        }

        String[] got = results.array_view();
        assert(equals(got, tc.out), "%s -> %s", tc.in, got);
        String left_over = (String)sc.bytes();
        assert(left_over == tc.left_over, "%s -> %s", tc.in, left_over);
    }
}