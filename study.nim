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
    (1..10) |> filter(it in 3..5).skip(1).cycle(7).each(number):
      echo number # 3 4 5 3 4 5 3

    var skipState1 = initSkip 7
    skipLoopWrapper:
      
      var cycleState1 = initCycle 7
      cycleLoopWrapper:
      
        for it in 1..10:
          if it in 3..5:
            skipBefore it
            cycleBefore it

            echo it

            skipAfter it
            cycleAfter it

  block flatten: # is not possible
    let mat = [
      [1, 2, 3],
      [4, 5, 6],
      [7, 8, 9]
    ]

    mat.items |> flatten() |> map(it ^ 2).filter(it.sum > 20) |> bulk()/window(10) |> each(row):
      echo row

study "options":
  (1..10) |> filter[n](n > 10).options(skip=3, limit=4)