import std/[unittest, sets, sequtils, strutils, math]
import iterrr

suite "main entities":
  test "maps":
    check (1..5) |>
      map($it).
      map(it & "0").
      map(parseInt it).
      toSeq() == @[10, 20, 30, 40, 50]

  test "filters":
    check (1..5) |>
      filter(it mod 2 == 1).
      filter(it != 3).
      toSeq() == @[1, 5]

  test "breakif":
    check (1..5) |> breakif(it == 4).toSeq() == @[1, 2, 3]

  test "do":
    var c = 0
    discard "yes".items |> filter(true).do(inc c).toSeq()
    check c == 3

  test "mix":
    check (1..5) |> map(it * it).filter(it > 10).toSeq() == @[16, 25]

    var c = 0
    check "yes".items |> map((c, it)).do(inc c).toSeq() == @[(0, 'y'), (1, 'e'),
        (2, 's')]

test "nested":
  let r = @[@[1, 2], @[3, 4]].pairs |>
    map[ia, a](
      a.pairs |> map[ib, _]((ia, ib)).toseq()).toseq()

  check r == @[@[(0, 0), (0, 1)], @[(1, 0), (1, 1)]]

suite "custom ident :: []":
  test "1":
    check (1..10) |> filter[i](i < 5).toSeq() == @[1, 2, 3, 4]

  test "1+":
    check (1..10) |> filter[i](i <= 5).toSeq() == toseq 1..5
    check "hello".pairs |> map[i, c](i + ord(c)).toSeq() == @[104, 102, 110,
        111, 115]

  test "chain":
    let res = (1..30) |>
      map[n]($n)
      .filter[s](s.len == 1)
      .map[s](parseInt s)
      .toSeq()

    check res == toseq 1..9

suite "custom ident :: =>":
  test "single":
    check (1..10) |> filter(n => n in 3..5).toSeq() == @[3, 4, 5]

  test "single inside pars":
    check (1..10) |> filter((n) => n in 2..4).toSeq() == @[2, 3, 4]

  test "multi":
    check "hello".pairs |> map((idx, c) => c).toSeq() == toseq "hello".toseq

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

test "custom code (AKA no reducer)":
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

  test "toHashSet":
    check (-5..5) |> map(abs it).toHashSet() == toHashSet toseq 0..5


import std/deques
suite "adapters":
  let matrix = [
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9]
  ]

  test "cycle":
    check (1..3) |> cycle(7).toseq() == @[1, 2, 3, 1, 2, 3, 1]

  test "drop":
    check (1..7) |> drop(3).toseq() == @[4, 5, 6, 7]

  test "take":
    check (1..7) |> take(3).toseq() == @[1, 2, 3]

  test "flatten":
    check matrix.items |> flatten().toseq() == toseq(1..9)

  test "group":
    check (1..5) |> group(2).toseq() == @[@[1, 2], @[3, 4], @[5]]
    check (1..5) |> group(2, false).toseq() == @[@[1, 2], @[3, 4]]

  test "window":
    let acc = (1..5) |> window(3).toseq()
    check acc.mapIt(it.toseq) ==  @[@[1, 2, 3], @[2, 3, 4], @[3, 4, 5]]

  test "mix":
    check matrix.items |> flatten().map(-it).cycle(11).group(4).toseq() == @[
      @[-1, -2, -3, -4], @[-5, -6, -7, -8], @[-9, -1, -2]
    ]

suite "custom adapter":
  test "typed args":
    iterator plus(loop: T; `by`: int): T {.adapter.} =
      for it in loop:
        yield it + `by`

    check (1..5) |> plus(2).toseq() == toseq(3..7)

  test "untyped args":
    iterator plus(loop: T; `by`): T {.adapter.} =
      for it in loop:
        yield it + `by`

    check (1..5) |> plus(2).toseq() == toseq(3..7)

  test "default value":
    iterator plus(loop: T; `by`: int = 2): T {.adapter.} =
      for it in loop:
        yield it + `by`

    check (1..5) |> plus().toseq() == toseq(3..7)
    check (1..5) |> plus(1).toseq() == toseq(2..6)

  test "multi args":
    iterator ALU(loop: T; `adder`, `mult`: int): T {.adapter.} =
      for it in loop:
        yield (it + `adder`) * `mult`

    check (1..3) |> ALU(1, -1).toseq() == @[-2, -3, -4]
