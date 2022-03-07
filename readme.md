# iterrr!
iterate faster ... 🏎️.
write higher-order functions, get its imperative style at the compile time!

# TODO 
add table of content
if you know the problem, just jump to usage

## The Problem
declarative programming is good, right? 

instead of 
```nim
var result: seq[int]

for it in list:
  if it mod 2 == 0:
    result.add it * 2
```

you can easily write:
```nim
list.filterIt(it mod 2 == 0).mapIt(it * 2)
```

which is a lot cleaner.

`std/sequtils` already gives us that power. but there is another problem. as you may know, is some functional programming languages like Haskell  the result of these higher-order funcions, are not evaluated until they are needed. [it's called **lazy evaluation**]

In other words, you don't have intermidiate `seq`s.

actually in the above codes, the latter is not equal to the first one. actually it is almost equal to:

```nim
var result1: seq[int]
for it in list:
  if it mod 2 == 0:
    result1.add it

var result2: seq[int]
for it in result1:
  result2.add it * 2

result2 # do whatever you want with the final result
```

another problem with `std/seqtutils` is, that you have to convert your iterable to `seq` before using `filterIt` or `mapIt` or `...`.

I mean:
```nim
(1..20).filterIt(it > 5) # is not working
(1..20).toseq.filterIt(it > 5) # works fine
```
which can be quite expensive (time/resource consuming).

## The Solution
imagine yourself writing almost the same style, while getting the same benefit of imprative style

well, we are not alone, we have macros!

by writing this:
```nim
(1..20) >< ifilter(it > 5).imap(it * 2)
```
you get this:
```nim
var acc = iseqInit[typeof(default(1..20) * 2)]()

block mainLoop:
  for it in (1..20):
    if it > 5:
      block:
        let it = it * 2
        if not iseq(acc, it):
          break mainLoop

iseqFinalizer acc
```

it's as clean is hand-written code, but it's good enough.

## Usage
### syntax
use `><` for normal.
and `>!<` for debug mode.

**here's the pattern**
```nim
iterable >< imap(operation).ifilter(cond).[reducer(args...)]
```
you can chain as many `imap` and `ifilter` as you want. but there is **only one** reducer.

### Main Entities:
1. **imap** :: like `mapIt` from `std/sequtils`
2. **ifilter** :: like `filterIt` from `std/sequtils`
3. **[reducer]**

**NOTE**: the prefix `i` is just a convention.

the default reducer is `iseq` witch stores the result to a sequence.

you can use other reducers, such as:
* `iseq` [the default reducer] :: add results to a `seq`
* `icount` :: count elements
* `imin` :: calculate minimum
* `imax` :: calculate maximum
* `iany` :: like `any` from `std/sequtils`
* `iall` :: like `all` from `std/sequtils`
* `iHashSet` :: add results to a `HashSet`
* `iStrJoin` :: like `join` from `std/strutils`
* **[your custom reducer!]**

here's how you can get maximum x, when `flatPoints` is: `[x0, y0, x1, y1, x2, y2, ...]`
```nim
let xmax = flatPoints.pairs >< ifilter(it[0] mod 2 == 0).imap(it[1]).imax()
```

did you noticed that I've just used `pairs` iterator? isn't that amazing?

### Define A Custom Reducer
**every reducer have**:
1. `iseqInit[T](args...): ...` :: initialize the value of accumulator :: must be generic, can have 0 or more args
2. `iseq(var acc, newValue): bool` :: updates the state value, if returns false, the iteration stops
3. `iseqFinalizer(n): ...` :: returns the result value of accumulator. see `imax` or `imin` implmentaion in `iterrr/reducers.nim`.

you can see details in `iterrr/reducers.nim`

## Inspirations
1. [zero_functional](https://github.com/zero-functional/zero-functional)
2. [itertools](https://github.com/narimiran/itertools)
3. [slicerator](https://github.com/beef331/slicerator)
4. [xflywind's comment on this issue](https://github.com/nim-lang/Nim/issues/18405#issuecomment-888391521)


## Common Questions:
### **iterrr** VS `zero_functional`:
`iterrr` targets the same problem as `zero_functional`, 
while being better at:
  1. extensibility
  2. using less meta programming

### **iterrr** VS `collect` from `std/suger`:
you can use `iterrr` instead of `collect`. 
you don't miss anything.

### Is it a replacement for `itertools`?
not really, you can use them both together.
`itertools` has lots of useful iterators.

## Wanna Contribute?
**here are some suggestion:**

* add benchmark
  1. `iterrr` VS `std/sequtils` VS `zero_functional`
  2. compare to other languages like Rust, Go, Haskell, ...


## With Special Thanks To:
* [@beef331](https://github.com/beef331): who helped me a lot in my Nim journey

## Donate
you can send your donation to my [cryptocurrencies](https://github.com/hamidb80/hamidb80/#cryptocurrencies)