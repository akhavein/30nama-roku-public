' A search is transactional: commit only valid results; keep the previous view
' for Cancel/Back/retry. Request IDs and page generations reject late replies.
sub ShowSearchKeyboard()
    if m.keyboard <> invalid then CloseKeyboard()
    m.searchEditOrigin = m.page
    RememberSearchFocus()
    EnterPage("search", "Search")
    m.status.text = "Search the full 30nama library"
    m.keyboard = CreateObject("roSGNode", "StandardKeyboardDialog")
    m.keyboard.title = "Search movies and series"
    m.keyboard.message = ["Enter a title · English or Persian · Phone keyboard also works"]
    m.keyboard.buttons = ["Search", "Cancel"]
    m.keyboard.text = m.searchQuery
    m.keyboard.keyboardDomain = "generic"
    ObserveKeyboard()
    m.keyboard.observeField("buttonSelected", "OnSearchKeyboard")
    m.top.dialog = m.keyboard
end sub

sub OnSearchKeyboard()
    if m.keyboard = invalid then return
    if m.keyboard.buttonSelected = 1 then CloseKeyboard(): CancelSearchEdit(): return
    query = NormalizeSearchQuery(m.keyboard.text)
    if query = "" then KeyboardMessage("Enter a title to search"): return
    m.searchQuery = query
    m.searchPages = 1
    CloseKeyboard()
    StartSearch(1)
end sub

sub CancelSearchEdit()
    if m.searchEditOrigin = "recent-searches" then ShowRecentSearches(): return
    if IsMap(m.searchSnapshot) then RestoreSearchSnapshot() else ShowHome()
end sub

sub RememberSearchFocus()
    if m.page = "search" and m.searchState = "ready" and IsMap(m.searchSnapshot) then
        m.searchSnapshot.index = m.rails.rowItemFocused
        m.searchSnapshot.viewKey = Text(m.searchFilter) + ":" + Text(m.searchSort)
        item = FocusedSearchId(m.searchItems,m.searchSnapshot.index,Text(m.searchFilter),Text(m.searchSort))
        m.searchSnapshot.focusId = item
        key = SearchCacheKey(m.searchSnapshot.query,m.searchSnapshot.page)
        if IsMap(m.searchCache) then
            cached = m.searchCache.Lookup(key)
            if IsMap(cached) then
                cached.data.index = m.searchSnapshot.index
                cached.data.viewKey = m.searchSnapshot.viewKey
                cached.data.focusId = m.searchSnapshot.focusId
            end if
        end if
    end if
end sub

sub RestoreSearchSnapshot()
    if not IsMap(m.searchSnapshot) then ShowRecentSearches(): return
    snapshot = m.searchSnapshot
    EnterPage("search","Search")
    m.searchQuery = snapshot.query
    m.searchPage = snapshot.page
    m.searchPages = snapshot.pages
    m.searchItems = snapshot.items
    m.searchEffectiveQuery = Text(snapshot.effectiveQuery,m.searchQuery)
    m.searchState = "ready"
    RenderSearch()
    RestoreRailIndex(snapshot.index)
end sub

sub StartSearch(page as Integer,force = false as Boolean)
    query = NormalizeSearchQuery(m.searchQuery)
    if query = "" then ShowSearchKeyboard(): return
    if page < 1 then page = 1
    if page > m.searchPages then page = m.searchPages
    if m.searchState = "loading" and m.tasks.DoesExist("search") then
        if m.searchRequestKey = SearchCacheKey(query,page) and not force then return
    end if
    RememberSearchFocus()
    if page = 1 then
        m.recentSearches = RememberSearch(m.recentSearches,query)
        m.registry.Write("recent_searches",FormatJson(m.recentSearches))
        m.registry.Flush()
    end if
    EnterPage("search", "Search")
    m.searchQuery = query
    m.searchPage = page
    m.searchRequestKey = SearchCacheKey(query,page)
    if page = 1 then m.searchEffectiveQuery = query
    if Text(m.searchEffectiveQuery) = "" then m.searchEffectiveQuery = query
    m.searchItems = []
    m.searchState = "loading"
    m.searchErrorActions = []
    ShowSearchHeading("Searching...")
    ShowEmpty("Searching the library... Back edits · Left opens menu")
    ' Keep keyboard/Back handling in the content context while loading.
    m.top.setFocus(true)
    cached = SearchCacheGet(query,page)
    if cached <> invalid and not force then
        CommitSearch(cached)
        print "[30nama][search] cache_hit page="; page
        return
    end if
    Request("search", "search/page/" + Text(page) + "/order/desc/orderby/imdb/", {query:m.searchEffectiveQuery})
end sub

function SearchCacheGet(query as String,page as Integer) as Dynamic
    if not IsMap(m.searchCache) then return invalid
    entry = m.searchCache.Lookup(SearchCacheKey(query,page))
    if not IsMap(entry) then return invalid
    if CreateObject("roDateTime").AsSeconds() - entry.saved > 60 then return invalid
    return entry.data
end function

sub CacheSearch(data as Object)
    if not IsMap(m.searchCache) then m.searchCache = {}
    if not IsList(m.searchCacheOrder) then m.searchCacheOrder = []
    key = SearchCacheKey(m.searchQuery,m.searchPage)
    if not IsList(data.index) then data.index = [0,0]
    order = []
    for each oldKey in m.searchCacheOrder
        if oldKey <> key then order.Push(oldKey)
    end for
    order.Push(key)
    while order.Count() > 6
        m.searchCache.Delete(order.Shift())
    end while
    m.searchCacheOrder = order
    m.searchCache[key] = {saved:CreateObject("roDateTime").AsSeconds(),data:data}
end sub

sub HandleSearchResult(result as Dynamic)
    data = {ok:false}
    if IsMap(result) and Truth(result.success) then data = SearchResponse(result.result)
    if not data.ok then SearchFailure(): return
    if data.items.Count() = 0 and m.searchPage = 1 and m.searchEffectiveQuery = m.searchQuery then
        alternate = SearchAlternate(m.searchQuery)
        if alternate <> "" then
            m.searchEffectiveQuery = alternate
            Request("search","search/page/1/order/desc/orderby/imdb/",{query:alternate})
            return
        end if
    end if
    if m.searchPage > data.pages then
        m.searchPages = data.pages
        StartSearch(data.pages,true)
        return
    end if
    data.items = RankSearchItems(data.items,m.searchQuery)
    data.effectiveQuery = m.searchEffectiveQuery
    CacheSearch(data)
    CommitSearch(data)
end sub

sub CommitSearch(data as Object)
    m.searchItems = data.items
    m.searchPages = data.pages
    m.searchState = "ready"
    m.searchEffectiveQuery = Text(data.effectiveQuery,m.searchQuery)
    index = [0,0]
    if IsList(data.index) then index = data.index
    if data.DoesExist("viewKey") then
        if data.viewKey <> Text(m.searchFilter) + ":" + Text(m.searchSort) then index = TitleFocusIndex(TitleView(data.items,Text(m.searchFilter,"all"),Text(m.searchSort,"relevance")),SafeInt(data.focusId))
    end if
    m.searchSnapshot = {query:m.searchQuery,effectiveQuery:m.searchEffectiveQuery,page:m.searchPage,pages:m.searchPages,items:m.searchItems,index:index}
    RenderSearch()
    RestoreRailIndex(index)
end sub

sub SearchFailure()
    m.searchState = "error"
    m.searchQueryLabel.visible = false
    m.status.translation = [280,96]
    m.status.width = 920
    m.status.text = "Search couldn't finish. Your last results are safe."
    if m.searchHttpStatus = 401 then m.status.text = "Search couldn't finish. Sign in again from Account."
    if m.searchHttpStatus = 429 then m.status.text = "Search couldn't finish. Too many requests; wait a moment before retrying."
    m.empty.visible = false
    m.browse.visible = false
    labels = ["Retry search"]
    m.searchErrorActions = ["retry"]
    if m.searchHttpStatus = 401 then labels.Push("Open Account"): m.searchErrorActions.Push("account")
    if IsMap(m.searchSnapshot) then labels.Push("Back to previous results"): m.searchErrorActions.Push("results")
    labels.Push("Edit search"): m.searchErrorActions.Push("edit")
    labels.Push("Home"): m.searchErrorActions.Push("home")
    m.list.content = MakeLabels(labels)
    m.list.visible = true
    m.list.setFocus(true)
end sub

sub RenderSearch()
    m.list.visible = false
    ShowSearchHeading("Page " + Text(m.searchPage) + " of " + Text(m.searchPages))
    visibleItems = TitleView(m.searchItems,Text(m.searchFilter,"all"),Text(m.searchSort,"relevance"))
    if visibleItems.Count() = 0 then
        m.rails.setFocus(false)
        m.list.setFocus(false)
        m.railItems = []
        m.rails.content = CreateObject("roSGNode","ContentNode")
        m.browse.visible = false
        emptyText = "No titles found. Try another spelling, or the original English/Persian title. Press Back to edit."
        if m.searchItems.Count() > 0 then emptyText = "No " + m.searchFilter + " on this page. Press * to change the filter or page."
        ShowEmpty(emptyText)
        m.nav.setFocus(false)
        m.top.setFocus(true)
    else
        RenderRails([{label:Text(visibleItems.Count()) + " of " + Text(m.searchItems.Count()) + " on this page · " + Text(m.searchFilter,"all") + " · " + Text(m.searchSort,"relevance"),items:visibleItems}], true)
    end if
    m.hint.text = "OK details · Play watches · * pages / edit · FF next · Rewind previous"
end sub

sub ShowSearchHeading(stateLabel as String)
    m.searchQueryLabel.visible = true
    m.searchQueryLabel.horizAlign = "left"
    if HasArabicText(m.searchQuery) then m.searchQueryLabel.horizAlign = "right"
    SetDisplayText(m.searchQueryLabel,m.searchQuery,22)
    m.status.translation = [980,96]
    m.status.width = 220
    m.status.text = stateLabel
end sub

sub ShowSearchOptions()
    if m.searchState <> "ready" then ShowSearchKeyboard(): return
    RememberSearchFocus()
    m.searchIndex = m.rails.rowItemFocused
    item = FocusedCard(m.searchIndex)
    if item <> invalid then m.searchFocusId = item.id
    EnterPage("search-options","Search")
    m.status.text = "Page " + Text(m.searchPage) + " of " + Text(m.searchPages)
    labels = []
    m.searchActions = []
    if m.searchPage < m.searchPages then labels.Push("Next page"): m.searchActions.Push("next")
    if m.searchPage > 1 then labels.Push("Previous page"): m.searchActions.Push("previous")
    labels.Push("Edit search"): m.searchActions.Push("edit")
    labels.Push("Refresh results"): m.searchActions.Push("refresh")
    labels.Push("Show on this page: " + m.searchFilter): m.searchActions.Push("filter")
    labels.Push("Sort this page: " + m.searchSort): m.searchActions.Push("sort")
    labels.Push("Back to results"): m.searchActions.Push("results")
    m.list.content = MakeLabels(labels)
    m.list.visible = true
    m.list.setFocus(true)
end sub
