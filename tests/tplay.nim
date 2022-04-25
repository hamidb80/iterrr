import std/[macros]
import ../src/iterrr

# impl -----------------------------------

iterator cycle(itrbl: untyped; `limit`: int): itrbl {.adapter.} =
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

iterator flatten(itrbl: openArray[int]): itrbl[0] {.adapter.} =
  for it in itrbl:
    for it in it:
      yield it


iterator group(itrbl: untyped, `every`: int): @[itrbl] {.adapter.} =
  var `gacc` = newseq[typeof itrbl]()
  for it in itrbl:
    `gacc`.add it
    if `gacc`.len == `every`:
      yield `gacc`
      `gacc` = @[]
  
  if `gacc`.len != `every`:
    yield `gacc`


# test -----------------------------------

let matrix = [
  [1, 2, 3],
  [4, 5, 6],
  [7, 8, 9]
]


# echo matrix.items !> cycle(5).flatten().toseq()
# echo matrix.items !> cycle(5).toseq()
# echo matrix.items !> flatten().toseq()
echo matrix.items !> group(2).toseq()
