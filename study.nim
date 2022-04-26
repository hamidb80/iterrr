template study(name, body) = discard
template conclusion(_) = discard

conclusion """
  there is/are:
    only one for loop
    many blocks as map
    maybe filters
    one reducer always
"""

study "map.[reducer]":
  Iter >< map(Op).reducer(Default)

  DetectedType: # <- means replace with
    it <- default(typeof Iter)
    it <- Op
    Op2

  var resultState =
    reducerDefault[typeof DetectedType]() |
    reducerDefault(arg1, arg2, .._)

  block mainLoop:
    for it in Iter:
      block: # new block introduces with a map [to localize `it`]
        let it = Op
        if not reducer(resultState, it):
          break mainLoop

study "filter.[reducer]":
  Iter >< filter(Cond).reducer(Default)

  for it in Iter:
    if Cond:
      _

study "adapter":
  template loop(itrbl, code): untyped {.fake.} =
    for it {.inject.} in itrbl:
      code

  # --------------------------------------------------

  iterator cycle(itrbl: Iter; limit: int): Iter {.adapter.} =
    var c = 0
    while true:
      loop itrbl:
        yield it
        inc c

      if c == limit:
        break

  ## we can't have overloads ...
  ## choose `untyped` if you want to
  iterator repeat(itrbl; t: int): Iter {.adapter.} =
    for _ in 1..t:
      loop itrbl


  iterator flatten(itrbl; t: int): Iter {.adapter.} =
    for _ in 1..t:
      loop itrbl:
        for n in it:
          yield n

    # =========================>>>>>>>>>>>>>>>>>>>>>>>

    for _ in 1..t:
      for it in itrbl:
        block:
          let it = it ## skip this and new block if "let it = it
          iseq(lastState, it)


  ## split the adapter to areas [wrapper, reducer]
  ## add typeCheck thingy
