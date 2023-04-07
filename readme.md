> Once a young man approached the Prophet Muhammad and asked him for some advice. The Prophet replied, “Do not become angry,” and he repeated this three times

# iterrr!
iterate faster ... 🏎️.
Write higher-order functions, get its imperative style at the compile time!

## The Problem
Writing a full nested loop is a boring task, `std/sequtils` creates lots of temporary `seq`s, [iterutils](https://github.com/def-/nim-iterutils) uses closure iterators (which is slow).

## The Solution
`iterrr` uses the *ultimate* power of meta-programming to bring you the speed that Nim programmers deserve.

## example of generated code
```nim
"hello".pairs |> 
  filter((i, _) => i  > 1)
  .map((_, ch) => ch)
  .strjoin() ## llo
```

```nim
block:
  template iterrrFn3(_; ch): untyped {.dirty.} =
    ch

  template iterrrFn4(i; _): untyped {.dirty.} =
    i > 1

  var iterrrAcc2 = strjoinInit[typeof(iterrrFn3(
      default(typeof("hello".pairs))[0], default(typeof("hello".pairs))[1]))]()
  block mainLoop:
    for li1 in "hello".pairs:
      if iterrrFn4(li1[0], li1[1]):
        block:
          let li1 = iterrrFn3(li1[0], li1[1])
          if not strjoinUpdate(iterrrAcc2, li1):
            break mainLoop
  strjoinFinalizer(iterrrAcc2)
```

## Usage

### complete syntax
**There is 3 type of usage:**
```nim
# predefined reducer
iterable |> entity1(_).entity2(_)...Reducer()

# custom reducer
iterable |> entity1(_).entity2(_)...reduce(loopIdents, accIdent = initial_value, [Finalizer]):
  # update accIdent

# custom code
iterable |> entity1(_).entity2(_)...each(...loopIdents):
  # do with loopIdents
```

### Main Entities:
1. **map** :: similar to `mapIt` from `std/sequtils`
2. **filter** :: similar to `filterIt` from `std/sequtils`
3. **breakif** :: similar to `takeWhile` in functional programming languages but negative.
4. **inject** :: injects custom code

#### 1. predefined reducer
**NOTE:** you can chain as many `map`/`filter`/... as you want in any order, but there is **only one** reducer.


**There are some predefined reducers in iterrr library:**
* `toSeq` :: stores elements into a `seq`
* `count` :: counts elements
* `sum` :: calculates summation
* `min` :: calculates minimum
* `max` :: calculates maximum
* `first` :: returns the first item
* `last` :: returns the last item
* `any` :: similar to `any` from `std/sequtils`
* `all` :: similar to `all` from `std/sequtils`
* `toHashSet` :: stores elements into a `HashSet`
* `strJoin` :: similar to `join` from `std/strutils`
* `toCountTable` :: similar to `toCountTable` from `std/tables`

here's how you can get maximum x, when `flatPoints` is: `[x0, y0, x1, y1, x2, y2, ...]`
```nim
let xmax = flatPoints.pairs |> filter(it[0] mod 2 == 0).map(it[1]).max()
# or
let xmax = countup(0, flatPoints.high, 2) |> map(flatPoints[it]).max()
```

**NOTE**: see more examples in `tests/test.nim`

### Custom Idents ?!?
using just `it` in `mapIt` and `filterIt` is just ... and makes code a little unreadable.

#### remember these principles when using custom ident:
1. if there was no custom idents, `it` is assumed
2. if there was only 1 custom ident, the custom ident is replaced with `it`
3. if there was more than 1 custom idents, `it` is unpacked 

**Here's some examples**:  
```nim
(1..10) |> map( _ ) # "it" is available inside the "map"
(1..10) |> map(n => _ )
(1..10) |> map((n) => _ )
(1..10) |> map((a1, a2, ...) => _ )
(1..10) |> reduce((a1, a2, ...), acc = 2)
(1..10) |> each(a1, a2)
```
Custom idents work with both `op:` and `op()` style syntax:
```nim
(1..10).items.iterrr:
  map: n => _
  ...
(1..10).items.iterrr:
  filter: (n, k) => _
  ...
```

**example**:
```nim
"hello".pairs |> filter((i, c) => i > 2).map((_, c) => ord c)
```

### Limitation
you have to specify the iterator for `seq` and other iterable objects [`HSlice` is an exception]

**example:**
```nim
let s = [1, 2, 3]
echo s |> map($it).toseq() # doesn't work
echo s.items |> map($it).toseq() # works fine
echo s.pairs |> map($it).toseq() # works fine
```

### Define Your Reducer!
**every reducer have**: [let't name our custom reducer `zzz`]
1. `zzzInit[T](args...): ...` :: initializes the value of accumulator(state) :: must be *generic*.
2. `zzzUpdate(var acc, newValue): bool` :: updates the accumulator based on `newValue`, if returns false, the iteration stops.
3. `zzzFinalizer(n): ...` :: returns the result of the accumulator.

**NOTE**: see implementations in `src/iterrr/reducers.nim`

### Custom Reducer
**pattern**:
```nim
ITER |> ...reduce(idents, acc = initial_value, [finalizer]): 
   update acc here 
```

**Notes**:
- acc can be any ident like `result` or `answer`, ... 
- **Finalizer**:
  - it's optional
  - it's an experssion inside of it you have access to the `acc` ident
  - the default finalizer is `acc` ident 

**Example of searching for a number**:
```nim
let element = (1..10) |> reduce(it, answer = none int, answer.get):
  if your_condition(it):
    answer = some MyNumber
    break mainLoop
```
**Note**: if the item has not found, raises `UnpackDefect` error as result of `get` function  in finalizer `answer.get`.

### Don't Wanna Use Reducer?
> My view is that a lot of the time in Nim when you're doing filter or map you're just going to operate it on afterwards
:: [@beef331](https://github.com/beef331) AKA beef.

I'm agree with beef. it happens a lot. 
you can do it with `each(arg1, arg2,...)`. [arguments semantic is the same as custom idents]
```nim
(1..10) |> filter(it in 3..5).each(num):
  echo num
  if num < 7:
    break mainLoop
```

**Note**: `mainLoop` is the main loop block

### Custom Adapter
adapters are inspired from implmentation of iterators in Nim.
TODO: explain more

**Limitations**: you have to import the dependencies of adapters in order to use them.

**Built-in adapter**:
- `group`
- `window`
- `cycle`
- `flatten`
- `drop`
- `take`

**Usage**: 
example:

```nim
let matrix = [
  [1, 2, 3],
  [4, 5, 6],
  [7, 8, 9]
]
matrix.items |> flatten().map(-it).cycle(11).group(4).toseq()
```
result:
```nim
@[
  @[-1, -2, -3, -4], 
  @[-5, -6, -7, -8], 
  @[-9, -1, -2] 
]
```

*see `tests`/`test.nim` for more.*

**Define your custom adapter**:
for now the name of loop iterator are limited to `it`.
TODO; 
see `src`/`iterrr`/`adapters`.

## `iterrr` macro
don't like `|>` operator? no problem! use `iterrr` keyword:

pattern:
```nim
iterable.iterator.iterrr:
  filter(...)
  map(...)
  reducer(...)
  reduce(...)/each(...):
    # code ...
```

example:
```nim
let points = @[(1, 2), (-3, 4), (12, 3), (-1, -6), (5, -9)]

points.items.iterrr:
  map (x, y) => x # or map((x, y) => x)
  filter it > 0   # or filter(it > 0)
  each n:         # or each(n):
    echo n
```

## Nesting

Both the `|>` operator and `iterrr` macro can be nested.

Examples:

```nim
matrix.pairs |> map((ia, a) => (
    a.pairs |> map((ib, _) => (ia, ib)).toseq()
  )).toseq()
```

```nim
matrix.pairs.iterrr:
  map: (ia, a) => a.pairs.iterrr:
    map: (ib, _) => (ia, ib)
    toseq()
  toseq()
```

## Debugging
use `-d:iterrrDebug` flag to see generated code.

## Breaking changes
### `0.x` -> `1.x`:
- using brackets for defining custom idents is no longer supported.


## Inspirations
1. [zero_functional](https://github.com/zero-functional/zero-functional)
2. [itertools](https://github.com/narimiran/itertools)
3. [slicerator](https://github.com/beef331/slicerator)
4. [xflywind's comment on this issue](https://github.com/nim-lang/Nim/issues/18405#issuecomment-888391521)
5. [mangle](https://github.com/baabelfish/mangle/)

## Common Questions:
### `iterrr` VS `zero_functional`:
`iterrr` targets the same problem as `zero_functional`, while being better at  *extensibility*.

**Is it fully "zero cost" like `zero_functional` though?**
> well NO, most of it is because of reducer update calls, however the speed difference is soooo tiny and you can't even measure it. I could define all reducer updates as `template` instead of function but IMO it's better to have call stack when you hit errors ...

## Quotes
> writing macro is kind of addicting...
:: [PMunch](https://github.com/PMunch/)
