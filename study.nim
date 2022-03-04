template study(name, body) = discard

"""
  there is/are:
    only one 'for loop'
    many blocks as imap
    maybe filters
    one reducer always 
"""

study "single":
  1.reducer: INVALID

study "simple chain":
  1.imap.reducer: # with default value
    Iter :> imap(Op).ired(Default)

    template DerefedType: untyped =
      # <- means replace with
      it <- default(typeof Iter)
      it <- Op
      Op2

    var resultState = Default | iredDefState[typeof DerefedType]()

    block mainLoop:
      for it {.inject.} in Iter:
        block: # new block introduces with a imap [to localize `it`]
          let it = Op
          if not ired(resultState, Op):
            break mainLoop

  2.imap.reducer: # with default value
    Iter :> ifilter(Cond).ired(Default)

    var resultState = _

    for it in Iter:
      if Cond:
        if not ired(resultState, Op):
          break mainLoop

study "complex chain":
  discard
