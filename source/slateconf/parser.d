module parser;
import slateconf;
import std.stdio;

class NotImplementedError : Exception {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
    super(msg, file, line);
  }
}

SlateConf parse(string config) {
  import std.string : splitLines, split, strip, startsWith, endsWith;
  import std.algorithm : canFind;
  import std.array : join;

  SlateConf result;

  long loc = 1;
  string key1_prefix;

  string expand(string text) {
    auto words = text.split();
    foreach (ref w; words) {
      if (w.length && w[0] == '*') {
        debug writeln("expanding macro " ~ w);

        auto name = w.strip("*");
        if (auto v = name in result.macros) w = *v;
      }
    }
    return words.join(" ");
  }

  foreach (line; splitLines(config)) {
    line = strip(line);
    if (line == "") {
      loc++; continue;
    }

    ConfigNode line_result;

    debug writeln("  \033[2m" ~ line ~ "\033[0m");
    if (line[0] == '{') {
      auto gr_name = line.strip("{").strip("}");

      if (gr_name != "end") {
        key1_prefix = gr_name ~ ".";
      } else {
        if (key1_prefix == "") {
          throw new SlateConfParseError(
            "cannot use {end} without a group",
            loc
          );
        }

        key1_prefix = "";
      }

      debug writeln("key1_prefix: " ~ key1_prefix);
    } else if (line[0] == '@') {
      auto parts = line.split("::");

      if (parts.length == 1) {
        throw new SlateConfParseError("cannot define a macro with no value", loc);
      }

      debug writeln("adding macro " ~ parts[0] ~ ": " ~ parts[1]);
      result.macros[parts[0].strip("@").strip()] = expand(strip(parts[1]));
    } else {
      line = expand(line);

      auto parts = line.split("::");

      parts[0] = key1_prefix ~ parts[0];
      foreach (ref part; parts) part = strip(part);

      bool list = parts[0].startsWith("[");
      if (list && !parts[0].endsWith("]")) {
        throw new SlateConfParseError("[ in list declaration not closed", loc);
      }

      foreach (i, part; parts) {
        part = strip(part);
        if (part.startsWith("--")) {
          continue;
        }

        else if (parts.length == 1) {
          throw new SlateConfParseError("key " ~ parts[0] ~ " cannot be used by itself", loc);
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
  debug writeln("\033[1;91mparsing example.slate\033[0m");

  void checkExpr(string expr)() {
    debug write("  " ~ expr ~ ": ");
    mixin("assert(" ~ expr ~ ");");
    debug writeln("\033[92;1mok\033[0m");
  }

  SlateConf result;
  try {
    result = parseFile("example.slate");
  } catch (SlateConfParseError e) {
    writeln(e.msg);
    assert(false);
  }

  debug writeln("\033[1;91mchecking values\033[0m");

  checkExpr!(`result["key"] == "value"`)();
  checkExpr!(`result["my_group.key"] == "value2"`)();
}
