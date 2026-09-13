module slateconf;
public import parser;

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

class SlateConfParseError : Exception {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
    super(msg, file, line);
  }
}

class SlateConfOpIndexError : Exception {
  this(string msg, string file = __FILE__, size_t line = __LINE__) {
    super(msg, file, line);
  }
}

struct SlateConf {
  ConfigNode[] values;

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
