import std/[macros, sequtils]
import macroplus

# conventions -----------------------

template err*(msg): untyped =
  raise newException(ValueError, msg)

# meta programming ------------------

proc replaceIdent*(root: NimNode, target, by: NimNode): NimNode =
  if eqIdent(root, target):
    by

  else:
    copyNimNode(root).add:
      root.mapIt replaceIdent(it, target, by)


proc flattenNestedDotExprCallImpl(n: NimNode, acc: var seq[NimNode]) =
  expectKind n, nnkCall

  template dotExprJob(innerCall, caller, args): untyped =
    flattenNestedDotExprCallImpl innerCall, acc
    acc.add newCall(caller).add(args)

  case n[CallIdent].kind:
  of nnkIdent:
    acc.add n

  of nnkBracketExpr:
    case n[CallIdent][BracketExprIdent].kind:
    of nnkIdent:
      acc.add n

    of nnkDotExpr:
      dotExprJob(
        n[CallIdent][BracketExprIdent][0],
        n[CallIdent][BracketExprIdent][1],
        n[BracketExprIdent][CallArgs])

    else:
      err "no"

  of nnkDotExpr:
    dotExprJob n[CallIdent][0], n[CallIdent][1], n[CallArgs]

  else:
    err "invalid caller"

proc flattenNestedDotExprCall*(n: NimNode): seq[NimNode] =
  ## imap[T](1).ifilter(2).imax()
  ##
  ## converts to >>>
  ##
  ## Call
  ##   BracketExpr
  ##     Ident "imap"
  ##     Ident "T"
  ##   IntLit 1
  ## Call
  ##   Ident "ifilter"
  ##   IntLit 2
  ## Call
  ##   Ident "imax"

  flattenNestedDotExprCallImpl n, result
