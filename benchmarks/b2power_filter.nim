import std/[sugar]
import benchy
import iterutils, iterrr, zero_functional

timeIt "closure iterator":
  var acc = 0

  for i in (1..100_000).
    toIter.
    filter(x => x mod 2 == 0).
    filter(x => x mod 4 == 0).
    filter(x => x mod 8 == 0).
    filter(x => x mod 16 == 0).
    filter(x => x mod 32 == 0).
    filter(x => x mod 64 == 0).
    filter(x => x mod 128 == 0).
    filter(x => x mod 256 == 0).
    filter(x => x mod 512 == 0):

    acc.inc i

timeIt "manual":
  var acc = 0

  for i in 1..100_000:
    if i mod 2 == 0:
      if i mod 4 == 0:
        if i mod 8 == 0:
          if i mod 16 == 0:
            if i mod 32 == 0:
              if i mod 64 == 0:
                if i mod 128 == 0:
                  if i mod 256 == 0:
                    if i mod 512 == 0:
                      acc.inc i

timeIt "iterrr":
  var acc = 0

  (1..100_000) |>
    filter(x => x mod 2 == 0).
    filter(x => x mod 4 == 0).
    filter(x => x mod 8 == 0).
    filter(x => x mod 16 == 0).
    filter(x => x mod 32 == 0).
    filter(x => x mod 64 == 0).
    filter(x => x mod 128 == 0).
    filter(x => x mod 256 == 0).
    filter(x => x mod 512 == 0).
    each(i):

    acc.inc i

timeIt "zero_functional":
  var acc = 0

  (1..100_000) -->
    filter(it mod 2 == 0).
    filter(it mod 4 == 0).
    filter(it mod 8 == 0).
    filter(it mod 16 == 0).
    filter(it mod 32 == 0).
    filter(it mod 64 == 0).
    filter(it mod 128 == 0).
    filter(it mod 256 == 0).
    filter(it mod 512 == 0).
    foreach(acc.inc it)
