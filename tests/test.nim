import std/[macros, unittest]
import iterrr


echo 1..20 >< imap(it * it).ifilter(it > 10)

# 123 :> imap(1).ifilter(2).imax(3)
