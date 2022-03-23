# iterrr!
iterate faster ... 🏎️.
write higher-order functions, get its imperative style at the compile time!

if you know the problem, just jump to [Usage](#Usage)

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

`std/sequtils` already gives us that power. but there is another problem. it creates intermediate `seq`s. as you may know, in some functional programming languages like Haskell, the result of these higher-order funcions, are not evaluated until they are needed. [it's called **lazy evaluation**]

In other words, there is not intermediate `seq`s.

actually, the latter code is not equal to the first one. actually it is almost equal to:

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
(1..20).filterIt(it > 5) # is doesn't work
(1..20).toseq.filterIt(it > 5) # works fine
```
which can be quite expensive (time/resource consuming) task.

## The Solution
imagine yourself writing almost the same style, while getting the same benefit of imprative style.

well, we are not alone, we have macros!

**by writing this:**
```nim
(1..20) |> filter(it > 5).map(it * 2)
```
**you get this:**
```nim
var acc = iseqInit[typeof(default(typeof(1..20)) * 2)]()

block mainLoop:
  for it in (1..20):
    if it > 5:
      block:
        let it = it * 2
        if not iseq(acc, it):
          break mainLoop

iseqFinalizer acc
```

it's not as clean as hand-written code, but it's good enough.

## Usage
### syntax
use `|>` for normal.
and `!>` for debug mode.

**here's the pattern**
```nim
iterable |> map(operation).filter(cond).[reducer(args...)]
```
you can chain as many `map` and `filter` as you want. but there is **only one** reducer.

### Main Entities:
1. **map** :: similar to `mapIt` from `std/sequtils`
2. **filter** :: similar to `filterIt` from `std/sequtils`
3. **[reducer]**

you can use other reducers, such as:
* `iseq` [the default reducer] :: stores elements into a `seq`
* `count` :: counts elements
* `sum` :: calculates summation
* `min` :: calculates minimum
* `max` :: calculates maximum
* `first` :: returns the first item
* `last` :: returns the last item
* `any` :: similar to `any` from `std/sequtils`
* `all` :: similar to `all` from `std/sequtils`
* `iHashSet` :: stores elements into a `HashSet`
* `strJoin` :: similar to `join` from `std/strutils`
* **[your custom reducer!]**

**NOTE**: see usage in `tests/test.nim`

here's how you can get maximum x, when `flatPoints` is: `[x0, y0, x1, y1, x2, y2, ...]`
```nim
let xmax = flatPoints.pairs |> filter(it[0] mod 2 == 0).map(it[1]).max()
# or
let xmax = countup(0, flatPoints.high, 2) |> map(flatPoints[it]).max()
```

did you noticed that I've just used iterators?

### Custom Idents ?!?
using just `it` in `mapIt` and `filterIt` is just ... and makes code a little unreadable.

#### remember these principles when using custom ident:
1. if there was not custom idents, `it` is assumed
2. if there was only 1 custom ident, the custom ident is replaced with `it`
3. if there was more than 1 custom idents, `it` is unpacked 

**I mean**:  
```nim
(1..10) |> map( _ ) # "it" is available inside the "map"

## bracket style
(1..10) |> map[n]( _ ) # "n" is replaced with "it"
(1..10) |> map[a1, a2, ...]( _ ) # "a1" is replaced with it[0], "a2" is replaced with it[1], ...

## infix style
(1..10) |> map(n => _ )
(1..10) |> map((a1, a2, ...) => _ )
```

**example**:
```nim
"hello".pairs |> filter[indx, c](indx > 2).map[_, c](ord c)
```
Yes, you can do it!


### Limitation
you have to specify the iterator for `seq` and other iterable objects [`HSlice` is an exception]

i mean:
```nim
let s = [1, 2, 3]
echo s |> map($it) # doesn't work
echo s.items |> map($it) # works fine
echo s.pairs |> map($it) # works fine
```

### Define A Custom Reducer
**every reducer have**: [let't name our custom reducer `zzz`]
1. `zzzInit[T](args...): ...` :: initializes the value of accumulator(state) :: must be *generic*, can have 0 or more args.
2. `zzz(var acc, newValue): bool` :: updates the accumulator based on `newValue`, if returns false, the iteration stops.
3. `zzzFinalizer(n): ...` :: returns the result of the accumulator.

**NOTE**: see implementations in `src/iterrr/reducers.nim`

### Inplace Reducer
**pattern**:
```nim
ITER |> ...reduce[acc, a](initialState, [finalizer]):
   acc = ...
```

**example**:
```nim
## default idents, acc & it
let summ = (1..10) |> reduce(0):
  acc += it

## custom idents without finalizer
let summ = (1..10) |> reduce[acc, n](0):
  acc += n

## custom idents + finalizer
let summ2 = (1..10) |> reduce[acc, n](0, acc * 2):
  acc += n
```

### Don't Wanna Use Reducer?
> My view is that a lot of the time in Nim when you're doing filter or map you're just going to operate it on afterwards
:: [@beef331](https://github.com/beef331) AKA beef.

I'm agree with beef. it happens a lot. 
you can do it with `do(arg1, arg2,...)`. [arguments semantic is the same as to custom ident]
```nim
(1..10) |> filter(it in 3..5).each(num):
  echo num
```

### Non Operator Version
you can use `iterrr` template instead of `|>` operator.

**example**:
```nim
check "hello".items.iterrr filter(it != 'l').count()
# or
check iterrr("hello".items, filter(it != 'l').count()
```

## do nested with `ifor`
there is also a DSL to do nested for loops. 
for now see `tests/test.nim`.

## Inspirations
1. [zero_functional](https://github.com/zero-functional/zero-functional)
2. [itertools](https://github.com/narimiran/itertools)
3. [slicerator](https://github.com/beef331/slicerator)
4. [xflywind's comment on this issue](https://github.com/nim-lang/Nim/issues/18405#issuecomment-888391521)

## Common Questions:
### `iterrr` VS `zero_functional`:
`iterrr` targets the same problem as `zero_functional`, 
while being better at:
  1. extensibility
  2. using less meta programming

and it also has smaller core.

### `iterrr` VS `collect` from `std/suger`:
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
you can send your donation to my [crypo wallets](https://github.com/hamidb80/hamidb80/#cryptocurrencies)

## Foot Notes
> writing a macro is kind of addicting...
:: [PMunch](https://github.com/PMunch/)

## Change Logs
### `0.2.x` -> `0.3.0`
* rename `do` to `each`
* add `first` and `last` reducers
* add `ifor` DSL

### `0.2.0` -> `0.2.1`
* add infix style fo custom idents inside `map` and `filter`

### `0.1.x` -> `0.2.0`
* remove prefix `i` wherever possible

### `0.0.x` -> `0.1.0`
- operator `><` and `>!<` replaced with `|>` and `!>`
- non-operator version added
