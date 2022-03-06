
# reducers -----------------------------------------

func iseqDefault*[T](): seq[T] =
  newseq[T]()

func iseq*[T](acc: var seq[T], n: T): bool =
  acc.add n
  true

template iseqFinalizer*(n): untyped =
  n

# --------------------------------------

type 
  IStrJoinState = tuple
    sep, acc: string

func iStrJoinDefault*(n1: string): IStrJoinState =
  (n1, "")

func iStrJoinDefault*[T](): IStrJoinState =
  ("", "")

func iStrJoin*(rs: var IStrJoinState, n: string): bool =
  if rs.acc == "":
    rs.acc = n
  else:
    rs.acc &= rs.sep & n

  true

template iStrJoinFinalizer*(n): untyped =
  n.acc

# --------------------------------------

func imaxDefault*[T](): T =
  T.low

func imax*[T](maxSoFar: var T, n: T): bool =
  if n > maxSoFar:
    maxSoFar = n
  true

template imaxFinalizer*(n): untyped =
  n


when false:
  iall
  iany
  imin
  iLinkedList
  iHashSet
