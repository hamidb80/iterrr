# iterrr!
iterate faster ... 🏎️.
Write higher-order functions, get its imperative style at the compile time!

## The Problem
The problem is that writing a full nested loop is a boring task, and using clojure iterators slows down the speed.

(`std/sequtils` is a nightmare, [iterutils](https://github.com/def-/nim-iterutils) is slightly better, but can we go faster? )

**The real question is:** "Can meta-programming help us?"

## The Solution
`iterrr` uses the *ultimate* power of meta-programming to bring you what you've just wished.

## Usage

### syntax
```nim
iterable |> entity1(_).entity2(_)...Final()
```

### Main Entities:
1. **map** :: similar to `mapIt` from `std/sequtils`
2. **filter** :: similar to `filterIt` from `std/sequtils`
3. **breakif** :: similar to `takeWhile` in functional programming languages but negative.
4. **do** :: does something.

### Final
final can be:
1. predefined reducer
2. custom reducer
3. custom code

#### 1. predefined reducer

**NOTE:** you can chain as many `map`/`filter`/... as you want in any order, but there is **only one** reducer.

you can use other reducers, such as:
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
* **[your custom reducer!]**


here's how you can get maximum x, when `flatPoints` is: `[x0, y0, x1, y1, x2, y2, ...]`
```nim
let xmax = flatPoints.pairs |> filter(it[0] mod 2 == 0).map(it[1]).max()
# or
let xmax = countup(0, flatPoints.high, 2) |> map(flatPoints[it]).max()
```

**NOTE**: see usage in `tests/test.nim`

### Custom Idents ?!?
using just `it` in `mapIt` and `filterIt` is just ... and makes code a little unreadable.

#### remember these principles when using custom ident:
1. if there was no custom idents, `it` is assumed
2. if there was only 1 custom ident, the custom ident is replaced with `it`
3. if there was more than 1 custom idents, `it` is unpacked 

**I mean**:  
```nim
(1..10) |> map( expr ) # "it" is available inside the "map"

## infix style`
(1..10) |> map(n => expr )
(1..10) |> map((n) => expr )
(1..10) |> map((a1, a2, ...) => expr )
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
echo s |> map($it) # doesn't work
echo s.items |> map($it) # works fine
echo s.pairs |> map($it) # works fine
```

### Define A Reducer
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

**example**:
```nim
let sum = (1..10) |> reduce(it, acc = 0):
  acc += it

# with finalizer
let sum_2 = "help".pairs |> reduce((index, ch), acc = -1, acc * 2):
  acc += index

# sum_2 = (-1 + 0 + 1 + 2 + 3) * 2 = 10

```

### Don't Wanna Use Reducer?
> My view is that a lot of the time in Nim when you're doing filter or map you're just going to operate it on afterwards
:: [@beef331](https://github.com/beef331) AKA beef.

I'm agree with beef. it happens a lot. 
you can do it with `each(arg1, arg2,...)`. [arguments semantic is the same as custom idents]
```nim
(1..10) |> filter(it in 3..5).each(num):
  echo num
```

### Custom Adapter
**Note:** adapters are like dirty templates, you have to import the dependencies of adapters in order to use them.

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


## Inspirations
1. [zero_functional](https://github.com/zero-functional/zero-functional)
2. [itertools](https://github.com/narimiran/itertools)
3. [slicerator](https://github.com/beef331/slicerator)
4. [xflywind's comment on this issue](https://github.com/nim-lang/Nim/issues/18405#issuecomment-888391521)
5. [mangle](https://github.com/baabelfish/mangle/)

## Common Questions:
### `iterrr` VS `zero_functional`:
`iterrr` targets the same problem as `zero_functional`, while being better at  *extensibility*.

## Quotes
> writing macro is kind of addicting...
:: [PMunch](https://github.com/PMunch/)
