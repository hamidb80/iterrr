import std/[macros, options]

template rangeError(): untyped =
  raise newException(RangeDefect, "finding minimum between 0 elements")

# --------------------------------------

func iseqInit*[T](): seq[T] =
  newseq[T]()

func iseq*[T](acc: var seq[T], n: T): bool =
  acc.add n
  true

template iseqFinalizer*(n): untyped =
  n

# --------------------------------------

func icountInit*[T](): int = 0

func icount*[T](acc: var int, _: T): bool =
  inc acc
  true

template icountFinalizer*(n): untyped = n

# --------------------------------------

func iminInit*[T](): Option[T] =
  none T

func imin*[T](res: var Option[T], n: T): bool =
  if (isNone res) or (res.get > n):
    res = some n

  true

func iminFinalizer*[T](res: var Option[T]): T =
  if issome res: res.get
  else: rangeError()

# --------------------------------------

func imaxInit*[T](): Option[T] =
  none T

func imax*[T](res: var Option[T], n: T): bool =
  if (isNone res) or (res.get < n):
    res = some n

  true

func imaxFinalizer*[T](res: var Option[T]): T =
  if issome res: res.get
  else: rangeError()

# --------------------------------------

func ianyInit*[T](): bool =
  false

func iany*(res: var bool, n: bool): bool =
  if n:
    res = true
    false

  else:
    true

template ianyFinalizer*(n): untyped =
  n

# --------------------------------------

func iallInit*[T](): bool =
  true

func iall*(res: var bool, n: bool): bool =
  if n:
    true

  else:
    res = false
    false

template iallFinalizer*(n): untyped =
  n

# --------------------------------------
import std/sets

func iHashSetInit*[T](): HashSet[T] =
  initHashSet[T]()

func iHashSet*[T](res: var HashSet[T], n: T): bool =
  res.incl n
  true

template iHashSetFinalizer*(n): untyped =
  n

# --------------------------------------

type IStrJoinState = object
  sep, acc: string

func iStrJoinInit*[T](): IStrJoinState =
  result

func iStrJoinInit*(separator: string): IStrJoinState =
  IStrJoinState(sep: separator)

func iStrJoin*(res: var IStrJoinState, n: string): bool =
  if res.acc == "":
    res.acc = n
  else:
    res.acc &= res.sep & n

  true

template iStrJoinFinalizer*(n): untyped =
  n.acc
