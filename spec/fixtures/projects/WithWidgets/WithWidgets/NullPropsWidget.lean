import ProofWidgets.Component.Panel.Basic

@[widget_module]
def NullPropsWidget : Lean.Widget.Module where
  javascript := "export default function() { return null }"

open Lean Elab Tactic Widget ProofWidgets in
elab stx:"null_props_widget" : tactic => do
  savePanelWidgetInfo (hash NullPropsWidget.javascript : UInt64) (return .null) stx
