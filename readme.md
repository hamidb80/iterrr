# iterrr!
iterate faster ... 🏎️.
write higher-order functions, get its imperative style at the compile time!

## The Problem


## The Solution

## Usage
use `><` for normal.
and `>!<` for debug mode.

## Concepts

### Main Entities:
1. **imap** :: like `mapIt` from `std/sequtils`
2. **ifilter** :: like `filterIt` from `std/sequtils`
3. **[reducer]**

**NOTE**: the prefix `i` is just a convention.

the default reducer is `iseq` with converts the result to a sequence of that type.

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

### Define A Custom Reducer
```nim
## example of custom reducer
```

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
  3. compilation time

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