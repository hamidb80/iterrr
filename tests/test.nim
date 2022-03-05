import std/[macros, unittest]
import iterrr

expandMacros:
  123 >< imap(1).ifilter(2).imax()

# 123 :> imap(1).ifilter(2).imax(3)
