import std/[macros]
import ../src/iterrr

# impl -----------------------------------

iterator cycle(itrbl: Iter; `limit`: int): Iter {.adapter.} =
  block cycleLoop:
    var `c` = 0
    while true:
      for it in itrbl:
        yield it
        inc `c`
        if `c` == `limit`:
          break cycleLoop

      if `c` == `limit`:
        break cycleLoop

iterator flatten(itrbl: openArray[int]): typeof itrbl {.adapter.} =
  for it in itrbl:
    for it in it:
      yield it


# test -----------------------------------

let matrix = [
  [1, 2, 3],
  [4, 5, 6],
  [7, 8, 9]
]


echo matrix.items !> cycle(5).flatten().toseq()
