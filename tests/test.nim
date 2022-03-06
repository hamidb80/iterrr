import std/[unittest, tables, strformat, sets, sequtils]
import iterrr


test "HSlice ->":
  check (1..20 >< imap(it * it).ifilter(it > 10).imax()) == 400

test "-> HashSet":
  check (-5..5 >< imap(abs it).iHashSet()) == toHashSet toseq 0..5

test "Table.pairs ->":
  let 
    t = newOrderedTable {"a": 1, "b": 2, "c": 3}
    res = t.pairs >< imap(fmt"{it[0]}: {it[1]}").iStrJoin(", ") 

  check res == "a: 1, b: 2, c: 3"
