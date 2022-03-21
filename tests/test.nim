import std/[unittest, tables, strformat, sets, sequtils, strutils]
import iterrr


suite "chain generation":
  test "HSlice -> _":
    check ((1..5) |> map(it * it).filter(it > 10)) == @[16, 25]

  test "Table.pairs -> _":
    let
      t = newOrderedTable {"a": 1, "b": 2, "c": 3}
      res = t.pairs |> map(fmt"{it[0]}: {it[1]}").strJoin(", ")

    check res == "a: 1, b: 2, c: 3"

  test "long chain":
    let res =
      [-2, -1, 0, 1, 2].items |>
        map($it)
        .filter(it != "0")
        .filter('-' in it)
        .map(parseInt it)

    check res == @[-2, -1]

suite "custom ident :: []":
  test "1":
    check ((1..10) |> filter[i](i < 5)) == @[1, 2, 3, 4]

  test "1+":
    check ((1..10) |> filter[i](i <= 5)) == toseq 1..5
    check ("hello".pairs |> map[i, c](i + ord(c))) == @[104, 102, 110, 111, 115]

  test "chain":
    let res = (1..30) |>
      map[n]($n)
      .filter[s](s.len == 1)
      .map[s](parseInt s)

    check res == toseq 1..9

suite "custom ident :: =>":
  test "single":
    check (1..10) |> filter(n => n in 3..5) == @[3, 4, 5]

  test "single inside pars":
    check (1..10) |> filter((n) => n in 2..4) == @[2, 3, 4]

  test "multi":
    check "hello".pairs |> map((idx, c) => c) == toseq "hello".toseq


test "custom code":
  var acc: string
  (1..10) |> filter(it in 3..5).map($(it+1)).each(num):
    acc &= num

  check acc == "456"

suite "inline reducer":
  test "without finalizer":
    let t = (1..10) |> reduce[acc, n](0):
      if n == 6:
        acc = n

    check t == 6

  test "with finalizer":
    let t1 = (1..10) |> reduce[acc, n](0, acc - 1):
      acc = n

    check t1 == 9

    let t2 = (1..10) |> reduce(0, acc - 1):
      acc = it

    check t2 == 9


  test "default idents":
    let t = (1..10) |> reduce(0):
      acc = it

    check t == 10

  test "call":
    var result = 0

    discard (1..2) |> reduce[acc, n](0, acc - 1) do:
      result = n
      break

    check result == 1

suite "non-operator":
  test "simple chain":
    check ("hello".items.iterrr filter(it != 'l').count()) == 3
    check iterrr("hello".items, filter(it != 'l').count()) == 3

  test "inline reducer":
    let prod = (3..6).iterrr reduce(1):
      acc *= it

    check prod == 3*4*5*6

  test "each":
    var acc: seq[int]

    (3..6).iterrr map(it - 2).each(n):
      acc.add n

    check acc == @[1, 2, 3, 4]


suite "reducers":
  let
    emptyIntList = newseq[int]()
    emptyBoolList = newseq[bool]()

  test "count":
    check (1..20) |> count() == 20

  test "sum":
    check (1..20) |> sum() == (1+20) * 20 div 2

  test "min":
    doAssertRaises RangeDefect:
      discard emptyIntList.items |> min()

    check [2, 1, 3].items |> min() == 1

  test "max":
    doAssertRaises RangeDefect:
      discard emptyIntList.items |> max()

    check [2, 1, 3].items |> max() == 3

  test "any":
    check:
      emptyBoolList.items |> any() == false
      [false, false, false].items |> any() == false
      [true, false, false].items |> any() == true

  test "all":
    check:
      emptyBoolList.items |> all() == true
      [false, true, true].items |> all() == false
      [true, true, true].items |> all() == true

  test "strJoin":
    check (1..4) |> strJoin(";") == "1;2;3;4"

  test "iHashSet":
    check (-5..5) |> map(abs it).iHashSet() == toHashSet toseq 0..5
