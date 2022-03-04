template study(name, body) = discard

study "single":
  1.reducer: INVALID

study "simple":
  1.imap == imap.reducer:
    Iter :> imap(Op)

    var resultState = iseqDefState[typeof Iter]()

    block mainLoop:
      for it {.inject.} in Iter:
        if not ired(resultState, Op):
          break mainLoop

    resultState

  2.ifilter == ifilter.reducer:
    Iter :> ifilter(Cond)

    var resultState = iseqDefState[typeof Iter]()

    block mainLoop:
      for it {.inject.} in Iter:
        if Cond:
          if not ired(resultState, it = NoOp):
            break mainLoop

    resultState

study "chains":
  1.imap.ifilter [reducer]:
    Iter :> imap(Op).ifilter(Cond)

    var rs: seq[typeof Iter]
    for it in Iter:
      let it = Op
      if Cond:
        rs.add it

  3.imap.ifilter.imap [reducer]:
    Iter :> imap(Op).ifilter(Cond).imap($it)

    var rs: seq[typeof (typeof Iter).default + 2]
    for it in Iter:
      let it = Op
      if Cond:
        rs.add $it

  4.imap.ifilter.imap.ifiter [reducer]:
    discard
