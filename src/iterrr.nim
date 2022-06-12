import std/[strutils, sequtils, tables]
import std/macros, macroplus
import ./iterrr/[reducers, helper, iterators, adapters]

export reducers, iterators, adapters

# FIXME correct param & args names
# TODO add debugging for adapter and debug flag

# type def ------------------------------------------

type
  HigherOrderCallers = enum
    hoMap, hoFilter, hoBreakIf, hoDo, hoCustom

  HigherOrderCall = object
    case kind: HigherOrderCallers
    of hoCustom:
      name: NimNode
      params: seq[NimNode]
    else:
      iteratorIdentAliases: seq[NimNode]
      expr: NimNode

  ReducerCall = object
    caller: NimNode
    idents: seq[NimNode]
    params: seq[NimNode]

  IterrrPack = object
    callChain: seq[HigherOrderCall]
    reducer: ReducerCall

  TypeTransformer = object
    case kind: HigherOrderCallers:
    of hoCustom:
      params: seq[NimNode]
      name: NimNode
    else:
      expr: NimNode

# impl -----------------------------------------

func getIteratorIdents(call: NimNode): seq[NimNode] =
  ## extracts custom iterator param names:
  ## map(...) => @[]
  ## map(x => ...) => @[x]
  ## map((x) => ...) => @[x]
  ## map((x, y) => ...) => @[x, y]
  ## map[x](...) => @[x]
  ## map[x, y](...) => @[x, y]

  if call[CallIdent].kind == nnkBracketExpr:
    call[CallIdent][BracketExprParams]

  elif call[1].matchInfix "=>":
    let args = call[1][InfixLeftSide]
    call[1] = call[1][InfixRightSide]

    case args.kind:
    of nnkIdent: @[args]
    of nnkPar: @[args[0]]
    of nnkTupleConstr: args.children.toseq
    else:
      err "invalid custom ident style. got: " & $args.kind

  else:
    @[]

func genBracketExprOf(id: NimNode, len: int): seq[NimNode] =
  ## (`it`, 10) => [`it`[0[, `it`[1], `it`[2], ...]
  for i in 0 ..< len:
    result.add newTree(nnkBracketExpr, id, newIntLitNode i)

func replacedIteratorIdents(expr: NimNode,
  aliases: seq[NimNode], by: NimNode): NimNode =

  case aliases.len:
  of 0: expr.replacedIdent(ident "it", by)
  of 1: expr.replacedIdent(aliases[0], by)
  else:
    expr.replacedIdents(aliases, genBracketExprOf(by, aliases.len))

func toIterrrPack(calls: seq[NimNode]): IterrrPack =
  var hasReducer = false
  for i, n in calls:
    template addToCallChain(higherOrderKind): untyped =
      result.callChain.add HigherOrderCall(
        kind: higherOrderKind,
        iteratorIdentAliases: getIteratorIdents n,
        expr: n[CallArgs[0]])

    let caller = nimIdentNormalize:
      if n[CallIdent].kind == nnkBracketExpr:
        n[CallIdent][BracketExprIdent].strVal
      else:
        n[CallIdent].strVal

    case caller:
    of "map": addToCallChain hoMap
    of "do": addToCallChain hoDo
    of "filter": addToCallChain hoFilter
    of "breakif": addToCallChain hoBreakIf

    elif i == calls.high: # reducer
      hasReducer = true

      result.reducer = ReducerCall(
        caller: ident caller,
        params: n[CallArgs],

        idents: if n[CallIdent].kind == nnkBracketExpr:
            n[CallIdent][BracketExprParams]
          else:
            @[])

    else:
      result.callChain.add HigherOrderCall(
        kind: hoCustom,
        name: ident caller,
        params: n[CallArgs])

  assert hasReducer, "must set reducer"

func detectTypeImpl(itrbl, iterIdent: NimNode, ttrfs: seq[TypeTransformer]): NimNode =
  var cursor = inlineQuote default(typeof(`itrbl`))

  for t in ttrfs:
    cursor =
      case t.kind:
      of hoMap:
        replacedIdent(t.expr, iterIdent, cursor)

      of hoCustom:
        newCall ident"default":
          newCall(t.name &. "Type", cursor).add t.params

      else: impossible

  inlineQuote typeof(`cursor`)

func detectType(itrbl, iterIdent: NimNode, callChain: seq[HigherOrderCall]): NimNode =
  detectTypeImpl itrbl, iterIdent:
    var temp: seq[TypeTransformer]
    for c in callChain:
      case c.kind:
      of hoMap:
        temp.add TypeTransformer(kind: hoMap, expr: c.expr)

      of hoCustom:
        temp.add TypeTransformer(kind: hoCustom, name: c.name, params: c.params)

      else: discard

    temp

func resolveIteratorAliases(ipack: var IterrrPack, iterIdent: NimNode) =
  for c in ipack.callChain.mitems:
    if c.kind != hoCustom:
      c.expr = c.expr.replacedIteratorIdents(c.iteratorIdentAliases, iterIdent)

proc resolveUniqIdents(node: NimNode, by: string) =
  ## appends `by` to every nnkAccQuote node recursively
  for i, n in node:
    if n.kind == nnkAccQuoted:
      node[i] = n &. by
    else:
      resolveUniqIdents n, by

proc iterrrImpl(itrbl: NimNode, calls: seq[NimNode],
    code: NimNode = nil): NimNode =

  let uniqLoopIdent = ident "loopIdent_" & genUniqId()

  # var ipack = toIterrrPack inspect calls
  var ipack = toIterrrPack calls
  resolveIteratorAliases ipack, uniqLoopIdent

  let
    hasCustomCode = code != nil
    noAcc = hasCustomCode and eqident(ipack.reducer.caller, "each")
    hasInplaceReducer = eqident(ipack.reducer.caller, "reduce")

    accIdent = ident "acc"
    mainLoopIdent = ident "mainLoop"
    reducerStateUpdaterProcIdent = ipack.reducer.caller
    reducerFinalizerProcIdent = ipack.reducer.caller &. "Finalizer"
    reducerInitProcIdent = ipack.reducer.caller &. "Init"
    accDef =
      if noAcc: newEmptyNode()

      elif hasInplaceReducer:
        let initialValue = ipack.reducer.params[0]
        quote:
          var `accIdent` = `initialValue`

      else:
        let
          dtype = detectType(itrbl, uniqLoopIdent, ipack.callChain)
          reducerInitCall = newTree(nnkBracketExpr, reducerInitProcIdent,
              dtype).newCall.add:
            ipack.reducer.params

        quote:
          var `accIdent` = `reducerInitCall`

    accFinalizeCall =
      if hasInplaceReducer:
        if ipack.reducer.params.len == 2: # has finalizer
          if ipack.reducer.idents.len == 2:
            ipack.reducer.params[1].replacedIdent(ipack.reducer.idents[0], accIdent)
          else:
            ipack.reducer.params[1]
        else:
          accIdent
      elif noAcc:
        newEmptyNode()
      else:
        newCall(reducerFinalizerProcIdent, accIdent)

  var
    wrappers: seq[tuple[code: NimNode, dtype: NimNode, params: seq[NimNode],
        info: AdapterInfo]]

    loopBody =
      if noAcc:
        code.replacedIteratorIdents(ipack.reducer.params, uniqLoopIdent)

      elif hasInplaceReducer:
        if ipack.reducer.idents.len == 2:
          let k = ipack.reducer.idents[1].kind

          case k:
          of nnkIdent:
            code.replacedIdents(ipack.reducer.idents, [accIdent, uniqLoopIdent])

          of nnkTupleConstr:
            let
              customIdents = ipack.reducer.idents[1].toseq
              repls = genBracketExprOf(uniqLoopIdent, customIdents.len)

            code.replacedIdents(
              ipack.reducer.idents[0] & customIdents,
              @[accIdent] & repls)

          else:
            err "invalid inplace reducer custom ident type. got: " & $k
        else:
          code.replacedIdent ident"it", uniqLoopIdent

      else:
        quote:
          if not `reducerStateUpdaterProcIdent`(`accIdent`, `uniqLoopIdent`):
            break `mainLoopIdent`


  for i, call in ipack.callChain.rpairs:
    let p =
      if call.kind == hoCustom: newEmptyNode()
      else: call.expr

    loopBody = block:
      case call.kind:
      of hoMap:
        quote:
          block:
            let `uniqLoopIdent` = `p`
            `loopBody`

      of hoFilter:
        quote:
          if `p`:
            `loopBody`

      of hoBreakIf:
        quote:
          if `p`:
            break `mainLoopIdent`
          else:
            `loopBody`

      of hoDo:
        newStmtList p, loopBody

      of hoCustom:
        let adptr = customAdapters[call.name.strval]
        var code = adptr.wrapperCode.copy.replacedIdent(ident"it", uniqLoopIdent)

        code.resolveUniqIdents $i

        for yp in adptr.yeildPaths:
          code.replaceNode yp:
            let yval = code.getNode(yp)[0]

            if eqIdent(yval, ident"it"):
              loopBody
            else:
              quote:
                block:
                  let `uniqLoopIdent` = `yval`
                  `loopBody`

        wrappers.add:
          let dtype = # speed optimzation for adptr who don't use generic type. like `cycle` and `flatten`
            if adptr.iterTypePaths.len == 0:
              newEmptyNode()
            else:
              detectType(itrbl, uniqLoopIdent, ipack.callChain[0..i-1])

          (code, dtype, call.params, adptr)

        code.getNode(adptr.loopPath)[ForBody]


  result = quote:
    for `uniqLoopIdent` in `itrbl`:
      `loopBody`

  for w in wrappers.ritems:
    result = block:
      w.code.replaceNode w.info.loopPath, result

      for p in w.info.iterTypePaths:
        w.code.replaceNode p, w.dtype

      for i, p in w.params:
        w.code.replaceNode w.info.argsValuePaths[i], p

      w.code

  result = quote:
    block:
      `accDef`
      block `mainLoopIdent`:
        `result`
      `accFinalizeCall`

# main ---------------------------------------

macro `|>`*(itrbl, body): untyped =
  iterrrImpl itrbl, flattenNestedDotExprCall body

macro `|>`*(itrbl, body, code): untyped =
  iterrrImpl itrbl, flattenNestedDotExprCall body, code


template footer: untyped {.dirty.} =
  echo ". . . . . . . . . . . . . . . . . . . ."
  echo repr result
  echo "---------------------------------------"

macro `!>`*(itrbl, body): untyped =
  result = iterrrImpl(itrbl, flattenNestedDotExprCall body)
  echo "## ", repr(itrbl), " !> ", repr(body)
  footer

macro `!>`*(itrbl, body, code): untyped =
  result = iterrrImpl(itrbl, flattenNestedDotExprCall body, code)
  echo "#["
  echo repr(itrbl), " !> ", repr(body), ":\n", indent(repr code, 4)
  echo "#]"
  footer


template iterrr*(itrbl, body, code): untyped =
  itrbl |> body:
    code

macro iterrr*(itrbl, body): untyped =
  case body.kind:
  of nnkStmtList:
    var calls = body.toseq
    let maybeCode = calls[^1][^1]

    if maybeCode.kind == nnkStmtList:
      calls[^1].del calls[^1].len - 1
      iterrrImpl itrbl, calls, maybeCode

    else:
      iterrrImpl itrbl, calls

  of nnkCall:
    iterrrImpl itrbl, flattenNestedDotExprCall body

  else:
    err "invalid type. expected nnkCall or nnkStmtList but got: " & $body.kind
