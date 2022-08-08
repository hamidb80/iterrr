# Change Logs
### `0.4.5` -> `0.5.0`:
- migrate to `template`s

### `0.4.4` -> `0.4.5`:
- add support for nested
  
### `0.4.2` -> `0.4.4`:
- add new adapters:
  - `window`
  - `take`
  - `drop`

### `0.4.1` -> `0.4.2`:
- optimize
- fix nim ident style related bug

### `0.3.8` -> `0.4.1`:
- remove `ifor`
- add custom adapter
- remove default reducer
- replace `i` prefix with `to` for`iseq` & `iHashset` reducers
- add `do`:
  > just does the given task, nothing else
  ```nim
    let even = (1..10) |> map(it+1).do(echo it).toSeq()
  ```

### `0.3.5` -> `0.3.8`
- add `breakif` to `ifor`
- add `state` to `ifor`
- pass generic type to reducer 

### `0.3.0` -> `0.3.5`
- add unpack custom ident for `reduce`
- add multi line support for `iterrr` (non operator version)
- add `breakif`
- optimize `count` reducer
- optimize compile time

### `0.2.x` -> `0.3.0`
- rename `do` to `each`
- add `first` and `last` reducers
- add `ifor` DSL

### `0.2.0` -> `0.2.1`
- add infix style fo custom idents inside `map` and `filter`

### `0.1.x` -> `0.2.0`
- remove prefix `i` wherever possible

### `0.0.x` -> `0.1.0`
- operator `><` and `>!<` replaced with `|>` and `!>`
- non-operator version added
