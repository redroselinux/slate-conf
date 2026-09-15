module parser;
import slateconf;
import std.stdio;

class NotImplementedError : Exception {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
    super(msg, file, line);
  }
}

/**
 * Parse a Slateconf file.
 *
 * Params:
 *   - `config` = The whole file to parse.
 *
 * Throws:
 *   - `SlateConfParseError`: on parse errors
 *   - `NotImplementedError`: in pre-0.1 versions; will be removed
 *   - runs `std.file.readText`, need to catch `FileException`
 *
 * See_Also:
 *   - `slateconf.parseFile`
 *   - `slateconf.SlateConf`
 */
SlateConf parse(string config) {
  import std.string : splitLines, split, strip, startsWith, endsWith, replace;
  import std.algorithm : canFind;
  import std.array : join;

  SlateConf result;

  ulong loc = 1;
  string key1_prefix;

  string expand(string text) {
    auto words = text.split();
    foreach (ref w; words) {
      if (w.length && w[0] == '*') {
        debug writeln("expanding macro " ~ w);

        auto name = w.strip("*");
        if (auto v = name in result.macros) w = *v;
      } else if (w.length && w[0] == '!') {
        import std.file : readText;
        debug writeln("mixing in list from file; " ~ text);
        auto file = text.strip().split("::")[1].replace("!", "").strip();
        string content = readText(file).strip();   // strip trailing newline first
        w = content.replace("\n", "::");
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

      if (list) {
        parts[0] = parts[0][1 .. $-1];
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

/**
 * Wrapper of `parse()` that reads a file path and returns the `SlateConf`.
 *
 * This function is used by the constructor of the SlateConf struct and
 * therefore you should use that instead.
 *
 * Params:
 *   path = File path to read.
 *
 * Throws:
 *   Propagates any exceptions thrown by `std.file.readText()` (e.g. file not
 *   found) or `slateconf.parse()` (e.g. SlateConfParseError).
 *
 * See_Also:
 *   - `slateconf.SlateConf`
 */
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
  checkExpr!(`result["other_list"] == ["test"]`)();
}
