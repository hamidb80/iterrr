import std/[macros, options]

template rangeError(): untyped =
  raise newException(RangeDefect, "finding between 0 elements")

# --------------------------------------

func iseqInit*[T](): seq[T] = newseq[T]()

func iseq*[T](acc: var seq[T], n: T): bool =
  acc.add n
  true

template iseqFinalizer*(n): untyped = n

# --------------------------------------

func countInit*[T](): int = 0

func count*[T](acc: var int, _: T): bool =
  inc acc
  true

template countFinalizer*(n): untyped = n

# --------------------------------------

func sumInit*[T](): T = default T
func sumInit*[T](n: T): T = n

func sum*[T](acc: var T, n: T): bool =
  inc acc, n
  true

template sumFinalizer*(n): untyped = n

# --------------------------------------

template getOption(n): untyped =
  if issome n: n.get
  else: rangeError()


func minInit*[T](): Option[T] = none T

func min*[T](res: var Option[T], n: T): bool =
  if (isNone res) or (res.get > n):
    res = some n

  true

func minFinalizer*[T](res: Option[T]): T =
  getOption res


func maxInit*[T](): Option[T] = none T

func max*[T](res: var Option[T], n: T): bool =
  if (isNone res) or (res.get < n):
    res = some n

  true

func maxFinalizer*[T](res: Option[T]): T =
  getOption res

# --------------------------------------

func firstInit*[T](): Option[T] = none T

func first*[T](res: var Option[T], val: T): bool =
  if isNone res:
    res = some val
    false

  else:
    true

func firstFinalizer*[T](n: Option[T]): T =
  getOption n


func lastInit*[T](): Option[T] = none T

func last*[T](res: var Option[T], val: T): bool =
  res = some val
  true

func lastFinalizer*[T](n: Option[T]): T =
  getOption n

# --------------------------------------

func anyInit*[T](): bool = false

func any*(res: var bool, n: bool): bool =
  if n:
    res = true
    false

  else:
    true

template anyFinalizer*(n): untyped = n


func allInit*[T](): bool = true

func all*(res: var bool, n: bool): bool =
  if n:
    true

  else:
    res = false
    false

template allFinalizer*(n): untyped = n

# --------------------------------------
import std/sets

func iHashSetInit*[T](): HashSet[T] = initHashSet[T]()

func iHashSet*[T](res: var HashSet[T], n: T): bool =
  res.incl n
  true

template iHashSetFinalizer*(n): untyped = n

# --------------------------------------

type StrJoinState = object
  sep, acc: string

func strJoinInit*[T](): StrJoinState = discard

func strJoinInit*(separator: string): StrJoinState =
  StrJoinState(sep: separator)

func strJoin*[T](res: var StrJoinState, s: T): bool =
  if res.acc == "":
    res.acc = $s
  else:
    res.acc &= res.sep & $s

  true

template strJoinFinalizer*(n): untyped = n.acc
