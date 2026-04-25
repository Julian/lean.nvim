import ProofWidgets.Component.Panel.Basic
import ProofWidgets.Component.OfRpcMethod

open Lean Server ProofWidgets Jsx

/-- A minimal mk_rpc_widget% widget for testing the generic ofRpcMethod handler. -/
@[server_rpc_method]
def GenericRpcWidget.rpc (props : PanelWidgetProps) :
    RequestM (RequestTask Html) :=
  RequestM.asTask do
    let selected := props.selectedLocations
    if selected.isEmpty then
      return <span>No selection.</span>
    return <div>
      <details «open»={true}>
        <summary>Generic RPC Widget</summary>
        <span>Selected {.text (toString selected.size)} location(s).</span>
      </details>
    </div>

@[widget_module]
def GenericRpcWidget : Component PanelWidgetProps :=
  mk_rpc_widget% GenericRpcWidget.rpc
