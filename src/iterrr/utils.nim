import std/macros

# conventions -----------------------

template err*(msg): untyped =
  raise newException(ValueError, msg)

# meta programming ------------------

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

proc flattenNestedDotExprCall*(n: NimNode): seq[NimNode] =
  ## imap(1).ifilter(2).imax()
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

# ---------------------------------

proc dumpReprAndReturn*(n: NimNode): NimNode =
  echo repr n
  n