import benchy
import iterutils
import iterrr
import sugar
import std/sequtils
import zero_functional

var acc = 0

timeIt "sequtils":
  for i in (1..1_000_000).toseq.
    filterit(it mod 2 == 0).
    filterit(it mod 4 == 0).
    filterit(it mod 8 == 0).
    filterit(it mod 16000 == 0).
    mapit(it div 16):

    acc.inc i

timeIt "iterutils":
  for i in (1..1_000_000).
    filter(x => x mod 2 == 0).
    filter(x => x mod 4 == 0).
    filter(x => x mod 8 == 0).
    filter(x => x mod 16000 == 0).
    map(x => x div 16):

    acc.inc i


timeIt "manual":
  for i in 1..1_000_000:
    if i mod 2 == 0:
      if i mod 4 == 0:
        if i mod 8 == 0:
          if i mod 16000 == 0:
            acc.inc i div 16


timeIt "zero_functional":
  (1..1_000_000) -->
    filter(it mod 2 == 0).
    filter(it mod 4 == 0).
    filter(it mod 8 == 0).
    filter(it mod 16000 == 0).
    map(it div 16).
    foreach(acc += it)


timeIt "iterrr":
  (1..1_000_000) |>
    filter(x => x mod 2 == 0).
    filter(x => x mod 4 == 0).
    filter(x => x mod 8 == 0).
    filter(x => x mod 16000 == 0).
    map(x => x div 16).
    each(i):

    acc.inc i
