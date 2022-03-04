import std/[macros, algorithm]
import macroplus

import std/[macros, strutils]
import macroplus

template err(msg): untyped =
  raise newException(ValueError, msg)


proc flattenNestedDotExprCallImpl(n: NimNode, acc: var seq[NimNode]) =
  expectKind n, nnkCall

  case n[0].kind:
  of nnkDotExpr:
    flattenNestedDotExprCallImpl n[0][0], acc

    acc.add:
      case n.len:
      of 1: newCall n[0][1]
      of 2: newCall n[0][1], n[1]
      else: err "only 0 or 1 parameters can finalizer have"

  of nnkIdent:
    acc.add n

  else:
    error "invalid caller"

proc flattenNestedDotExprCall(n: NimNode): seq[NimNode] =
  ## imap(1).ifilter(2).imax()
  ##
  ## Call
  ##   DotExpr
  ##     Call
  ##       DotExpr
  ##         Call
  ##           Ident "imap"
  ##           IntLit 1
  ##         Ident "ifilter"
  ##       IntLit 2
  ##     Ident "imax"
  ##
  ## converts to >>>
  ##
  ## Call
  ##   Ident "imap"
  ##   IntLit 1
  ## Call
  ##   Ident "ifilter"
  ##   IntLit 2
  ## Call
  ##   Ident "imax"

  flattenNestedDotExprCallImpl n, result


proc validityCheck(nodes: seq[NimNode]) =
  for i, n in nodes:
    let caller = n[CallIdent].strVal.normalize
    if not (
        caller in ["imap", "ifilter"] or
        i == nodes.high
      ):
      err "finalizer can only be last call: " & caller

proc iii(body: NimNode): NimNode =
  let rs = flattenNestedDotExprCall body
  validityCheck rs

  # result = genForLoop()
  for n in rs:
    discard

  newEmptyNode()

macro `:>`(D, body) =
  iii body


123 :> imap(1).ifilter(2).imax()
123 :> imap(1).ifilter(2).imax(3)


# -----------------------------------------

# it has to be generic
func imaxDefault[T](n: T): string =
  ""

# the return value indicates whether you should continue or not
func imax[T](n: T, acc: var string): bool =
  if n > acc.len:
    acc = $n

# -----------------------------------------
