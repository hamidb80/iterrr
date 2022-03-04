
# reducers -----------------------------------------

# it has to be generic
func imaxDefault[T](n: T): string =
  ""

# the return value indicates whether you should continue or not
func imax[T](n: T, acc: var string): bool =
  if n > acc.len:
    acc = $n
