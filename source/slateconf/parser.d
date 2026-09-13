module parser;
import slateconf;

class NotImplementedError : Exception {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
    super(msg, file, line);
  }
}

SlateConf parse(string config) {
  import std.string : splitLines, split, strip, startsWith, endsWith;
  import std.conv : to;

  SlateConf result;

  long loc = 1;
  string key1_prefix;
  foreach (line; splitLines(config)) {
    line = strip(line);
    if (line == "") continue;

    ConfigNode line_result;

    if (line[0] == '{') {
      auto gr_name = line.strip("{").strip("}") ~ ".";

      if (gr_name != "end") key1_prefix = gr_name;
      else {
        if (key1_prefix == "") {
          throw new SlateConfParseError("cannot use {end} without a group : " ~ to!string(loc));
        }

        auto gr_parts = key1_prefix.split(".");
        gr_parts.length -= 1;
      }
    } else {
      auto parts = line.split("::");

      parts[0] = key1_prefix ~ parts[0];
      foreach (ref part; parts) part = strip(part);

      bool list = parts[0].startsWith("[");
      if (list && !parts[0].endsWith("]")) {
        throw new SlateConfParseError(
          "[ in list declaration not closed : " ~ to!string(loc)
        );
      }

      foreach (i, part; parts) {
        part = strip(part);
        if (part.startsWith("--")) continue;
        else if (parts.length == 1) {
          throw new SlateConfParseError(
            "key " ~ parts[0] ~ " cannot be used by itself : " ~ to!string(loc)
          );
        }

        if (i == cast(ptrdiff_t) parts.length - 1) {
          if (list) {
            line_result.value.sa = parts[1 .. $];
            line_result.is_arr_or_s = true;
          } else {
            line_result.value.s = part;
            line_result.is_arr_or_s = false;
          }
        } else {
          line_result.keys ~= part;
        }
      }
    }

    result.values ~= line_result;
    loc++;
  }

  return result;
}

SlateConf parseFile(string path) {
  import std.file : readText;
  return parse(readText(path));
}

unittest {
  import std.stdio;

  SlateConf result;
  try {
    result = parseFile("example.slate");
  } catch (SlateConfParseError e) {
    writeln(e.msg);
    assert(false);
  }

  assert(result["key"] == "value");
  assert(result["my_group.key"] == "value2");
}
