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


study "transformer":
  block cycle:
    (1..10) |> filter(it in 3..5).cycle(7).each(number):
      echo number
      # 3 4 5 3 4 5 3

  block flatten:
    let mat = [
      [1, 2, 3],
      [4, 5, 6],
      [7, 8, 9]
    ]

    mat.items |> flatten().map(it ^ 2).group(3).filter(it.sum > 20).each(row):
      echo row

  block memory:
    [1, 4, 5, 8, 11].items |> between().each(n):
      echo n # 2 3 5 6 7 9 10
    
    for it in _:
      # between(it)

      code