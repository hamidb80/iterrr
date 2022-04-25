import std/[macros]
import ../src/iterrr

# impl -----------------------------------

iterator cycle(itrbl: T; `limit`: int): itrbl {.adapter.} =
  block cycleLoop:
    var `c` = 0
    while true:
      for it in itrbl:
        yield it
        inc `c`
        if `c` == `limit`:
          break cycleLoop

iterator flatten(itrbl: T): itrbl[0] {.adapter.} =
  for it in itrbl:
    for it in it:
      yield it

iterator group(loop: T; `every`: int): seq[T] {.adapter.} =
  var `gacc` = newseq[T]()
  for it in loop:
    `gacc`.add it
    if `gacc`.len == `every`:
      yield `gacc`
      `gacc` = @[]
  
  

# test -----------------------------------

let matrix = [
  [1, 2, 3],
  [4, 5, 6],
  [7, 8, 9]
]

echo matrix.items !> flatten().cycle(10).group(2).toseq()
echo matrix.items !> flatten().cycle(10).toseq()
# echo matrix.items !> cycle(5).toseq()
# echo matrix.items !> flatten().toseq()
# echo matrix.items !> group(2).toseq()
