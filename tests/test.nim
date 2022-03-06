import std/[unittest, tables, strformat, sets, sequtils, strutils]
import iterrr


test "HSlice -> _":
  check (1..20 >< imap(it * it).ifilter(it > 10).imax()) == 400

test "_ -> HashSet":
  check (-5..5 >< imap(abs it).iHashSet()) == toHashSet toseq 0..5

test "Table.pairs -> _":
  let 
    t = newOrderedTable {"a": 1, "b": 2, "c": 3}
    res = t.pairs >< imap(fmt"{it[0]}: {it[1]}").iStrJoin(", ") 

  check res == "a: 1, b: 2, c: 3"

test "multi imap and ifilters":
  let res =
    -2..4 >!< 
      imap($it)
      .ifilter(it != "0")
      .ifilter('-' in it)
      .imap(parseInt it)

  check res == @[-2, -1]
