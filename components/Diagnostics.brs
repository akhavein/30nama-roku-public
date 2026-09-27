sub ShowDiagnostics()
    EnterPage("diagnostics","Connection checks")
    m.helperStatus = "Checking..."
    RenderDiagnostics()
    Request("helper-health","health",{})
    Request("catalog","mainV2",{})
end sub

sub RenderDiagnostics()
    if m.page <> "diagnostics" then return
    auth = "Sign in to enable playback"
    if m.api.token <> "" then auth = "Signed in · verify or change account"
    catalog = "Catalog unavailable · retry"
    for each group in m.catalog
        if group.items.Count() > 0 then catalog = "Catalog ready · refresh"
    end for
    m.list.content = MakeLabels([catalog,Text(m.syncStatus,"Local progress ready") + " · refresh", "Subtitles: " + Text(m.helperStatus,"Not checked") + " · retry",auth,"Back to Account"])
    m.list.visible = true
    m.list.setFocus(true)
    m.status.text = "Playback works independently of the subtitle and progress helper"
end sub
