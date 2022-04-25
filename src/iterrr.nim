import std/[strutils, sequtils, tables, sugar]
import std/macros, macroplus
import ./iterrr/[reducers, helper, iterators]

export reducers, iterators

# def ------------------------------------------

type
  HigherOrderCallers = enum
    hoMap, hoFilter, hoBreakIf, hoCustom

  HigherOrderCall = object
    case kind: HigherOrderCallers
    of hoCustom:
      name: string
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

# impl -----------------------------------------

func `&.`(id: NimNode, str: string): NimNode =
  expectKind id, nnkIdent
  ident id.strVal & str

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
      raise newException(ValueError, "invalid custom ident style")

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
        name: caller,
        params: n[CallArgs])

  assert hasReducer, "must set reducer"

func detectType(itrbl: NimNode, mapsParam: seq[NimNode]): NimNode =
  var target = inlineQuote default(typeof(`itrbl`))

  for operation in mapsParam:
    target = replacedIdent(operation, ident "it", target)

  inlineQuote typeof(`target`)

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


type
  AdapterInfo = ref object
    wrapperCode: NimNode
    args: seq[NimNode] ## TODO
    loopPath: seq[int]
    yeildPaths: seq[seq[int]]

var customAdapters {.compileTime.}: Table[string, AdapterInfo]

## FIXME correct param & args names

macro adapter*(iterDef): untyped =
  expectKind iterDef, nnkIteratorDef
  let args = iterdef.RoutineArguments
  assert args.len >= 1

  let
    itrblId = args[0][IdentDefName]
    ypaths = findPaths(iterDef[RoutineBody], (n: NimNode) => n.kind == nnkYieldStmt)
    mainloopPaths = findPaths(iterDef[RoutineBody],
      (n: NimNode) => n.kind == nnkForStmt and eqIdent(n[ForRange], itrblId))

  assert mainloopPaths.len == 1, "there must be only one main loop"

  let adptr = AdapterInfo(
    wrapperCode: iterDef[RoutineBody],
    loopPath: mainloopPaths[0],
    yeildPaths: ypaths)

  customAdapters[iterdef[RoutineName].strVal] = adptr
  echo repr adptr


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
          dtype = detectType itrbl:
            ipack.callChain.filterIt(it.kind == hoMap).mapIt(it.param)
            # ipack.callChain.filterIt(it.kind in {hoMap, hoCustom}).mapIt:
              # case it.kind:
              # of hoMap: it.param
              # of hoCustom: it.name & "AdapterType"
              # else: err "cannot happen"

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
      else:
        newCall(reducerFinalizerProcIdent, accIdent)

  var
    wrappers: seq[tuple[code: NimNode, args: seq[NimNode], path: seq[int]]]
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
            raise newException(ValueError,
                "invalid inplace reducer custom ident type") # TODO easier error
        else:
          code

      else:
        quote:
          if not `reducerStateUpdaterProcIdent`(`accIdent`, `itIdent`):
            break `mainLoopIdent`


  for call in ipack.callChain.ritems:
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
        try:
          let adptr = customAdapters[call.name]
          var code = copy adptr.wrapperCode

          for yp in adptr.yeildPaths:
            code.replaceNode yp:
              let yval = code.getNode(yp)[0]
              quote:
                block:
                  let `itIdent` = `yval`
                  `loopBody`

          wrappers.add (code, @[], adptr.loopPath)
          code.getNode(adptr.loopPath)[ForBody]

        except:
          raise newException(ValueError, "not defined")


  result = quote:
    block `mainLoopIdent`:
      for `itIdent` in `itrbl`:
        `loopBody`

  for w in wrappers:
    result = block:
      w.code.replaceNode(w.path, result)
      w.code

  result = quote:
    block:
      `accDef`
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
  echo "## ", repr(itrbl), " >< ", repr(body)
  footer

macro `!>`*(itrbl, body, code): untyped =
  result = iterrrImpl(itrbl, flattenNestedDotExprCall body, code)
  echo "#["
  echo repr(itrbl), " >< ", repr(body), ":\n", indent(repr code, 4)
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
    raise newException(ValueError, "invalid type")
