when false: # scenarios
  1. imap:
    10..20 >. imap(it + 2)
    # -----------------------

    var rs: seq[typeof 10..20]
    for it {.inject.} in 10..20:
      rs.add it + 2

  
  2. imap.ifilter:
    10..20 >. imap(it + 2).ifilter(it > 5)
    # -----------------------

    var rs: seq[typeof 10..20]
    for it in 10..20:
      let it = it + 2
      if it > 5:
        rs.add it


  2. imap.ifilter.reducer:
    10..20 >- imap(it + 2).ifilter(it > 5).imax()
    # -----------------------

    var acc = initImaxDefaultValue()
    for it in 10..20:
      let it = it + 2
      if it > 5:
        if not imax(it, acc):
          break


          
  4. imap.ifilter.imap:
    10..20 >. imap(it + 2).ifilter(it > 5).imap($it)
    # -----------------------

    var rs: seq[typeof (typeof 10..20).default + 2]
    for it in 10..20:
      let it = it + 2
      if it > 5:
        rs.add $it
