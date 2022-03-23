iterator ritems*[T](o: openArray[T]): lent T =
  for i in countdown(o.high, o.low):
    yield o[i]
