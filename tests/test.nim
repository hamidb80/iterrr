import std/[unittest, tables, strformat, sets, sequtils, strutils, math]
import iterrr


suite "adapters":
  test "map + filter":
    check ((1..5) |> map(it * it).filter(it > 10)) == @[16, 25]

  test "breakif":
    check (1..5) |> breakif(it == 2) == @[1]

suite "code gen":
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

suite "custom ident :: reduce":
  test "1":
    let res = (1..10) |> reduce[result, n](0):
      result += n

    check res == sum toseq 1..10

  test "1+":
    let res = "hello".pairs |> reduce[result, (idx, ch)](("", 0)):
      result[0] &= ch
      result[1] += idx

    check:
      res[0] == "hello"
      res[1] == sum toseq 0..("hello".high)

test "custom code":
  var acc: string
  (1..10) |> filter(it in 3..5).map($(it+1)).each(num):
    acc &= num

  check acc == "456"

suite "inplace reducer":
  test "without finalizer":
    let t = (1..10) |> reduce(0):
      if it == 6:
        acc = it

    check t == 6

  test "with finalizer":
    let t = (1..10) |> reduce(0, acc - 1):
      acc = it

    check t == 9

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

  test "inplace reducer":
    let prod = (3..6).iterrr reduce(1):
      acc *= it

    check prod == 3*4*5*6

  test "each":
    var acc: seq[int]

    (3..6).iterrr map(it - 2).each(n):
      acc.add n

    check acc == @[1, 2, 3, 4]

  test "multi line":
    var acc: seq[int]
    (3..6).iterrr:
      filter(it > 3)
      map[n](n - 2)
      each(n):
        acc.add n

    check acc == @[2, 3, 4]

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

  test "first":
    check (1..10) |> filter(it > 5).first() == 6

    doAssertRaises RangeDefect:
      discard (1..10) |> filter(it > 10).first()

  test "last":
    check (1..10) |> filter(it < 5).last() == 4

    doAssertRaises RangeDefect:
      discard (1..10) |> filter(it < 0).last()

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


suite "ifor":
  test "filter":
    var acc: seq[int]

    ifor [n1, n2, n3] in [1..2,
                          1..3,
                          1..4,
                          filter n1+n2+n3 == 8]:

      acc.add n1*100 + n2*10 + n3

    check acc == @[134, 224, 233]

  test "breakif":
    var acc: seq[seq[int]]
    ifor [x, y] in [1..3,
                  breakif x == 2,
                  1..4]:

      acc.add @[x, y]

    check acc.allIt it[0] == 1


  test "break_custom_loop":
    var c = 0
    ifor [x, y, z] in [1..3,
                       1..3,
                       1..3]:
      inc c
      break block_x

    check c == 1

  test "tuple ident":
    let qlines = [
      "SELECT COUNT(1) as cnt",
      "FROM people",
      "WHERE age = 87"
    ]

    var numbers: seq[char]
    ifor [statement, (i, ch)] in [qlines, statement.pairs]:
      if ch in '0'..'9':
        numbers.add ch

    check numbers.join == "187"
