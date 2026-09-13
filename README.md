# slate-conf

A flexible configuration file format for Redrose Linux projects.

```slateconf
key :: value
key1 :: key2 :: value
[my_list] :: thing :: thing :: hello
-- comment
{my_group}
  key :: value2
{end}
```

Soon, this will be a DUB package, and C/C++ bindings are planned.

## Usage

```d
import slateconf;

import std.stdio;
import core.stdc.stdlib : exit;

SlateConf conf;
try {
  conf = SlateConf("file.slate");
} catch (SlateConfParseError e) {
  writeln("Error parsing file.slate: " ~ e.msg);
  exit(1);
}

try {
  writeln(conf["my_group.key"]);
} catch (SlateConfOpIndexError e) {
  writeln("No group 'my_group' in file.slate.");
  exit(1);
}
```
