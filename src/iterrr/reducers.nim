
# reducers -----------------------------------------

# it has to be generic
func iseqDefault*[T](): seq[T] =
  newseq[T]()

# the return value indicates whether you should continue or not
func iseq*[T](acc: var seq[T], n: T): bool =
  acc.add n
  true

# it has to be generic
func imaxDefault*[T](n: T): string =
  ""

# the return value indicates whether you should continue or not
func imax*[T](n: T, acc: var string): bool =
  if n > acc.len:
    acc = $n

when false:
  iall 
  iany
  imin
  iLinkedList
  iHashSet