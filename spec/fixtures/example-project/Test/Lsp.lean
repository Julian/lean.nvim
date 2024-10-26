/- Delete me once this hopefully gets merged into batteries (or even into the holy land). -/

import Lean

open Lean Server Lsp FileWorker RequestM

/-- Is this the `SyntaxNodeKind` of a tactic syntax? Currently a very crude heuristic. -/
def Lean.SyntaxNodeKind.isTactic (kind : SyntaxNodeKind) : Bool :=
  Name.isPrefixOf `Lean.Parser.Tactic kind

/-- In the given syntax stack, find the first item satisfying the condition `cond`
and run `code` on it. Return `none` if no such item exists.  -/
def Lean.Syntax.Stack.find? (stack : Syntax.Stack) (cond : Lean.Syntax → Bool) {m : Type → Type} [Monad m] {α : Type}
    (code : Lean.Syntax → m (Option α)) : m (Option α) := do
  for (stx, _) in stack do
    if cond stx then
      return ← code stx
  return none

def mkRpcAtMethod {α : Type} [RpcEncodable α] [Inhabited α]
    (cond : Lean.Syntax → Bool) (body : Syntax → (map : FileMap) → Option α) (params : TextDocumentPositionParams) :
    RequestM (RequestTask <| Option α) := do
  let doc ← readDoc
  let text := doc.meta.text
  let hoverPos := text.lspPosToUtf8Pos params.position
  withWaitFindSnap doc (fun s => s.endPos > hoverPos) (notFoundX := pure none) fun snap => do
  let some stack := snap.stx.findStack? (·.getRange?.any (·.contains hoverPos)) | return none
  stack.find? cond fun stx ↦ return body stx text


def mkRpcRangeAtMethod (cond : Lean.Syntax → Bool) :=
    mkRpcAtMethod cond fun stx map ↦ return stx.getRange?.map fun rg ↦ rg.toLspRange map

@[server_rpc_method]
def rpcDeclarationRangeAt := mkRpcRangeAtMethod (·.getKind = `Lean.Parser.Command.declaration)

@[server_rpc_method]
def rpcTacticRangeAt := mkRpcRangeAtMethod (·.getKind.isTactic)

@[server_rpc_method]
def rpcTacticSeqRangeAt := mkRpcRangeAtMethod (·.getKind = `Lean.Parser.Tactic.tacticSeq)


@[server_rpc_method]
def rpcBinderRangeAt :=
  mkRpcAtMethod (·.getKind ∈ [`Lean.Parser.Term.explicitBinder,`Lean.Parser.Term.implicitBinder]) fun stx map ↦ return stx.getRange?.map fun rg ↦ (stx.getKind, rg.toLspRange map)


deriving instance Repr for Lsp.Position
deriving instance Repr for Lsp.Range

@[server_rpc_method]
def syntaxStack  (p : TextDocumentPositionParams ) :
    RequestM (RequestTask <| Option String) := do
  let doc ← readDoc
  let text := doc.meta.text
  let hoverPos := text.lspPosToUtf8Pos p.position
  withWaitFindSnap doc (fun s => s.endPos > hoverPos) (notFoundX := pure "No snapshot found") fun snap => do
  let some stack := snap.stx.findStack? (·.getRange?.any (·.contains hoverPos)) | return "No syntax stack found"
  let mut res := ""
  for (stx, _) in stack do
    let some rg := stx.getRange? | continue
    res := s!"{res}\n\n{stx.getKind}\n{stx}\n{repr <| rg.toLspRange text}"
  return some res
