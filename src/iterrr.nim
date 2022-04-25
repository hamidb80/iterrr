import std/[strutils, sequtils, tables, sugar]
import std/macros, macroplus
import ./iterrr/[reducers, helper, iterators]

export reducers, iterators

# def ------------------------------------------

## FIXME correct param & args names

type
  HigherOrderCallers = enum
    hoMap, hoFilter, hoBreakIf, hoCustom

  HigherOrderCall = object
    case kind: HigherOrderCallers
    of hoCustom:
      name: NimNode
      params: seq[NimNode]
    else:
      iteratorIdentAliases: seq[NimNode]
      param: NimNode

  ReducerCall = object
    caller: NimNode
    idents: seq[NimNode]
    params: seq[NimNode]

  IterrrPack = object
    callChain: seq[HigherOrderCall]
    reducer: ReducerCall

  Changer = object
    case kind: HigherOrderCallers:
    of hoCustom:
      params: seq[NimNode]
      name: NimNode
    else:
      expr: NimNode

  AdapterInfo = ref object
    wrapperCode: NimNode
    loopPath: seq[int]
    iterTypePaths, yeildPaths, argsValuePaths, uniqIdentPaths: seq[seq[int]]


# impl -----------------------------------------

func `&.`(id: NimNode, str: string): NimNode =
  case id.kind:
  of nnkIdent: ident id.strVal & str
  of nnkAccQuoted: id[0] &. str
  else: err "what?!+" & " " & treerepr(id) & " ::"

func getIteratorIdents(call: NimNode): seq[NimNode] =
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
      err "invalid custom ident style"

  else:
    @[]

func buildBracketExprOf(id: NimNode, len: int): seq[NimNode] =
  for i in (0..<len):
    result.add newTree(nnkBracketExpr, id, newIntLitNode i)

func replacedIteratorIdents(expr: NimNode, aliases: seq[NimNode]): NimNode =
  case aliases.len:
  of 0: expr
  of 1: expr.replacedIdent(aliases[0], ident "it")
  else:
    expr.replacedIdents(aliases, buildBracketExprOf(ident"it", aliases.len))

func toIterrrPack(calls: seq[NimNode]): IterrrPack =
  var hasReducer = false
  for i, n in calls:
    template addToCallChain(higherOrderKind): untyped =
      result.callChain.add HigherOrderCall(
        kind: higherOrderKind,
        iteratorIdentAliases: getIteratorIdents n,
        param: n[CallArgs[0]])

    let caller = normalize:
      if n[CallIdent].kind == nnkBracketExpr:
        n[CallIdent][BracketExprIdent].strVal
      else:
        n[CallIdent].strVal

    case caller:
    of "map": addToCallChain hoMap
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

func detectTypeImpl(itrbl: NimNode, mapsParam: seq[Changer]): NimNode =
  var target = inlineQuote default(typeof(`itrbl`))

  for ch in mapsParam:
    case ch.kind:
    of hoMap:
      target = replacedIdent(ch.expr, ident "it", target)
    of hoCustom:
      target = newCall(ch.name &. "Type", target).add ch.params
    else:
      err "impossible"

  inlineQuote typeof(`target`)

func detectType(itrbl: NimNode, callChain: seq[HigherOrderCall]): NimNode =
  detectTypeImpl itrbl:
    var temp: seq[Changer]
    for c in callChain:
      case c.kind:
      of hoMap:
        temp.add Changer(kind: hoMap, expr: c.param)
      of hoCustom:
        temp.add Changer(kind: hoCustom, name: c.name, params: c.params)
      else: err "imp"

    temp


func resolveIteratorAliases(ipack: var IterrrPack) =
  for c in ipack.callChain.mitems:
    if c.kind != hoCustom:
      c.param = c.param.replacedIteratorIdents(c.iteratorIdentAliases)

proc inspect(s: seq[NimNode]): seq[NimNode] {.used.} =
  ## debugging purposes
  for n in s:
    echo treeRepr n
  s


func getNode(node: NimNode, path: seq[int]): NimNode =
  result = node
  for i in path:
    result = result[i]

proc replaceNode(node: NimNode, path: seq[int], by: NimNode) =
  var cur = node

  for i in path[0 ..< ^1]:
    cur = cur[i]

  cur[path[^1]] = by


func findPathsImpl(node: NimNode, fn: proc(node: NimNode): bool,
  path: seq[int], result: var seq[seq[int]]) =

  if fn node:
    result.add path

  else:
    for i, n in node:
      findPathsImpl n, fn, path & @[i], result

func findPaths(node: NimNode, fn: proc(node: NimNode): bool): seq[seq[int]] =
  findPathsImpl node, fn, @[], result


var customAdapters {.compileTime.}: Table[string, AdapterInfo]

macro adapter*(iterDef): untyped =
  expectKind iterDef, nnkIteratorDef

  let
    args = iterdef.RoutineArguments
    itrblId = args[0]

  var
    adptr = AdapterInfo()
    body = iterDef[RoutineBody]
    argsDef = newTree nnkLetSection

  for i, a in args[1..^1]: # FIXME refactor
    argsDef.add newIdentDefs(a[IdentDefName], a[IdentDefType], newNilLit())
    adptr.argsValuePaths.add @[0, i, 2]

  body.insert 0, argsDef

  adptr.wrapperCode = body
  adptr.uniqIdentPaths = findPaths(body, (n) => n.kind == nnkAccQuoted)
  adptr.yeildPaths = findPaths(body, (n) => n.kind == nnkYieldStmt)
  adptr.iterTypePaths = findPaths(body, (n) => n.eqIdent itrblId[IdentDefType])
  adptr.loopPath = block:
    let temp = findPaths(body,
      (n) => n.kind == nnkForStmt and eqIdent(n[ForRange], itrblId[IdentDefName]))

    assert temp.len == 1, "there must be only one main loop"
    temp[0]


  customAdapters[iterdef[RoutineName].strVal] = adptr
  echo repr adptr

  result = newProc(
    iterDef[RoutineName] &. "Type",
    @[ident"untyped"] & args,
    iterDef.RoutineReturnType,
    nnkTemplateDef)

  result[RoutineGenericParams] = newTree(nnkGenericParams, 
    newIdentDefs(itrblId[IdentDefType], newEmptyNode()))

  debugEcho repr result

proc iterrrImpl(itrbl: NimNode, calls: seq[NimNode],
    code: NimNode = nil): NimNode =

  # var ipack = toIterrrPack inspect calls
  var ipack = toIterrrPack calls
  resolveIteratorAliases ipack

  let
    hasCustomCode = code != nil
    noAcc = hasCustomCode and eqident(ipack.reducer.caller, "each")
    hasInplaceReducer = eqident(ipack.reducer.caller, "reduce")

    accIdent = ident "acc"
    itIdent = ident "it"
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
          dtype = detectType(itrbl, ipack.callChain)
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
    wrappers: seq[tuple[code: NimNode, dtype: NimNode, params: seq[NimNode], info: AdapterInfo]]
    loopBody =
      if noAcc:
        code.replacedIteratorIdents(ipack.reducer.params)

      elif hasInplaceReducer:
        if ipack.reducer.idents.len == 2:
          case ipack.reducer.idents[1].kind:
          of nnkIdent:
            code.replacedIdents(ipack.reducer.idents, [accIdent, itIdent])
          of nnkTupleConstr:
            let
              customIdents = ipack.reducer.idents[1].toseq
              repls = buildBracketExprOf(ident "it", customIdents.len)
            code.replacedIdents(ipack.reducer.idents[0] & customIdents, @[
                accIdent] & repls)
          else:
            err "invalid inplace reducer custom ident type" # TODO easier error
        else:
          code

      else:
        quote:
          if not `reducerStateUpdaterProcIdent`(`accIdent`, `itIdent`):
            break `mainLoopIdent`


  for i, call in ipack.callChain.rpairs:
    let p =
      if call.kind == hoCustom: newEmptyNode()
      else: call.param

    loopBody = block:
      case call.kind:
      of hoMap:
        quote:
          block:
            let `itIdent` = `p`
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

      of hoCustom:
        let adptr = customAdapters[call.name.strval]
        var code = copy adptr.wrapperCode

        for up in adptr.uniqIdentPaths:
          code.replaceNode up, code.getnode(up) &. $i

        for yp in adptr.yeildPaths:
          code.replaceNode yp:
            let yval = code.getNode(yp)[0]

            if eqIdent(yval, ident"it"):
              loopBody
            else:
              quote:
                block:
                  let `itIdent` = `yval`
                  `loopBody`

        wrappers.add (code, itrbl.detectType(ipack.callChain[0..i-1]), call.params, adptr)
        code.getNode(adptr.loopPath)[ForBody]


  result = quote:
    for `itIdent` in `itrbl`:
      `loopBody`

  for w in wrappers.ritems:
    result = block:
      w.code.replaceNode w.info.loopPath, result

      for p in w.info.iterTypePaths:
        w.code.replaceNode p, w.dtype

      for i, p in w.params:
        w.code.replaceNode w.info.argsValuePaths[i], p

      debugEcho repr code

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
    err "invalid type"
