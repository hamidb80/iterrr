import std/[macros]
import ../src/iterrr

# test -----------------------------------

let matrix = [
  [1, 2, 3],
  [4, 5, 6],
  [7, 8, 9]
]

# single adapter
echo matrix.items !> cycle(5).toseq()
echo matrix.items !> flatten().toseq()

# chain of adapters
echo matrix.items |> flatten().cycle(10).group(2).toseq()
echo matrix.items !> flatten().cycle(10).toseq()

# :: group 
echo matrix.items !> group(2).toseq()
echo matrix.items !> group(2, true).toseq()
