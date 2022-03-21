import std/[unittest, tables, strformat, sets, sequtils, strutils]
import iterrr


suite "chain generation":
  test "HSlice -> _":
    check ((1..5) |> imap(it * it).ifilter(it > 10)) == @[16, 25]

  test "Table.pairs -> _":
    let
      t = newOrderedTable {"a": 1, "b": 2, "c": 3}
      res = t.pairs |> imap(fmt"{it[0]}: {it[1]}").iStrJoin(", ")

    check res == "a: 1, b: 2, c: 3"

  test "long chain":
    let res =
      [-2, -1, 0, 1, 2].items |>
        imap($it)
        .ifilter(it != "0")
        .ifilter('-' in it)
        .imap(parseInt it)

    check res == @[-2, -1]

suite "custom ident":
  test "== 1":
    check ((1..10) |> ifilter[i](i < 5)) == @[1, 2, 3, 4]

  test "> 1":
    check ((1..10) |> ifilter[i](i <= 5)) == toseq 1..5
    check ("hello".pairs |> imap[i, c](i + ord(c))) == @[104, 102, 110, 111, 115]

  test "long chain":
    let res = (1..30) |>
      imap[n]($n)
      .ifilter[s](s.len == 1)
      .imap[s](parseInt s)

    check res == toseq 1..9

test "custom code":
  var acc: string
  (1..10) |> ifilter(it in 3..5).imap($(it+1)).do(num):
    acc &= num

  check acc == "456"

suite "inline reducer":
  test "without finalizer":
    let t = (1..10) |> ireduce[acc, n](0):
      if n == 6:
        acc = n

    check t == 6

  test "with finalizer":
    let t1 = (1..10) |> ireduce[acc, n](0, acc - 1):
      acc = n

    check t1 == 9

    let t2 = (1..10) |> ireduce(0, acc - 1):
      acc = it

    check t2 == 9


  test "default idents":
    let t = (1..10) |> ireduce(0):
      acc = it

    check t == 10

  test "call":
    var result = 0

    discard (1..2) |> ireduce[acc, n](0, acc - 1) do:
      result = n
      break

    check result == 1

suite "non-operator":
  test "simple chain":
    check ("hello".items.iterrr ifilter(it != 'l').icount()) == 3
    check iterrr("hello".items, ifilter(it != 'l').icount()) == 3

  test "inline reducer":
    let prod = (3..6).iterrr ireduce(1):
      acc *= it

    check prod == 3*4*5*6

  test "do":
    var acc: seq[int]
    
    (3..6).iterrr imap(it - 2).do(n):
      acc.add n

    check acc == @[1,2,3,4] 


suite "reducers":
  let
    emptyIntList = newseq[int]()
    emptyBoolList = newseq[bool]()

  test "icount":
    check (1..20) |> icount() == 20

  test "isum":
    check (1..20) |> isum() == (1+20) * 20 div 2

  test "imin":
    doAssertRaises RangeDefect:
      discard emptyIntList.items |> imin()

    check [2, 1, 3].items |> imin() == 1

  test "imax":
    doAssertRaises RangeDefect:
      discard emptyIntList.items |> imax()

    check [2, 1, 3].items |> imax() == 3

  test "iany":
    check:
      emptyBoolList.items |> iany() == false
      [false, false, false].items |> iany() == false
      [true, false, false].items |> iany() == true

  test "iall":
    check:
      emptyBoolList.items |> iall() == true
      [false, true, true].items |> iall() == false
      [true, true, true].items |> iall() == true

  test "istrJoin":
    check (1..4) |> iStrJoin(";") == "1;2;3;4"

  test "iHashSet":
    check (-5..5) |> imap(abs it).iHashSet() == toHashSet toseq 0..5
