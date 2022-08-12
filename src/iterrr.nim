import std/[strutils, sequtils, tables]
import std/macros, macroplus
import ./iterrr/[reducers, helpers, iterators, adapters]

export reducers, iterators, adapters

# FIXME correct param & args names
# TODO add debugging for adapter and debug flag
# TODO use templates for custom reducer too
# TODO add code doc

# type def ------------------------------------------

type
  HigherOrderCallers = enum
    hoMap, hoFilter, hoBreakIf, hoWith, hoCustom

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

func extractIdents(args: NimNode): seq[NimNode] =
  ## x => @[x]
  ## (x) => @[x]
  ## (x, y) => @[x, y]
  case args.kind:
  of nnkIdent: @[args]
  of nnkPar: @[args[0]]
  of nnkTupleConstr: args.children.toseq
  else:
    err "invalid custom ident style. got: " & $args.kind

func iteratorIdents(call: NimNode): seq[NimNode] =
  ## extracts custom iterator param names:
  ## map(...) => @[]
  ## map(x => ...) => @[x]
  ## map((x) => ...) => @[x]
  ## map((x, y) => ...) => @[x, y]

  if call[1].matchInfix "=>":
    extractIdents call[1][InfixLeftSide]
  else:
    @[]

func genBracketExprsOf(id: NimNode, len: int): seq[NimNode] =
  ## (`it`, 2) => [`it`[0], `it`[1], `it`[2]]
  for i in 0 ..< len:
    result.add newTree(nnkBracketExpr, id, newIntLitNode i)

func replacedIteratorIdents(expr: NimNode,
  aliases: seq[NimNode], by: NimNode): NimNode =

  case aliases.len:
  of 0: expr.replacedIdent(ident "it", by)
  of 1: expr.replacedIdent(aliases[0], by)
  else:
    expr.replacedIdents(aliases, genBracketExprsOf(by, aliases.len))

func toIterrrPack(calls: seq[NimNode]): IterrrPack =
  var hasReducer = false

  for i, n in calls:
    template addToCallChain(higherOrderKind): untyped =
      let
        firstParam = n[CallArgs[0]]
        expr =
          if matchInfix(firstParam, "=>"):
            firstParam[InfixRightSide]
          else:
            firstParam

      result.callChain.add HigherOrderCall(
        kind: higherOrderKind,
        iteratorIdentAliases: iteratorIdents n,
        expr: expr)

    let
      nc = n[CallIdent]
      caller = nc.strVal

    case caller:
    of "map": addToCallChain hoMap
    of "with": addToCallChain hoWith
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

  expect hasReducer, "must set reducer"

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
func updaterIdent(n: NimNode): NimNode = n &. "Update"

type AdapterWrapper = tuple
  code: NimNode
  dtype: NimNode
  params: seq[NimNode]
  info: AdapterInfo

func toUntypedIdentDef(id: NimNode): NimNode =
  newIdentDefs(id, ident "untyped")

func newDirtyTemplate(name: NimNode, args: seq[NimNode],
    body: NimNode): NimNode =
  let pragmas = newNimNode(nnkPragma).add ident "dirty"
  newProc(name, @[ident "untyped"] & args, body, nnkTemplateDef, pragmas)

func makeAliasCallWith(
  name: NimNode,
  args: seq[NimNode],
  uniqLoopIdent: NimNode): NimNode = # TODO what a name !

  newCall(name).add:
    case args.len:
    of 1: @[uniqLoopIdent]
    else: genBracketExprsOf(uniqLoopIdent, args.len)


proc iterrrImpl(itrbl: NimNode, calls: seq[NimNode],
    code: NimNode = nil): NimNode =

  var ipack = toIterrrPack calls
  let
    mainLoopIdent = ident "mainLoop"
    uniqLoopIdent = ident "li" & genUniqId()
    reducerIdent = ipack.reducer.caller

    hasCustomCode = reducerIdent ~= "each"
    hasCustomReducer = reducerIdent ~= "reduce"

    accIdent =
      if hasCustomReducer:
        ipack.reducer.params[1][0] # TODO add to macroplus nnkEqExprEq
      else:
        ident "iterrrAcc" & genUniqId()
    
    accDef =
      if hasCustomCode: newEmptyNode()

      elif hasCustomReducer:
        let initialValue = ipack.reducer.params[1][1] # TODO EqExprEq
        quote:
          var `accIdent` = `initialValue`

      else:
        let
          dtype = detectType(itrbl, uniqLoopIdent, ipack.callChain)
          reducerInitCall =
            newTree(nnkBracketExpr, reducerIdent.initIdent, dtype).newCall.add:
            ipack.reducer.params

        quote:
          var `accIdent` = `reducerInitCall`

    accFinalizeCall =
      if hasCustomCode: newEmptyNode()

      elif hasCustomReducer:
        case ipack.reducer.params.len:
        of 3: ipack.reducer.params[2]
        else: accIdent

      else: newCall(reducerIdent.finalizerIdent, accIdent)


  if hasCustomCode or hasCustomReducer:
    expect code != nil, "where's the code?"

  var
    tmplts = newStmtList()
    wrappers: seq[AdapterWrapper]
    loopBody =
      if hasCustomCode:
        let id = ident "iterrrBody" & genUniqId()
        tmplts.add newDirtyTemplate(id, ipack.reducer.params.map toUntypedIdentDef, code)
        makeAliasCallWith id, ipack.reducer.params or @[uniqLoopIdent], uniqLoopIdent

      elif hasCustomReducer:
        let
          id = ident "iterrrBody" & genUniqId()
          args = extractIdents ipack.reducer.params[0]

        tmplts.add newDirtyTemplate(id, args.map toUntypedIdentDef, code)
        makeAliasCallWith id, args, uniqLoopIdent

      else:
        let updaterId = reducerIdent.updaterIdent
        quote:
          if not `updaterId`(`accIdent`, `uniqLoopIdent`):
            break `mainLoopIdent`


  # resolve 
  for i, call in ipack.callChain.mrpairs:
    let p =
      case call.kind:
      of hoCustom: newEmptyNode()
      else:
        let
          body = call.expr
          tname = ident "iterrFn" & genUniqId()
          args = (call.iteratorIdentAliases or @[ident "it"]).map:
            toUntypedIdentDef

        tmplts.add newDirtyTemplate(tname, args, body)
        makeAliasCallWith(tname, args, uniqLoopIdent)

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

      of hoWith:
        newStmtList p, loopBody

      of hoCustom:
        let adptr = customAdapters[call.name.strval.nimIdentNormalize]
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

  when defined iterrrDebug:
    debugEcho "---------------------------"
    debugEcho repr result

# main ---------------------------------------

macro `|>`*(itrbl, body): untyped =
  iterrrImpl itrbl, flattenNestedDotExprCall body

macro `|>`*(itrbl, body, code): untyped =
  iterrrImpl itrbl, flattenNestedDotExprCall body, code
