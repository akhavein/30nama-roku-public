sub Main()
    m.checks = 0
    ResetHome()
    ShowHome()
    Assert(m.requests = 1 and m.catalogState = "loading","cold Home requests the catalog before rendering loading state")
    HandleCatalog({success:true,result:{}})
    Assert(m.catalogState = "ready" and m.status.text = "No titles available","successful empty catalog is not permanent loading")
    Assert(Instr(1,m.empty.text,"Account") > 0 and m.nav.focused,"empty state offers a reachable refresh action")
    ShowHome()
    Assert(m.requests = 1,"returning to a known empty catalog does not create a retry loop")
    ResetHome()
    HandleCatalog({success:false,error:"no_response"})
    Assert(m.catalogState = "error" and m.status.text = "Catalog unavailable","first-load failure is distinct from empty success")
    Assert(Instr(1,m.empty.text,"Refresh catalog") > 0,"failed load explains how to retry")
    ShowHome()
    Assert(m.requests = 1 and m.catalogState = "loading","returning Home can retry an uncached failed load")
    HandleCatalog({success:true,result:{hero_section:[{id:42,title:"Recovered"}]}})
    Assert(m.catalogState = "ready" and m.rendered[0].items[0].id = 42,"successful retry replaces the failure with usable titles")
    HandleCatalog({success:false})
    Assert(m.rendered[0].items[0].id = 42 and Instr(1,m.status.text,"saved titles") > 0,"refresh failure retains last-good catalog with an honest status")
    ResetHome()
    m.history = [{id:99,title:"Continue",completed:false}]
    HandleCatalog({success:false})
    Assert(m.rendered[0].label = "Continue Watching" and m.rendered[0].items[0].id = 99,"catalog outage leaves local continue-watching accessible")
    ResetHome()
    m.page = "account"
    m.status.text = "Account status"
    HandleCatalog({success:false})
    Assert(m.catalogState = "error" and m.status.text = "Account status","background catalog failure cannot overwrite another page")
    print "REGRESSION PASS: ";m.checks;" Home state assertions"
end sub
sub ResetHome()
    m.page = "home": m.catalog = []: m.catalogState = "idle": m.history = []
    m.status = {text:""}: m.empty = {text:""}: m.rendered = []: m.requests = 0
    m.nav = {focused:false,setFocus:sub(value)
        m.focused = value
    end sub}
end sub
sub EnterPage(page as String,heading as String)
    m.page = page
    m.status.text = ""
end sub
sub Request(tag as String,action as String,payload as Object)
    m.requests = m.requests + 1
    m.catalogState = "loading"
end sub
sub RenderRails(groups as Object,focus as Boolean)
    m.rendered = groups
end sub
sub ShowEmpty(message as String)
    m.empty.text = message
end sub
sub QueueStoreRendered()
end sub
sub Assert(ok as Boolean,label as String)
    if not ok then print "FAIL: ";label: stop
    m.checks = m.checks + 1
end sub
