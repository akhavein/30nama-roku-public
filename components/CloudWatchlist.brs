' Account Watchlist is distinct from the legacy TV list. No offline toggle queue.
function CloudGlobalTag(tag as String) as Boolean
    return tag = "cloud-check" or tag = "cloud-write" or tag = "cloud-verify"
end function

function CloudWatchLabel(id as Integer) as String
    if m.api.token = "" then return "Sign in for account Watchlist"
    if IsMap(m.cloudMutation) then return "Updating account Watchlist..."
    if not IsMap(m.cloudIds) then return "Check account Watchlist"
    if m.cloudIds.DoesExist(Text(id)) then return "Remove from account Watchlist"
    return "Add to account Watchlist"
end function

sub RefreshCloudMembership()
    if m.api.token = "" or IsMap(m.cloudMutation) then return
    Request("cloud-membership","user_mylist",{})
end sub

sub BeginCloudMutation()
    if m.api.token = "" then ShowAccount(): return
    if IsMap(m.cloudMutation) or not IsMap(m.title) then return
    if m.cloudClickClock <> invalid and m.cloudClickId = m.title.id then
        if m.cloudClickClock.TotalMilliseconds() < 750 then return
    end if
    if not IsMap(m.cloudIds) then
        m.status.text = "Checking your account Watchlist..."
        RefreshCloudMembership()
        return
    end if
    m.cloudClickClock = CreateObject("roTimespan")
    m.cloudClickClock.Mark()
    m.cloudClickId = m.title.id
    m.cloudMutation = {id:m.title.id,wanted:not m.cloudIds.DoesExist(Text(m.title.id)),verifies:0}
    m.status.text = "Checking before saving..."
    RenderTitle()
    Request("cloud-check","user_mylist",{})
end sub

sub FinishCloudMutation(message as String,confirmed as Boolean)
    id = 0
    if IsMap(m.cloudMutation) then id = m.cloudMutation.id
    m.cloudMutation = invalid
    m.cloudVerifyTimer.control = "stop"
    if not confirmed then m.cloudIds = invalid
    if m.page = "title" and IsMap(m.title) then
        RenderTitle()
        if m.title.id = id then m.status.text = message
    end if
    if m.page = "cloud-watchlist" then ShowCloudWatchlist()
end sub

sub OnCloudVerifyTimer()
    if not IsMap(m.cloudMutation) or m.api.token = "" then return
    Request("cloud-verify","user_mylist",{})
end sub

sub HandleCloudResult(tag as String,result as Dynamic,status as Integer)
    if m.api.token = "" then
        m.cloudIds = invalid
        m.cloudMutation = invalid
        if m.page = "cloud-watchlist" then ShowCloudWatchlist()
        if m.page = "title" then RenderTitle()
        return
    end if
    if tag = "cloud-list" then
        page = CloudWatchPage(result)
        if page = invalid then
            RenderCloudWatchlist()
            m.status.text = "Account Watchlist unavailable. * opens Refresh; previous results kept."
            return
        end if
        if m.cloudWantedPage > page.pages and m.cloudWantedPage > 1 then
            ShowCloudWatchlist(page.pages)
            return
        end if
        if page.page <> m.cloudWantedPage then
            RenderCloudWatchlist()
            m.status.text = "Account page changed. Press * then Refresh."
            return
        end if
        m.cloudPage = page.page: m.cloudPages = page.pages: m.cloudItems = page.items
        RenderCloudWatchlist()
        return
    end if
    if tag = "cloud-write" then
        ' A timeout or 5xx may hide a committed toggle. NEVER replay this write.
        if IsMap(m.cloudMutation) then Request("cloud-verify","user_mylist",{})
        return
    end if
    ids = CloudWatchIds(result)
    if tag = "cloud-membership" then
        if IsMap(m.cloudMutation) then return
        m.cloudIds = ids
        if m.page = "title" then
            RenderTitle()
            if ids = invalid then
                m.status.text = "Account Watchlist unavailable; the TV list still works."
            else if m.status.text = "Checking your account Watchlist..." then
                m.status.text = "Account Watchlist checked. Choose Add or Remove."
            end if
        end if
        return
    end if
    if not IsMap(m.cloudMutation) then return
    intent = m.cloudMutation
    if tag = "cloud-check" then
        if ids = invalid then FinishCloudMutation("Could not check account Watchlist. No change sent.",false): return
        m.cloudIds = ids
        if ids.DoesExist(Text(intent.id)) = intent.wanted then
            FinishCloudMutation("Account Watchlist is already up to date.",true)
        else
            Request("cloud-write","add_to_mylist/id/" + Text(intent.id) + "/group/watchlist",{})
        end if
    else if tag = "cloud-verify" then
        if ids <> invalid then
            if ids.DoesExist(Text(intent.id)) = intent.wanted then
                m.cloudIds = ids
                FinishCloudMutation("Account Watchlist saved and verified.",true)
                return
            end if
        end if
        m.cloudMutation.verifies = m.cloudMutation.verifies + 1
        if m.cloudMutation.verifies < 3 then
            m.cloudVerifyTimer.control = "start"
        else
            FinishCloudMutation("Update not confirmed. Check account Watchlist before trying again.",false)
        end if
    end if
end sub

sub ShowCloudWatchlist(page = 0 as Integer)
    if page = 0 then page = SafeInt(m.cloudPage,1)
    if page < 1 then page = 1
    if SafeInt(m.cloudPages) > 0 and page > m.cloudPages then page = m.cloudPages
    EnterPage("cloud-watchlist","Watchlist · 30nama account")
    m.cloudWantedPage = page
    m.rails.content = CreateObject("roSGNode","ContentNode")
    m.railItems = []
    m.rails.setFocus(false)
    m.list.setFocus(false)
    m.nav.setFocus(false)
    m.top.setFocus(true)
    m.hint.text = "* options / refresh · FF / Rewind pages · Back TV Watchlist"
    if m.api.token = "" then
        m.cloudItems = []
        ShowEmpty("Sign in from Account to load your account Watchlist.")
        return
    end if
    m.status.text = "Loading your account Watchlist..."
    Request("cloud-list","mylist/group/watchlist/page/" + Text(page),{})
end sub

sub RenderCloudWatchlist()
    if m.page <> "cloud-watchlist" then return
    if not IsList(m.cloudItems) then m.cloudItems = []
    items = TitleView(m.cloudItems,Text(m.cloudFilter,"all"),Text(m.cloudSort,"added"))
    m.rails.content = CreateObject("roSGNode","ContentNode")
    m.railItems = []
    m.browse.visible = false
    m.rails.setFocus(false)
    if items.Count() = 0 then
        ShowEmpty("No matching account titles on this page. * options · FF / Rewind pages")
        m.list.setFocus(false)
        m.nav.setFocus(false)
        m.top.setFocus(true)
    else
        RenderRails([{label:"Saved on your 30nama account",items:items}],true)
        if SafeInt(m.cloudFocusId) > 0 then RestoreRailIndex(TitleFocusIndex(items,m.cloudFocusId))
    end if
    m.cloudRestoreIndex = invalid
    m.status.text = Text(items.Count()) + " of " + Text(m.cloudItems.Count()) + " on page " + Text(m.cloudPage) + " / " + Text(m.cloudPages)
    m.hint.text = "* options / refresh · FF / Rewind pages · Back TV Watchlist"
end sub

sub ShowCloudOptions()
    if m.page = "cloud-watchlist" then
        item = FocusedCard(m.rails.rowItemFocused)
        if item <> invalid then m.cloudFocusId = item.id
    end if
    EnterPage("cloud-watch-options","Account Watchlist options")
    m.cloudActions = ["refresh","filter","sort","local","back"]
    labels = ["Refresh from account","Show: " + m.cloudFilter,"Sort this page: " + m.cloudSort,"Open TV-only Watchlist","Back to account Watchlist"]
    if m.cloudPage < m.cloudPages then m.cloudActions.Push("next"):labels.Push("Next page")
    if m.cloudPage > 1 then m.cloudActions.Push("previous"):labels.Push("Previous page")
    m.list.content = MakeLabels(labels)
    m.list.visible = true:m.list.setFocus(true)
    m.status.text = "Account changes appear on your other signed-in 30nama devices."
end sub

sub OnCloudOption(index as Integer)
    if index < 0 or index >= m.cloudActions.Count() then return
    action = m.cloudActions[index]
    if action = "local" then ShowWatchlist(): return
    if action = "next" then m.cloudRestoreIndex = invalid: ShowCloudWatchlist(m.cloudPage + 1): return
    if action = "previous" then m.cloudRestoreIndex = invalid: ShowCloudWatchlist(m.cloudPage - 1): return
    if action = "filter" then m.cloudFilter = ChoiceNext(m.cloudFilter,["all","movies","series"])
    if action = "sort" then m.cloudSort = ChoiceNext(m.cloudSort,["added","title"])
    if action = "filter" or action = "sort" then ShowCloudOptions(): m.list.jumpToItem = index: return
    ShowCloudWatchlist()
end sub
