module testing;
import std::io;

macro void! assert_equal(a, b, tag = "")
{
	$if $typeof(a).typeid != $typeof(b).typeid:
		assert(false, "%s != %s", $typeof(a).nameof, $typeof(b).nameof);
	$else
	bool ok;
	$if $checks(equals(a, a)):
		ok = equals(a, b);
	$else
		ok = deep_equal(a, b);
	$endif
	if (!ok)
	{
		@stack_mem(256; Allocator* using = mem::temp())
		{
			String sa;
			String sb;
			$if $checks(a.as_str()):
            	sa = a.as_str();
            	sb = b.as_str();
			$else
				DString da;
				da.init(8, using);
				as_str(a, &da)!;
				sa = da.as_str();
				DString db;
				db.init(8, using);
				as_str(b, &db)!;
				sb = db.as_str();
			$endif
			assert(false, "%s got %s; want %s", tag, sa, sb);
		};
	}
	$endif
}

macro bool deep_equal(a, b)
{
	$if $typeof(a).typeid != $typeof(b).typeid:
		assert(false, "%s != %s", $typeof(a).nameof, $typeof(b).nameof);
	$else
	$switch ($typeof(a).kindof)
		$case ARRAY:
		$case SUBARRAY:
			if (a.len != b.len) return false;
			foreach (i, x : a)
			{
				if (!deep_equal(x, b[i])) return false;
			}
			return true;
		$case BITSTRUCT:
		$case STRUCT:
			$foreach ($m : $typeof(a).membersof)
				$if $m.nameof != "": // skip union fields
					if (!deep_equal(a.$eval($m.nameof), b.$eval($m.nameof))) return false;
				$endif
			$endforeach
			return true;
		$default:
			return equals(a, b);
	$endswitch
	$endif
}

macro as_str(a, DString* str)
{
	var $Type = $typeof(a);
	$switch ($Type.kindof)
		$case ARRAY:
		$case SUBARRAY:
			str.append("[");
			foreach (i, x : a)
			{
				if (i > 0) str.append(", ");
				as_str(x, str)!;
			}
			str.append("]");
		$case BITSTRUCT:
		$case STRUCT:
			str.append("{");
			$foreach ($i, $m : $typeof(a).membersof)
				$if $m.nameof != "": // skip union fields
					$if $i > 0:
						str.append(", ");
					$endif
					as_str(a.$eval($m.nameof), str)!;
				$endif
			$endforeach
			str.append("}");
		$default:
			char[256] buf;
			String s = (String)io::bprintf(buf[..], "%s", a)!;
			$switch ($Type.nameof)
				$case "String":
				$case "DString":
				$case "WString":
				$case "ZString":
					str.append(`"`);
					str.append(s);
					str.append(`"`);
				$default:
					str.append(s);
			$endswitch
	$endswitch
}