import ProofWidgets.Component.RefreshComponent
import ProofWidgets.Component.HtmlDisplay

open Lean Server Widget ProofWidgets Jsx

def quickRefresh : CoreM Html := do
  mkRefreshComponentM (.text "loading...") fun token => do
    token.update <| .text "refreshed!"

#html quickRefresh
