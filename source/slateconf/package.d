module slateconf;
public import slateconf.parser;

// While writing this, I was arguing with a person who said D means dicks.

/// Handles values in a ConfigNode. Check which value to use in is_arr_or_s from the ConfigNode.
private union ConfigNodeValue {
  string s;
  string[] sa;
}

struct ConfigNode {
  string group;
  string[] keys;
  ConfigNodeValue value;
  bool is_arr_or_s;
}

/**
 * Thrown from `slateconf.parse()` when the parsing fails.
 * The message is meant to be shown to the user when the parsing fails.
 *
 * Params:
 *   - msg = base message
 *   - error_at_line = line in which the error is located
 */
class SlateConfParseError : Exception {
  /// Line of code where the error occured.
  public ulong error_at_line;

  this(string msg, ulong error_at_line, string file = __FILE__, size_t line = __LINE__) {
    import std.conv : to;

    this.error_at_line = error_at_line;
    super(msg ~ ": " ~ to!string(error_at_line), file, line);
  }
}

/// Thrown when `slateconf.SlateConf.opIndex()` fails because of a non-existent key.
class SlateConfOpIndexError : Exception {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
    super(msg, file, line);
  }
}

/**
 * Main struct for the parsed config.
 *
 * Throws:
 *   - opIndex
 *     - Throws SlateConfOpIndexError if the key does not exist.
 *   - this
 *     - See `slateconf.parseFile()`.
 *
 * Examples:
 * ---
 * SlateConf conf;
 * try {
 *   conf = SlateConf("file.slate");
 * } catch (SlateConfParseError e) {
 *   writeln("Error parsing file.slate: " ~ e.msg);
 *   exit(1);
 * }
 * ---
 */
struct SlateConf {
  ConfigNode[] values;

  /// Macros for the parser, name: content format
  string[string] macros;

  import std.variant : Algebraic;
  Algebraic!(string, string[]) opIndex(string val) {
    import std.array : join;

    foreach (key; values) {
      auto wgroup = key.keys.join(".");
      if (wgroup == val) {
        if (key.is_arr_or_s) return Algebraic!(string, string[])(key.value.sa);
        else return Algebraic!(string, string[])(key.value.s);
      }
    }

    throw new SlateConfOpIndexError("no such value " ~ val);
  }

  this(string file_path) {
    this = parseFile(file_path);
  }
}
