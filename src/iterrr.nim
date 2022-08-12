import std/[strutils, sequtils, tables]
import std/macros, macroplus
import ./iterrr/[reducers, helper, iterators, adapters]

export reducers, iterators, adapters

# FIXME correct param & args names
# TODO add debugging for adapter and debug flag
# TODO use templates for custom reducer too

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

  if call[1].matchInfix "=>": # TODO turn it to function
    let args = call[1][InfixLeftSide]
    call[1] = call[1][InfixRightSide]

    case args.kind:
    of nnkIdent: @[args]
    of nnkPar: @[args[0]]
    of nnkTupleConstr: args.children.toseq
    else:
      debugEcho treeRepr args
      err "invalid custom ident style. got: " & $args.kind

  else: @[]

func genBracketExprOf(id: NimNode, len: int): seq[NimNode] =
  ## (`it`, 2) => [`it`[0], `it`[1], `it`[2]]
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

    let
      nc = n[CallIdent]
      caller = nc.strVal

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
        idents: @[])

    else:
      result.callChain.add HigherOrderCall(
        kind: hoCustom,
        name: ident caller,
        params: n[CallArgs])

  assert hasReducer, "must set reducer"

func detectTypeImpl(itrbl, iterIdent: NimNode,
  ttrfs: seq[TypeTransformer]): NimNode =

  var cursor = inlineQuote default(typeof(`itrbl`))

  for t in ttrfs:
    cursor =
      case t.kind:
      of hoMap:
        replacedIdent(t.expr, iterIdent, cursor)

      of hoCustom:
        newCall ident"default":
          newCall(t.name &. "Type", cursor).add t.params

      else: err "impossible"

  inlineQuote typeof(`cursor`)

func detectType(itrbl, iterIdent: NimNode,
  callChain: seq[HigherOrderCall]): NimNode =

  detectTypeImpl itrbl, iterIdent:
    var temp: seq[TypeTransformer]
    for c in callChain:
      case c.kind:
      of hoMap:
        temp.add TypeTransformer(kind: hoMap,
            expr: c.expr.replacedIteratorIdents(c.iteratorIdentAliases, iterIdent))

      of hoCustom:
        temp.add TypeTransformer(kind: hoCustom, name: c.name, params: c.params)

      else: discard

    temp

proc resolveUniqIdents(node: NimNode, by: string) =
  ## appends `by` to every nnkAccQuote node recursively
  for i, n in node:
    if n.kind == nnkAccQuoted:
      node[i] = n &. by
    else:
      resolveUniqIdents n, by

func finalizerIdent(n: NimNode): NimNode = n &. "Finalizer"
func initIdent(n: NimNode): NimNode = n &. "Init"

proc iterrrImpl(itrbl: NimNode, calls: seq[NimNode],
    code: NimNode = nil): NimNode =

  var
    ipack = toIterrrPack calls
    tmplts = newStmtList()

  let
    mainLoopIdent = ident "mainLoop"
    accIdent = ident "acc"
    uniqLoopIdent = ident "li" & genUniqId()
    reducerFnIdent = ipack.reducer.caller

    hasCustomCode = code != nil
    noAcc = hasCustomCode and ipack.reducer.caller ~= "each"
    hasCustomReducer = ipack.reducer.caller ~= "reduce"

    accFinalizeCall =                     # TODO turn it to function
      if hasCustomReducer:
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
        newCall(reducerFnIdent.finalizerIdent, accIdent)

  var
    wrappers: seq[tuple[code: NimNode, dtype: NimNode, params: seq[NimNode],
        info: AdapterInfo]]

    loopBody =
      if noAcc:
        code.replacedIteratorIdents(ipack.reducer.params, uniqLoopIdent)

      elif hasCustomReducer:
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
          if not `reducerFnIdent`(`accIdent`, `uniqLoopIdent`):
            break `mainLoopIdent`

  for i, call in ipack.callChain.mrpairs:
    let p =
      case call.kind:
      of hoCustom: newEmptyNode()
      else:
        let
          p = call.expr
          tname = ident "iterrFn" & genUniqId()
          args = (call.iteratorIdentAliases or @[ident "it"]).mapIt:
            newIdentDefs(it, ident "untyped")

        ## TODO turn it to function
        let ps = newNimNode(nnkPragma).add ident "dirty"
        tmplts.add newProc(tname, @[ident "untyped"] & args, p, nnkTemplateDef, ps)

        call.expr = newCall(tname).add:
          case args.len:
          of 1: @[uniqLoopIdent]
          else: genBracketExprOf(uniqLoopIdent, args.len)

        call.expr

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

            if yval ~= "it": loopBody
            else:
              quote:
                block:
                  let `uniqLoopIdent` = `yval`
                  `loopBody`

        wrappers.add:
          let dtype = # speed optimzation for adptrs who don't use generic type. like `cycle` and `flatten`
            if adptr.iterTypePaths.len == 0:
              newEmptyNode()
            else:
              detectType(itrbl, uniqLoopIdent, ipack.callChain[0..i-1])

          (code, dtype, call.params, adptr)

        code.getNode(adptr.loopPath)[ForBody]


  let accDef =
    if noAcc: newEmptyNode()

    elif hasCustomReducer:
      let initialValue = ipack.reducer.params[0]
      quote:
        var `accIdent` = `initialValue`

    else:
      let
        dtype = detectType(itrbl, uniqLoopIdent, ipack.callChain)
        reducerInitCall =
          newTree(nnkBracketExpr, reducerFnIdent.initIdent, dtype).newCall.add:
          ipack.reducer.params

      quote:
        var `accIdent` = `reducerInitCall`


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
      `tmplts`
      `accDef`

      block `mainLoopIdent`:
        `result`

      `accFinalizeCall`

# main ---------------------------------------

macro `|>`*(itrbl, body): untyped =
  iterrrImpl itrbl, flattenNestedDotExprCall body

macro `|>`*(itrbl, body, code): untyped =
  iterrrImpl itrbl, flattenNestedDotExprCall body, code

## TODO add -d:iterrrDebug for debug log

# template footer: untyped {.dirty.} =
#   echo ". . . . . . . . . . . . . . . . . . . ."
#   echo repr result
#   echo "---------------------------------------"

# macro `!>`*(itrbl, body): untyped =
#   result = iterrrImpl(itrbl, flattenNestedDotExprCall body)
#   echo "## ", repr(itrbl), " !> ", repr(body)
#   footer

# macro `!>`*(itrbl, body, code): untyped =
#   result = iterrrImpl(itrbl, flattenNestedDotExprCall body, code)
#   echo "#["
#   echo repr(itrbl), " !> ", repr(body), ":\n", indent(repr code, 4)
#   echo "#]"
#   footer
