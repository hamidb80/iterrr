func iseqDefault*[T](): seq[T] =
  newseq[T]()

func iseq*[T](acc: var seq[T], n: T): bool =
  acc.add n
  true

template iseqFinalizer*(n): untyped =
  n

# --------------------------------------

func iminDefault*[T](): T =
  T.low

func imin*[T](maxSoFar: var T, n: T): bool =
  if n > maxSoFar:
    maxSoFar = n
  true

template iminFinalizer*(n): untyped =
  n

# --------------------------------------

func imaxDefault*[T](): T =
  T.low

func imax*[T](maxSoFar: var T, n: T): bool =
  if n > maxSoFar:
    maxSoFar = n
  true

template imaxFinalizer*(n): untyped =
  n

# --------------------------------------

func ianyDefault*[T](): bool =
  false

func iany*[T](res: var bool, n: bool): bool =
  if n:
    res = true
    false

  else:
    true

template ianyFinalizer*(n): untyped =
  n

# --------------------------------------

func iallDefault*[T](): bool =
  true

func iall*[T](res: var bool, n: bool): bool =
  if n:
    true

  else:
    res = false
    false

template iallFinalizer*(n): untyped =
  n

# --------------------------------------
import std/sets

func iHashSetDefault*[T](): HashSet[T] =
  initHashSet[T]()

func iHashSet*[T](res: var HashSet[T], n: T): bool =
  res.incl n
  true

template iHashSetFinalizer*(n): untyped =
  n

# --------------------------------------

type IStrJoinState = object
  sep, acc: string

func iStrJoinDefault*[T](): IStrJoinState =
  result

func iStrJoinDefault*(separator: string): IStrJoinState =
  IStrJoinState(sep: separator)

func iStrJoin*(res: var IStrJoinState, n: string): bool =
  if res.acc == "":
    res.acc = n
  else:
    res.acc &= res.sep & n

  true

template iStrJoinFinalizer*(n): untyped =
  n.acc
