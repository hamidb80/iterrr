import std/[strutils, sequtils]
import std/macros, macroplus
import ./iterrr/[reducers, helper, iterators]

export reducers, iterators

# def ------------------------------------------

type
  HigherOrderCallers = enum
    hoMap, hoFilter, hoBreackIf

  HigherOrderCall = object
    kind: HigherOrderCallers
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

proc getIteratorIdents(call: NimNode): seq[NimNode] =
  if call[CallIdent].kind == nnkBracketExpr:
    call[CallIdent][BracketExprParams]

  elif call[1].matchInfix "=>":
    let args = call[1][InfixLeftSide]
    call[1] = call[1][InfixRightSide]

    case args.kind:
    of nnkIdent: @[args]
    of nnkPar: @[args[0]]
    of nnkTupleConstr:
      args.children.toseq
    else:
      raise newException(ValueError, "invalid custom ident style")

  else:
    @[]

proc buildBracketExprOf(id: NimNode, len: int): seq[NimNode] =
  for i in (0..<len):
    result.add newTree(nnkBracketExpr, id, newIntLitNode i)

func replacedIteratorIdents(expr: NimNode, aliases: seq[NimNode]): NimNode =
  case aliases.len:
  of 0: expr
  of 1: expr.replacedIdent(aliases[0], ident "it")
  else:
    expr.replacedIdents(aliases, buildBracketExprOf(ident"it", aliases.len))

proc toIterrrPack(calls: seq[NimNode]): IterrrPack =
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
    of "breakif": addToCallChain hoBreackIf

    elif i == calls.high: # reducer
      hasReducer = true
      result.reducer = ReducerCall(
        caller: ident caller,

        idents: if n[CallIdent].kind == nnkBracketExpr:
            n[CallIdent][BracketExprParams]
          else:
            @[],

        params: n[CallArgs])

    else:
      err "finalizer can only be last call: " & caller

  if not hasReducer:
    result.reducer = ReducerCall(caller: ident "iseq")

proc detectType(iterIsh: NimNode, mapsParam: seq[NimNode]): NimNode =
  var target = inlineQuote default(typeof(`iterIsh`))

  for operation in mapsParam:
    target = replacedIdent(operation, ident "it", target)

  inlineQuote typeof(`target`)

proc resolveIteratorAliases(ipack: var IterrrPack) =
  for c in ipack.callChain.mitems:
    c.param = c.param.replacedIteratorIdents(c.iteratorIdentAliases)

proc inspect(s: seq[NimNode]): seq[NimNode] {.used.} =
  ## debugging purposes
  for n in s:
    echo treeRepr n

  s

proc iterrrImpl(iterIsh: NimNode, calls: seq[NimNode],
    code: NimNode = nil): NimNode =

  # var ipack = toIterrrPack inspect calls
  var ipack = toIterrrPack calls
  resolveIteratorAliases ipack

  let
    hasCustomCode = code != nil
    noAcc = hasCustomCode and ipack.reducer.caller.strval == "each"
    hasInplaceReducer = ipack.reducer.caller.strVal == "reduce"

    accIdent = ident "acc"
    itIdent = ident "it"
    mainLoopIdent = ident "mainLoop"
    reducerStateUpdaterProcIdent = ipack.reducer.caller
    reducerFinalizerProcIdent = ident ipack.reducer.caller.strVal & "Finalizer"
    reducerInitProcIdent = ident ipack.reducer.caller.strval & "Init"

    accDef =
      if noAcc: newEmptyNode()

      elif hasInplaceReducer:
        let initialValue = ipack.reducer.params[0]
        quote:
          var `accIdent` = `initialValue`

      else:
        let 
          dtype = detectType iterIsh:
            ipack.callChain.filterIt(it.kind == hoMap).mapIt(it.param)

          reducerInitCall = newCall(newTree(nnkBracketExpr, reducerInitProcIdent, dtype)).add:
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


  var loopBody =
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
    let p = call.param

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

      of hoBreackIf:
        quote:
          if `p`:
            break `mainLoopIdent`
          else:
            `loopBody`


  newBlockStmt:
    if noAcc:
      quote:
        for `itIdent` in `iterIsh`:
          `loopBody`

    else:
      quote:
        `accDef`

        block `mainLoopIdent`:
          for `itIdent` in `iterIsh`:
            `loopBody`

        `accFinalizeCall`

proc toVarTuple(n: NimNode): NimNode =
  result = newTree(nnkVarTuple)
  result.add n.toseq
  result.add newEmptyNode()

# main ---------------------------------------

macro `|>`*(iterIsh, body): untyped =
  iterrrImpl iterIsh, flattenNestedDotExprCall body

macro `|>`*(iterIsh, body, code): untyped =
  iterrrImpl iterIsh, flattenNestedDotExprCall body, code


template footer: untyped {.dirty.} =
  echo ". . . . . . . . . . . . . . . . . . . ."
  echo repr result
  echo "---------------------------------------"

macro `!>`*(iterIsh, body): untyped =
  result = iterrrImpl(iterIsh, flattenNestedDotExprCall body)
  echo "## ", repr(iterIsh), " >< ", repr(body)
  footer

macro `!>`*(iterIsh, body, code): untyped =
  result = iterrrImpl(iterIsh, flattenNestedDotExprCall body, code)
  echo "#["
  echo repr(iterIsh), " >< ", repr(body), ":\n", indent(repr code, 4)
  echo "#]"
  footer

template iterrr*(iterIsh, body, code): untyped =
  iterIsh |> body:
    code

macro iterrr*(iterIsh, body): untyped =
  case body.kind:
  of nnkStmtList:
    var calls = body.toseq
    let maybeCode = calls[^1][^1]

    if maybeCode.kind == nnkStmtList:
      calls[^1].del calls[^1].len - 1
      iterrrImpl iterIsh, calls, maybeCode

    else:
      iterrrImpl iterIsh, calls

  of nnkCall:
    iterrrImpl iterIsh, flattenNestedDotExprCall body

  else:
    raise newException(ValueError, "invalid type")

# ---------------------------------------------

macro ifor*(header, body): untyped =
  assert matchInfix(header, "in")
  assert header[InfixSides].allit it.kind == nnkBracket

  result = body
  let idents = header[InfixLeftSide]
  var i = idents.len - 1

  for entity in header[InfixRightSide].rchildren:
    result = 
      case entity.kind:
      of nnkCommand:
        let expr = entity[CommandBody]

        case entity[CommandIdent].strVal:
        of "filter":
          quote:
            if `expr`:
              `result`

        of "breakif":
          quote:
            if `expr`:
              break
            else:
              `result`

        else:
          raise newException(ValueError, "invalid entity")

      of nnkExprEqExpr:
        case entity[0][CommandIdent].strVal:
        of "state":
          let 
            stateVar = entity[0][CommandArgs[0]]
            stateVal = entity[1]

          expectKind stateVar, nnkIdent
          
          quote:
            let `stateVar` = `stateVal`
            `result`

        else:
          raise newException(ValueError, "invalid entity")

      else:
        let
          needUnpack = idents[i].kind == nnkTupleConstr
          iterId =
            if needUnpack:
              toVarTuple idents[i]
            else:
              idents[i]

          blockId =
            if needUnpack:
              ident "block_" & idents[i].toseq.mapit(it.strval).join "_"
            else:
              ident "block_" & iterId.strval

        dec i
        quote:
          block `blockId`:
            for `iterId` in `entity`:
              `result`

  # echo treerepr result
  # echo repr result
