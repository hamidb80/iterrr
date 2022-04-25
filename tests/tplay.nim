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

# dumptree:
when false:
  ## identifiers in back-tick are uniq
  macro cycle(itrbl: untyped; `limit`: int): untyped =
    let body = quote:
      var `c` = 0
      while true:
        for it in itrbl:
          yield it
          inc `c`

        if `c` == `limit`:
          break

    yieldPaths = [
      @[1, 1, 0]
    ]

    loopsPaths = [
      @[1, 1, 0]
    ]

# test -----------------------------------

let matrix = [
  [1, 2, 3],
  [4, 5, 6],
  [7, 8, 9]
]

echo matrix.items !> cycle(5).iseq()
