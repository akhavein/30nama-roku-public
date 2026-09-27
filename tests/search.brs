sub Main()
    m.checks = 0
    Assert(NormalizeSearchQuery("  Breaking"+Chr(9)+" Bad  ") = "Breaking Bad","tabs and repeated spaces normalize")
    Assert(NormalizeSearchQuery("علي كيان ۲۰۲۶") = "علی کیان 2026","Persian and Arabic letter/digit variants normalize")
    Assert(NormalizeSearchQuery("Spider-Man: No Way Home / 2021") = "Spider-Man: No Way Home / 2021","punctuation remains literal")
    Assert(NormalizeSearchQuery("A&B + 'Love' #1") = "A&B + 'Love' #1","URL metacharacters remain literal form data")
    Assert(NormalizeSearchQuery(Chr(160)+" "+Chr(10)) = "","Unicode whitespace cannot launch empty search")
    Assert(Len(NormalizeSearchQuery(String(200,"a"))) = 120,"query length bounded")
    Assert(SearchAlternate("Schindler's List") = "Schindler s List","apostrophe fallback matches verified provider contract")
    Assert(SearchAlternate("Love") = "","ordinary queries do not launch pointless fallbacks")
    ranked = RankSearchItems(NormalizeTitles([{id:2,title:"The Matrix Resurrections 2021"},{id:1,title:"The Matrix 1999"}]),"The Matrix")
    Assert(ranked[0].id = 1,"exact title outranks a sequel on the same provider page")
    Assert(SearchResponse({posts:[],pages:0}).ok,"genuine empty results accepted")
    Assert(not SearchResponse({posts:{},pages:2}).ok,"wrong posts type is failure, not empty")
    Assert(not SearchResponse({posts:[invalid,{id:0}],pages:2}).ok,"all-invalid rows are failure")
    parsed = SearchResponse({posts:[{id:1,title:"One"},invalid,{id:1,title:"Duplicate"},{id:2,title:"Two"}],pages:3})
    Assert(parsed.items.Count() = 2 and parsed.pages = 3,"mixed/duplicate rows normalize")
    Assert(SearchResponse({posts:[],pages:999999}).pages = 10000,"malformed page count bounded")
    m.tasks = {}
    m.searchQuery = "Love"
    m.searchPage = 1
    m.searchPages = 3
    m.searchState = "idle"
    m.searchCache = {}
    m.searchCacheOrder = []
    m.recentSearches = []
    m.rails = {rowItemFocused:[0,0]}
    m.status = {}
    m.registry = {Write:sub(k,v)
    end sub,Flush:sub()
    end sub}
    m.top = {setFocus:sub(v)
    end sub}
    m.requests = 0
    StartSearch(1)
    Assert(m.requests = 1 and m.searchState = "loading","first query creates request")
    StartSearch(1)
    Assert(m.requests = 1,"duplicate submit while loading does not duplicate request")
    HandleSearchResult({success:true,result:{posts:[{id:1,title:"One"},{id:2,title:"Two"}],pages:3}})
    Assert(m.searchState = "ready" and m.searchItems.Count() = 2,"valid response committed")
    m.rails.rowItemFocused = [0,1]
    StartSearch(2)
    Assert(m.searchSnapshot.page = 1 and m.searchSnapshot.index[1] = 1,"page load preserves successful results and focus")
    HandleSearchResult({success:false})
    Assert(m.searchState = "error" and m.searchSnapshot.items.Count() = 2,"page failure keeps previous results")
    CancelSearchEdit()
    Assert(m.page = "search" and m.searchPage = 1 and m.restored[1] = 1,"cancel restores page and focus")
    before = m.requests
    StartSearch(1)
    Assert(m.requests = before and m.searchState = "ready","cache avoids a redundant provider request")
    Assert(m.restored[1] = 1,"cached page restores its own remembered card position")
    StartSearch(1,true)
    Assert(m.requests = before+1,"explicit refresh bypasses cache")
    m.searchCache[SearchCacheKey("Love",1)].saved = 0
    Assert(SearchCacheGet("Love",1) = invalid,"expired cache is not reused")
    for i = 1 to 9
        m.searchPage = i
        CacheSearch({ok:true,items:[],pages:10})
    end for
    Assert(m.searchCache.Count() = 6 and m.searchCacheOrder.Count() = 6,"cache is bounded to six pages")
    m.searchPage = 5
    m.searchPages = 5
    HandleSearchResult({success:true,result:{posts:[],pages:2}})
    Assert(m.searchPage = 2 and m.searchState = "loading","shrinking catalog redirects to the actual last page")
    m.searchQuery = "Different"
    m.searchPages = 1
    StartSearch(1)
    Assert(m.searchItems.Count() = 0,"new query never labels old result cards as new matches")
    m.tasks = {}
    m.searchQuery = "Schindler's List"
    m.searchEffectiveQuery = m.searchQuery
    m.searchPage = 1
    HandleSearchResult({success:true,result:{posts:[],pages:0}})
    Assert(m.searchEffectiveQuery = "Schindler s List" and m.tasks.search.payload.query = "Schindler s List","zero results trigger one punctuation-tolerant request")
    m.tasks = {}
    HandleSearchResult({success:true,result:{posts:[],pages:0}})
    Assert(m.searchState = "ready" and not m.tasks.DoesExist("search"),"fallback is bounded even when no title exists")
    audio = AudioOptions([{Track:"A",Language:"eng",Name:"English"},{Track:"B",Language:"eng",Name:"Description",HasAccessibilityDescription:true}])
    Assert(PreferredAudio(audio,"en",false) = 0,"audio preference matches language without commentary")
    Assert(PreferredAudio(audio,"en",true) = 1,"audio description preference is distinct")
    Assert(PreferredAudio(audio,"fa",false) = -1,"missing preferred audio does not select unrelated track")
    print "REGRESSION PASS: ";m.checks;" search/polish assertions"
end sub
sub Assert(ok as Boolean,label as String)
    if not ok then print "FAIL: ";label: stop
    m.checks = m.checks + 1
    print "PASS: ";label
end sub
sub EnterPage(page,heading)
    m.page = page
    m.tasks = {}
end sub
sub Request(tag,action,payload)
    m.requests = m.requests + 1
    m.tasks[tag] = {payload:payload}
end sub
sub ShowEmpty(message)
end sub
sub RenderSearch()
    m.tasks.Delete("search")
end sub
sub SearchFailure()
    m.searchState = "error"
    m.tasks.Delete("search")
end sub
sub RestoreRailIndex(index)
    m.restored = index
end sub
sub ShowHome()
    m.page = "home"
end sub
sub ShowRecentSearches()
    m.page = "recent-searches"
end sub
sub ShowSearchKeyboard()
    m.page = "keyboard"
end sub

sub ShowSearchHeading(label)
    m.status.text = label
end sub
