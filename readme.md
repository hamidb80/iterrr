# iterrr!
iterate faster ... 🏎️

## the problem


## the solution

## concepts

there are only 3 things in `iterrr`:
1. imap
2. ifilter
3. [reducer]

the default reducer is `iseq` with converts the result to a sequence of that type.

you can use other reducers, such as:
* imax
* imin
* iHashSet
* iLinkedList

or you can define your own reducer.
```nim
## example of custom reducer
```

## inspired by
1. [zero_functional](https://github.com/zero-functional/zero-functional)
2. [itertools](https://github.com/narimiran/itertools)

## **iterrr** vs `zero_functional`:
iterrr targets the same problem as `zero_functional`, 
while being better at:
  1. extensibility
  2. using less meta programming

but there are features from `zero_functional` that is not covered yet:
  1. convert to function
  2. convert to iterator

## **iterrr** vs `collect` from `std/suger`:
you can use `iterrr` instead of `collect` macro I guess.

## is it a replacement for `itertools`?
not really, you can use them both together.
`itertools` has lots of useful utilities.

## wanna contribute?
here are some suggestion:

1. add benchmark 
  * `std/sequtils` vs `iterrr` vs `zero_functional`
  * compare to other languages like Rust, Go, Haskell, ...