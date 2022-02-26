import std/[macros, algorithm]
import macroplus

## we have `map`, `filter` and reducers like max, min, ...

# utils --------------------------------------

proc flattenDeepInfix(n: NimNode, infixStr: string): NimNode =
  var cur = n
  result = newTree(nnkInfix, ident infixStr)


  while cur.kind == nnkInfix and cur[InfixIdent].strVal == infixStr:
    result.insert 1, cur[InfixRightSide]

    if cur[InfixLeftSide].kind == nnkInfix:
      cur = cur[InfixLeftSide]

    else:
      result.insert 1, cur[InfixLeftSide]
      break

proc strip(n: NimNode): NimNode = 
  if n.kind in {nnkPar, nnkStmtList}:
    n[0]
  else:
    n

proc genForLoop(ident, iter, body: NimNode): NimNode =
  discard

proc genIf(cond, body: NimNode): NimNode =
  discard

# impl ---------------------------------------

macro finalize(iter, tree): untyped =
  echo treeRepr tree

  # let parts = flattenDeepInfix(strip n, "-")[1..^1]

  # for entity in parts[1..^1].reversed:
  #   expectKind entity, nnkCall

  #   echo treeRepr entity
    
  #   let routine = entity[CallIdent].strVal
  #   case routine:
  #   of "imap":
  #     discard

  #   of "ifilter":
  #     discard
    
  #   else:
  #     let 
  #       accI = genSym(nskVar, "acc")
  #       genDefaultProcI = ident routine & "Default"

  #     # result.add quote do:
  #     #   var `accI`: typeof `genDefaultProcI`()


template `>.`(iter, n): untyped =
  finalize iter, n


# -----------------------------------------

# TODO what about generrics?
func imaxDefault(): string =
  ""

# the return value indicates whether you should continue or not
func imax[T](n: T, acc: var string): bool =
  if n > acc.len:
    acc = $n

# -----------------------------------------

WWW >.
  ifilter(it > 7).
  imap(it ^ 2).
  imax()


when false:
  "Scenarios":
    1. imap:
      10..20 >. imap(it + 2)
      # -----------------------

      var rs: seq[typeof 10..20]
      for it {.inject.} in 10..20:
        rs.add it + 2

    
    2. imap.ifilter:
      10..20 >. imap(it + 2).ifilter(it > 5)
      # -----------------------

      var rs: seq[typeof 10..20]
      for it in 10..20:
        let it = it + 2
        if it > 5:
          rs.add it


    2. imap.ifilter.reducer:
      10..20 >. imap(it + 2).ifilter(it > 5).imax()
      # -----------------------

      var acc = initImaxDefaultValue()
      for it in 10..20:
        let it = it + 2
        if it > 5:
          if not imax(it, acc):
            break


            
    4. imap.ifilter.imap:
      10..20 >. imap(it + 2).ifilter(it > 5).imap($it)
      # -----------------------

      var rs: seq[typeof (typeof 10..20).default + 2]
      for it in 10..20:
        let it = it + 2
        if it > 5:
          rs.add $it
