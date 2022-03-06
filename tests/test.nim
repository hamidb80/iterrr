import std/[unittest, tables]
import iterrr


test "HSlice":
  echo 1..20 >< imap(it * it).ifilter(it > 10).imax()

test "table":
  let t = toTable {"a": 1, "b": 2, "c": 3, "d": 4}
  echo t.keys >< iStrJoin(",")
