import std/[unittest, tables, strformat, sets]
import iterrr


test "HSlice":
  echo 1..20 >< imap(it * it).ifilter(it > 10).imax()

test "HashSet":
  echo -5..5 >!< imap(abs it).iHashSet()

test "Table":
  let t = toTable {"a": 1, "b": 2, "c": 3, "d": 4}
  echo t.pairs >< imap(fmt"{it[0]}: {it[1]}").iStrJoin(", ") 
