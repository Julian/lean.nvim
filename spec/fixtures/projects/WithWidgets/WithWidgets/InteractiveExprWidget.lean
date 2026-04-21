import ProofWidgets.Component.Basic
import ProofWidgets.Component.HtmlDisplay

open ProofWidgets Lean Jsx

def quickExpr : Elab.Term.TermElabM Html := do
  let e ← Elab.Term.elabTerm (← ``(1 + 2)) (mkConst ``Nat)
  Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let e ← instantiateMVars e
  return <InteractiveExpr expr={← Server.WithRpcRef.mk (← ExprWithCtx.save e)} />
