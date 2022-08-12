import std/[macros, options]

template rangeError(): untyped =
  raise newException(RangeDefect, "finding between 0 elements")

# --------------------------------------

func toSeqInit*[T](): seq[T] = newseq[T]()

func toSeqUpdate*[T](acc: var seq[T], n: T): bool =
  acc.add n
  true

template toSeqFinalizer*(n): untyped = n

# --------------------------------------

template countInit*[T](): int = 0

template countUpdate*[T](acc: var int, _: T): bool =
  inc acc
  true

template countFinalizer*(n): untyped = n

# --------------------------------------

func sumInit*[T](): T = default T
func sumInit*[T](n: T): T = n

func sumUpdate*[T](acc: var T, n: T): bool =
  inc acc, n
  true

template sumFinalizer*(n): untyped = n

# --------------------------------------

template getOption(n): untyped =
  if issome n: n.get
  else: rangeError()


func minInit*[T](): Option[T] = none T

func minUpdate*[T](res: var Option[T], n: T): bool =
  if (isNone res) or (res.get > n):
    res = some n

  true

func minFinalizer*[T](res: Option[T]): T =
  getOption res


func maxInit*[T](): Option[T] = none T

func maxUpdate*[T](res: var Option[T], n: T): bool =
  if (isNone res) or (res.get < n):
    res = some n

  true

func maxFinalizer*[T](res: Option[T]): T =
  getOption res

# --------------------------------------

func firstInit*[T](): Option[T] = none T

func firstUpdate*[T](res: var Option[T], val: T): bool =
  if isNone res:
    res = some val
    false

  else:
    true

func firstFinalizer*[T](n: Option[T]): T =
  getOption n


func lastInit*[T](): Option[T] = none T

func lastUpdate*[T](res: var Option[T], val: T): bool =
  res = some val
  true

func lastFinalizer*[T](n: Option[T]): T =
  getOption n

# --------------------------------------

func anyInit*[T](): bool = false

func anyUpdate*(res: var bool, n: bool): bool =
  if n:
    res = true
    false

  else:
    true

template anyFinalizer*(n): untyped = n


func allInit*[T](): bool = true

func allUpdate*(res: var bool, n: bool): bool =
  if n:
    true

  else:
    res = false
    false

template allFinalizer*(n): untyped = n

# --------------------------------------
import std/sets

func toHashSetInit*[T](): HashSet[T] = initHashSet[T]()

func toHashSetUpdate*[T](res: var HashSet[T], n: T): bool =
  res.incl n
  true

template toHashSetFinalizer*(n): untyped = n

# --------------------------------------

type StrJoinState = object
  sep, acc: string

func strJoinInit*[T](): StrJoinState = discard

func strJoinInit*[T](separator: string): StrJoinState =
  StrJoinState(sep: separator)

func strJoinUpdate*[T](res: var StrJoinState, s: T): bool =
  if res.acc == "":
    res.acc = $s
  else:
    res.acc &= res.sep & $s

  true

template strJoinFinalizer*(n): untyped = n.acc

# --------------------------------------

import std/tables

func toCountTableInit*[T](): CountTable[T] = initCountTable[T]()

func toCountTableUpdate*[T](res: var CountTable[T], n: T): bool =
  res.inc n
  true

template toCountTableFinalizer*(n): untyped = n
