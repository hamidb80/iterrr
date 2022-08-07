iterator ritems*[T](o: openArray[T]): lent T =
  for i in countdown(o.high, o.low):
    yield o[i]

iterator rpairs*[T](o: openArray[T]): (int, lent T) =
  for i in countdown(o.high, o.low):
    yield (i, o[i])

iterator mritems*[T](o: var openArray[T]): var T =
  for i in countdown(o.high, o.low):
    yield o[i]

iterator mrpairs*[T](o: var openArray[T]): (int, var T) =
  for i in countdown(o.high, o.low):
    yield (i, o[i])
