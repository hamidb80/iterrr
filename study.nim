template study(name, body) = discard
template conclusion(_) = discard

conclusion """
  there is/are:
    only one for loop
    many blocks as imap
    maybe filters
    one reducer always
"""

study "imap.[reducer]": 
  Iter >< imap(Op).reducer(Default)

  DetectedType: # <- means replace with
    it <- default(typeof Iter)
    it <- Op
    Op2

  var resultState = 
    reducerDefault[typeof DetectedType]() |
    reducerDefault(arg1, arg2, .._)

  block mainLoop:
    for it in Iter:
      block: # new block introduces with a imap [to localize `it`]
        let it = Op
        if not reducer(resultState, it):
          break mainLoop


study "ifilter.[reducer]": 
  Iter >< ifilter(Cond).reducer(Default)

  for it in Iter:
    if Cond:
      _
