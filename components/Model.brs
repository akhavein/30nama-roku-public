' Pure data operations shared by the UI and executable regression tests.
function CloudWatchIds(response as Dynamic) as Dynamic
    if not IsMap(response) or not Truth(response.success) then return invalid
    data = response.result
    if not IsMap(data) or not IsMap(data.watchlist) then return invalid
    posts = data.watchlist.post
    if not IsList(posts) then return invalid
    if posts.Count() > 10000 then return invalid
    ids = {}
    for each value in posts
        raw = Text(value)
        if Len(raw) = 0 or Len(raw) > 10 then return invalid
        if not CreateObject("roRegex","^[0-9]+$","").IsMatch(raw) then return invalid
        if Len(raw) = 10 and raw > "2147483647" then return invalid
        id = SafeInt(raw)
        if id <= 0 then return invalid
        while Len(raw) > 1 and Left(raw,1) = "0"
            raw = Mid(raw,2)
        end while
        if Text(id) <> raw then return invalid
        ids[Text(id)] = true
    end for
    return ids
end function

function CloudWatchPage(response as Dynamic) as Dynamic
    if not IsMap(response) or not Truth(response.success) then return invalid
    data = response.result
    if not IsMap(data) or not IsList(data.posts) then return invalid
    if data.posts.Count() > 100 then return invalid
    pattern = CreateObject("roRegex","^[0-9]{1,5}$","")
    if not pattern.IsMatch(Text(data.page)) or not pattern.IsMatch(Text(data.pages)) then return invalid
    page = SafeInt(data.page,-1): pages = SafeInt(data.pages,-1)
    if pages = 0 and data.posts.Count() = 0 then pages = 1
    if page < 1 or pages < 1 or pages > 10000 then return invalid
    items = NormalizeTitles(data.posts)
    if data.posts.Count() > 0 and items.Count() = 0 then return invalid
    return {page:page,pages:pages,items:items}
end function

function MarkerSeconds(value as Dynamic) as Integer
    if type(value) <> "String" and type(value) <> "roString" then return -1
    if not CreateObject("roRegex","^[0-9]{2}:[0-9]{2}:[0-9]{2}$","").IsMatch(value) then return -1
    parts = value.Split(":")
    h = SafeInt(parts[0]): minutes = SafeInt(parts[1]): seconds = SafeInt(parts[2])
    if h > 23 or minutes > 59 or seconds > 59 then return -1
    return h * 3600 + minutes * 60 + seconds
end function

function IntroMarker(options as Dynamic) as Dynamic
    if not IsMap(options) then return invalid
    first = MarkerSeconds(options.intro_start)
    last = MarkerSeconds(options.intro_end)
    if first < 0 or last <= first or last - first > 600 then return invalid
    return {first:first,last:last}
end function

function IntroTarget(marker as Dynamic,position as Dynamic,duration as Dynamic) as Integer
    if not IsMap(marker) then return -1
    if not IsNumericValue(position) or not IsNumericValue(duration) then return -1
    if duration <= 0 or marker.last >= duration then return -1
    if position < marker.first or position >= marker.last then return -1
    return marker.last
end function

function IsNumericValue(value as Dynamic) as Boolean
    return type(value) = "Integer" or type(value) = "roInt" or type(value) = "Float" or type(value) = "roFloat" or type(value) = "Double" or type(value) = "roDouble" or type(value) = "LongInteger"
end function

function Text(value as Dynamic, fallback = "" as String) as String
    if value = invalid then return fallback
    if GetInterface(value, "ifString") <> invalid then return value
    if GetInterface(value, "ifToStr") <> invalid then return value.ToStr().Trim()
    return fallback
end function

function IsMap(value as Dynamic) as Boolean
    return GetInterface(value, "ifAssociativeArray") <> invalid
end function

function IsList(value as Dynamic) as Boolean
    return GetInterface(value, "ifArray") <> invalid
end function

function SafeInt(value as Dynamic, fallback = 0 as Integer) as Integer
    if value = invalid then return fallback
    raw = Text(value).Trim()
    if raw = "" then return fallback
    for i = 1 to Len(raw)
        char = Mid(raw,i,1)
        if Instr(1,"0123456789.-",char) = 0 then return fallback
    end for
    if raw = "-" or raw = "." then return fallback
    ' Keep whole-number IDs and epoch timestamps out of single-precision Val.
    if Instr(1,raw,".") = 0 then return raw.ToInt()
    return Int(Val(raw))
end function

function Truth(value as Dynamic) as Boolean
    s = LCase(Text(value))
    return s = "true" or s = "1" or s = "yes"
end function

function PosterUrl(item as Dynamic) as String
    if not IsMap(item) then return ""
    if item.poster <> invalid then return Text(item.poster)
    if not IsMap(item.image) then return ""
    poster = item.image.Lookup("poster")
    if not IsMap(poster) then return ""
    for each size in ["large", "medium", "small"]
        url = Text(poster.Lookup(size))
        if url <> "" then return url
    end for
    return ""
end function

function NormalizeTitle(item as Dynamic) as Dynamic
    if not IsMap(item) then return invalid
    id = SafeInt(item.id)
    if id <= 0 then return invalid
    title = Text(item.title, Text(item.name, "Untitled"))
    return {id:id, title:title, poster:PosterUrl(item), plot:Text(item.english_plot, Text(item.plot)), isSeries:Truth(item.is_series) or Truth(item.isSeries), year:Text(item.year), rating:Text(item.imdb_score, Text(item.imdb_rate, Text(item.rating))), episodeId:SafeInt(item.episodeId), season:SafeInt(item.season), number:SafeInt(item.number), episodeTitle:Text(item.episodeTitle)}
end function

function NormalizeTitles(items as Dynamic) as Object
    out = []
    seen = {}
    if not IsList(items) then return out
    for each raw in items
        item = NormalizeTitle(raw)
        if item <> invalid then
            key = Text(item.id)
            if not seen.DoesExist(key) then out.Push(item): seen[key] = true
        end if
    end for
    return out
end function

function SectionPosts(section as Dynamic) as Object
    if IsList(section) then return NormalizeTitles(section)
    if IsMap(section) then return NormalizeTitles(section.posts)
    return []
end function

function FlattenEpisodes(seasons as Dynamic) as Object
    items = []
    seen = {}
    if not IsMap(seasons) then return items
    for each seasonKey in seasons.Keys()
        list = seasons.Lookup(seasonKey)
        if IsList(list) then
            for each episode in list
                if IsMap(episode) and IsMap(episode.data) then
                    data = episode.data
                    id = SafeInt(data.id)
                    season = SafeInt(data.season, SafeInt(seasonKey))
                    number = SafeInt(data.number)
                    if id > 0 and season >= 0 and number > 0 and not seen.DoesExist(Text(id)) then
                        items.Push({id:id, season:season, number:number, title:EpisodeLabel(data, number), file:episode.file, subtitle:episode.subtitle, options:episode.options})
                        seen[Text(id)] = true
                    end if
                end if
            end for
        end if
    end for
    for i = 1 to items.Count() - 1
        item = items[i]
        j = i - 1
        while j >= 0
            prior = items[j]
            if prior.season < item.season then exit while
            if prior.season = item.season and prior.number <= item.number then exit while
            items[j + 1] = prior
            j = j - 1
        end while
        items[j + 1] = item
    end for
    return items
end function

function SeasonNumbers(episodes as Object) as Object
    seasons = []
    previous = -1
    for each episode in episodes
        if episode.season <> previous then seasons.Push(episode.season): previous = episode.season
    end for
    return seasons
end function

function EpisodesInSeason(episodes as Object, season as Integer) as Object
    items = []
    for each episode in episodes
        if episode.season = season then items.Push(episode)
    end for
    return items
end function

function EpisodeIndex(episodes as Object, id as Integer) as Integer
    for i = 0 to episodes.Count() - 1
        if episodes[i].id = id then return i
    end for
    return -1
end function

function StreamUrl(file as Dynamic) as String
    if not IsMap(file) then return ""
    if IsList(file.source) then
        for each source in file.source
            if IsMap(source) then
                for each quality in ["auto", "2ch"]
                    url = MediaUrl(source.Lookup(quality))
                    if Left(url,8) = "https://" or Left(url,7) = "http://" then return url
                end for
            end if
        end for
    end if
    url = MediaUrl(file.url)
    if Left(url,8) = "https://" or Left(url,7) = "http://" then return url
    return ""
end function

function SubtitleOptions(subtitle as Dynamic) as Object
    options = [{label:"System default", code:"system", track:""}, {label:"Off", code:"off", track:""}]
    if IsMap(subtitle) then
        for each code in ["en", "fa"]
            url = MediaUrl(subtitle.Lookup(code))
            if Left(url,8) = "https://" or Left(url,7) = "http://" then
                label = "English"
                if code = "fa" then label = "Persian"
                options.Push({label:label, code:code, track:url})
            end if
        end for
    end if
    return options
end function

function ClockText(seconds as Dynamic) as String
    n = SafeInt(seconds)
    if n < 0 then n = 0
    hours = Int(n / 3600)
    minutes = Int(n / 60) mod 60
    secs = n mod 60
    secondText = Pad2(secs)
    if hours > 0 then return Text(hours) + ":" + Pad2(minutes) + ":" + secondText
    return Text(minutes) + ":" + secondText
end function

function SeekTarget(position as Dynamic, delta as Integer, duration as Dynamic) as Integer
    target = SafeInt(position) + delta
    if target < 0 then target = 0
    length = SafeInt(duration)
    if length > 0 and target >= length then target = length - 1
    return target
end function

function CleanHistory(value as Dynamic) as Object
    out = []
    seen = {}
    if not IsList(value) then return out
    for each raw in value
        item = NormalizeTitle(raw)
        if item <> invalid then
            key = Text(item.id)
            if not seen.DoesExist(key) then
                item.position = SafeInt(raw.position)
                item.duration = SafeInt(raw.duration)
                if item.position < 0 then item.position = 0
                if item.duration < 0 then item.duration = 0
                item.completed = Truth(raw.completed)
                item.updated = SafeInt(raw.updated)
                item.syncDirty = not raw.DoesExist("syncDirty") or Truth(raw.syncDirty)
                out.Push(item)
                seen[key] = true
                if out.Count() >= 20 then exit for
            end if
        end if
    end for
    return out
end function

function HistoryFind(history as Object, id as Integer) as Dynamic
    for each item in history
        if item.id = id then return item
    end for
    return invalid
end function

function HistoryRemove(history as Object, id as Integer) as Object
    out = []
    for each item in history
        if item.id <> id then out.Push(item)
    end for
    return out
end function

function HistoryUpsert(history as Object, entry as Object) as Object
    out = [entry]
    for each item in history
        if item.id <> entry.id and out.Count() < 20 then out.Push(item)
    end for
    return CleanHistory(out)
end function

function ContinueItems(history as Object) as Object
    out = []
    for each item in history
        if not item.completed then out.Push(item)
    end for
    return out
end function

function ResumeSeconds(entry as Dynamic, episodeId as Integer) as Integer
    if not IsMap(entry) then return 0
    if entry.completed or entry.episodeId <> episodeId then return 0
    return SeekTarget(entry.position,0,entry.duration)
end function

function HistoryEntry(title as Object, episode as Dynamic, position as Integer, duration as Integer, completed as Boolean) as Object
    entry = NormalizeTitle(title)
    entry.position = position
    entry.duration = duration
    entry.completed = completed
    entry.syncDirty = true
    entry.updated = CreateObject("roDateTime").AsSeconds()
    entry.episodeId = 0
    if IsMap(episode) then
        entry.episodeId = episode.id
        entry.season = episode.season
        entry.number = episode.number
        entry.episodeTitle = episode.title
    end if
    return entry
end function

function Pad2(value as Integer) as String
    if value < 10 then return "0" + Text(value)
    return Text(value)
end function

function EpisodeLabel(data as Object, number as Integer) as String
    name = Text(data.english_title,Text(data.title))
    for i = 1 to Len(name)
        code = Asc(Mid(name,i,1))
        if code >= 1536 and code <= 1791 then return "Episode " + Text(number)
    end for
    if name = "" then return "Episode " + Text(number)
    return name
end function

function MediaUrl(value as Dynamic) as String
    url = Text(value).Trim()
    ' Same protocol placeholders normalized by official-30nama-api core/index.js.
    if Left(url,7) = "link://" then return "https://" + Mid(url,8)
    if Left(url,13) = "linkStream://" then return "https://" + Mid(url,14)
    if Left(url,2) = "//" then return "https:" + url
    return url
end function

function NativeSubtitleOptions(sidecars as Object, available as Dynamic) as Object
    options = [{label:"System default",code:"system",track:""},{label:"Off",code:"off",track:""}]
    seen = {}
    languages = {}
    if IsList(available) then
        for each track in available
            if IsMap(track) then
                id = Text(track.TrackName)
                if id <> "" and not seen.DoesExist(id) then
                    language = LCase(Text(track.Language))
                    code = "embedded"
                    if language = "eng" then code = "en"
                    if language = "fas" or language = "per" then code = "fa"
                    label = Text(track.Description,Text(track.Language,"Subtitle"))
                    options.Push({label:label,code:code,track:id})
                    seen[id] = true
                    languages[code] = true
                end if
            end if
        end for
    end if
    for each option in sidecars
        if option.track <> "" and not languages.DoesExist(option.code) and not seen.DoesExist(option.track) then
            options.Push(option)
        end if
    end for
    return options
end function

function AudioOptions(available as Dynamic) as Object
    options = []
    seen = {}
    if IsList(available) then
        for each track in available
            if IsMap(track) then
                id = Text(track.Track)
                if id <> "" and not seen.DoesExist(id) then
                    language = LCase(Text(track.Language))
                    if language = "eng" or language = "en" then language = "English"
                    if language = "per" or language = "fas" or language = "fa" then language = "Persian"
                    if language = "und" then language = ""
                    name = Text(track.Name)
                    if LCase(name) = "audio" then name = ""
                    if name = "" then name = language
                    if name = "" then name = "Audio track"
                    label = Text(options.Count() + 1) + " · " + name
                    if Truth(track.HasAccessibilityDescription) then label = label + " · Description"
                    options.Push({label:label,track:id,language:AudioLanguage(track.Language),description:Truth(track.HasAccessibilityDescription)})
                    seen[id] = true
                end if
            end if
        end for
    end if
    if options.Count() = 0 then options.Push({label:"Default audio — no alternate tracks",track:""})
    return options
end function

function MergeRemoteHistory(local as Object, remote as Dynamic) as Object
    out = CleanHistory(local)
    if not IsList(remote) then return out
    nowSeconds = CreateObject("roDateTime").AsSeconds()
    for each row in remote
        item = NormalizeTitle(row)
        if item <> invalid then
            item.number = SafeInt(row.episode)
            old = HistoryFind(out,item.id)
            protected = false
            if old <> invalid then
                protected = Truth(old.syncDirty) or old.completed
                ' The provider can cache history for about two minutes after a
                ' successful write. Protect recent local backward movement for
                ' five minutes; still accept forward remote progress immediately.
                if not protected and old.updated > 0 and nowSeconds - old.updated < 300 then
                    sameEpisode = not old.isSeries or (old.season = item.season and old.number = item.number)
                    olderEpisode = old.isSeries and (old.season > item.season or (old.season = item.season and old.number > item.number))
                    protected = olderEpisode or (sameEpisode and old.position > SafeInt(row.time))
                end if
            end if
            if not protected then
                item.position = SafeInt(row.time)
                item.duration = 0
                item.completed = false
                item.syncDirty = false
                if old <> invalid then
                    item.duration = old.duration
                    if old.season = item.season and old.number = item.number then
                        item.episodeId = old.episodeId
                        if old.position >= item.position and old.position - item.position < 30 then item.position = old.position
                    end if
                end if
                item.updated = 0
                if old = invalid then out.Push(item) else out = HistoryUpsert(out,item)
            end if
        end if
    end for
    return CleanHistory(out)
end function

function ToggleWatchlist(items as Object,title as Object) as Object
    if HistoryFind(items,title.id) <> invalid then return HistoryRemove(items,title.id)
    out = [NormalizeTitle(title)]
    for each item in items
        if out.Count() < 100 then out.Push(item)
    end for
    return out
end function

function CleanSearches(value as Dynamic) as Object
    out = []
    if not IsList(value) then return out
    seen = {}
    for each raw in value
        if GetInterface(raw,"ifString") <> invalid then
            query = NormalizeSearchQuery(raw)
            if query <> "" and not seen.DoesExist(LCase(query)) then
                out.Push(query)
                seen[LCase(query)] = true
                if out.Count() >= 10 then exit for
            end if
        end if
    end for
    return out
end function

' Keep punctuation (including apostrophes) literal. Never interpolate into URLs.
function NormalizeSearchQuery(value as String) as String
    value = value.Replace(Chr(1610),Chr(1740)).Replace(Chr(1603),Chr(1705))
    for i = 0 to 9
        value = value.Replace(Chr(1776+i),Text(i)).Replace(Chr(1632+i),Text(i))
    end for
    for each code in [9,10,13,160,8199,8239,12288]
        value = value.Replace(Chr(code)," ")
    end for
    while Instr(1,value,"  ") > 0
        value = value.Replace("  "," ")
    end while
    return Left(value.Trim(),120)
end function

function SearchResponse(data as Dynamic) as Object
    if not IsMap(data) then return {ok:false}
    if not IsList(data.posts) then return {ok:false}
    items = NormalizeTitles(data.posts)
    ' A nonempty array of entirely invalid objects is a broken response, not a
    ' valid zero-result query. Do not cache it as "nothing found".
    if data.posts.Count() > 0 and items.Count() = 0 then return {ok:false}
    pages = SafeInt(data.pages,1)
    if pages < 1 then pages = 1
    if pages > 10000 then pages = 10000
    return {ok:true,items:items,pages:pages}
end function

function SearchCacheKey(query as String,page as Integer) as String
    return LCase(NormalizeSearchQuery(query)) + "|" + Text(page)
end function

function SearchAlternate(query as String) as String
    value = query
    for each punctuation in ["'",Chr(8217),Chr(8216),Chr(34),"-",":","/","(",")"]
        value = value.Replace(punctuation," ")
    end for
    value = NormalizeSearchQuery(value)
    if value = query then return ""
    return value
end function

function SearchMatchKey(value as String) as String
    alternate = SearchAlternate(value)
    if alternate <> "" then value = alternate
    return LCase(NormalizeSearchQuery(value))
end function

function RankSearchItems(items as Object,query as String) as Object
    exact = []: prefix = []: rest = []
    key = SearchMatchKey(query)
    for each item in items
        titleKey = SearchMatchKey(item.title)
        withoutYear = titleKey
        if Len(titleKey) > 5 then
            year = SafeInt(Right(titleKey,4))
            if year >= 1880 and year <= 2100 and Mid(titleKey,Len(titleKey)-4,1) = " " then withoutYear = Left(titleKey,Len(titleKey)-5).Trim()
        end if
        if titleKey = key or withoutYear = key then
            exact.Push(item)
        else if Left(titleKey,Len(key)) = key then
            prefix.Push(item)
        else
            rest.Push(item)
        end if
    end for
    exact.Append(prefix): exact.Append(rest)
    return exact
end function

function AudioLanguage(value as Dynamic) as String
    language = LCase(Text(value))
    if language = "eng" then return "en"
    if language = "fas" or language = "per" then return "fa"
    if language = "und" then return ""
    return language
end function

function PreferredAudio(options as Object,language as String,description as Boolean) as Integer
    if language = "" then return -1
    for i = 0 to options.Count() - 1
        if Text(options[i].language) = language and Truth(options[i].description) = description then return i
    end for
    return -1
end function

function RememberSearch(items as Object,query as String) as Object
    out = [query]
    for each item in items
        out.Push(item)
    end for
    return CleanSearches(out)
end function

function StreamOptions(file as Dynamic) as Object
    out = []
    seen = {}
    if not IsMap(file) then return out
    if IsList(file.source) then
        for each source in file.source
            if IsMap(source) then
                for each kind in ["auto","2ch","6ch"]
                    url = MediaUrl(source.Lookup(kind))
                    if (Left(url,8) = "https://" or Left(url,7) = "http://") and not seen.DoesExist(url) then
                        label = "Auto"
                        if kind = "2ch" then label = "Stereo"
                        if kind = "6ch" then label = "Surround"
                        if Text(source.label) <> "" then label = Text(source.label) + " · " + label
                        out.Push({url:url,label:label})
                        seen[url] = true
                        if out.Count() >= 8 then return out
                    end if
                end for
            end if
        end for
    end if
    url = MediaUrl(file.url)
    if (Left(url,8) = "https://" or Left(url,7) = "http://") and not seen.DoesExist(url) then out.Push({url:url,label:"Original source"})
    return out
end function

function ClampCaptionOffset(value as Integer) as Integer
    if value < -10000 then return -10000
    if value > 10000 then return 10000
    return value
end function

function CaptionLayout(textValue as String,baseSize as Integer) as Object
    if baseSize <> 26 and baseSize <> 32 and baseSize <> 40 then baseSize = 32
    lines = 0
    for each line in textValue.Split(Chr(10))
        estimate = Int(Len(line) * baseSize * 0.6 / 1088) + 1
        lines = lines + estimate
    end for
    if lines < 1 then lines = 1
    if lines > 5 then lines = 5
    size = baseSize
    maximum = Int(208 / (lines * 1.85))
    if size > maximum then size = maximum
    if size < 20 then size = 20
    ' Merged font hhea metrics are 1703 units per 1000 em. A 40px font
    ' needs more than 68px per line; shorter labels can render no glyphs.
    height = Int(lines * size * 1.85) + 24
    if height > 224 then height = 224
    return {size:size,height:height}
end function

' Per-episode ledger is separate from the single Continue target per series.
' Only compact public identifiers/progress are retained; newest 120 entries win, within a separate serialized byte budget.
function CleanEpisodeHistory(value as Dynamic) as Object
    out = []
    seen = {}
    if not IsList(value) then return out
    for each raw in value
        if IsList(raw) then
            if raw.Count() = 6 then raw = {id:raw[0],episodeId:raw[1],position:raw[2],duration:raw[3],completed:raw[4],updated:raw[5]}
        end if
        if IsMap(raw) then
            id = SafeInt(raw.id)
            ep = SafeInt(raw.episodeId)
            key = Text(id) + ":" + Text(ep)
            if id > 0 and ep > 0 and not seen.DoesExist(key) then
                position = SafeInt(raw.position)
                duration = SafeInt(raw.duration)
                if position < 0 then position = 0
                if duration < 0 then duration = 0
                out.Push({id:id,episodeId:ep,position:position,duration:duration,completed:Truth(raw.completed),updated:SafeInt(raw.updated)})
                seen[key] = true
                if out.Count() >= 120 then exit for
            end if
        end if
    end for
    return out
end function

function EpisodeHistoryFind(items as Dynamic,id as Integer,episodeId as Integer) as Dynamic
    if not IsList(items) then return invalid
    for each item in items
        if item.id = id and item.episodeId = episodeId then return item
    end for
    return invalid
end function

function EpisodeHistoryUpsert(items as Dynamic,entry as Object) as Object
    out = [entry]
    if IsList(items) then
        for each item in items
            if item.id <> entry.id or item.episodeId <> entry.episodeId then out.Push(item)
        end for
    end if
    return CleanEpisodeHistory(out)
end function

function EpisodeResumeEntry(history as Object,ledger as Dynamic,id as Integer,episodeId as Integer) as Dynamic
    latest = HistoryFind(history,id)
    saved = EpisodeHistoryFind(ledger,id,episodeId)
    ' A newer cloud checkpoint for this episode may supersede the local ledger.
    if latest <> invalid then
        if latest.episodeId = episodeId then
            if saved = invalid then return latest
            if latest.updated > saved.updated then return latest
            ' Provider snapshots have no timestamp. Accept forward progress or
            ' a settled older rewind, but never undo an explicit local watched flag.
            if latest.updated = 0 and not Truth(latest.syncDirty) and not saved.completed then
                if latest.position > saved.position then return latest
                if CreateObject("roDateTime").AsSeconds() - saved.updated >= 300 then return latest
            end if
        end if
    end if
    if saved <> invalid then return saved
    return latest
end function

function ChoiceNext(value as String,choices as Object) as String
    for i = 0 to choices.Count() - 1
        if choices[i] = value then return choices[(i + 1) mod choices.Count()]
    end for
    return choices[0]
end function

function TitleView(items as Object,kind as String,sort as String) as Object
    out = []
    for each item in items
        include = kind = "all" or (kind = "series" and item.isSeries) or (kind = "movies" and not item.isSeries)
        if include then
            index = out.Count()
            if sort = "title" then
                for i = 0 to out.Count() - 1
                    if LCase(item.title) < LCase(out[i].title) then index = i: exit for
                end for
            else if sort = "rating" then
                for i = 0 to out.Count() - 1
                    if Val(item.rating) > Val(out[i].rating) then index = i: exit for
                end for
            end if
            out.Push(item)
            for i = out.Count() - 1 to index + 1 step -1
                out[i] = out[i - 1]
            end for
            out[index] = item
        end if
    end for
    return out
end function

function TitleFocusIndex(items as Object,id as Integer) as Object
    for i = 0 to items.Count() - 1
        if items[i].id = id then return [0,i]
    end for
    return [0,0]
end function

function RemoteSeconds(kind as String) as Integer
    value = SafeInt(m.Lookup("remote_" + kind))
    choices = [5,10,15,30]
    fallback = 10
    if kind = "skip" then choices = [10,30,60]: fallback = 30
    if kind = "replay" then choices = [10,15,20,25]
    for each choice in choices
        if value = choice then return value
    end for
    return fallback
end function

function CaptionPlacement(height as Integer,position as String,controls as Boolean) as Integer
    bottom = 656
    if position = "raised" then bottom = 584
    if position = "top" then bottom = 130 + height
    if controls and bottom > 416 then bottom = 416
    y = bottom - height
    if y < 130 then y = 130
    return y
end function

function CaptionContrast(value as String) as String
    if value = "soft" then return "0x00000070"
    if value = "solid" then return "0x000000ff"
    return "0x000000b0"
end function

function SleepReason(minutes as Float,elapsed as Float,stillMinutes as Integer,watchSeconds as Float) as String
    if minutes > 0 and elapsed >= minutes * 60 then return "sleep"
    if stillMinutes > 0 and watchSeconds >= stillMinutes * 60 then return "still"
    return ""
end function

function FocusedSearchId(items as Object,index as Dynamic,kind as String,sort as String) as Integer
    if not IsList(index) then return 0
    if index.Count() <> 2 then return 0
    if kind = "" then kind = "all"
    visible = TitleView(items,kind,sort)
    if index[1] < 0 or index[1] >= visible.Count() then return 0
    return visible[index[1]].id
end function

function EpisodeStorage(items as Object,budget as Integer) as Object
    rows = []
    retained = []
    for each item in items
        rows.Push([item.id,item.episodeId,item.position,item.duration,item.completed,item.updated])
        if Len(FormatJson(rows)) > budget then rows.Pop(): exit for
        retained.Push(item)
    end for
    return {items:retained,json:FormatJson(rows)}
end function

function PreviewTarget(position as Dynamic, delta as Integer, duration as Dynamic) as Integer
    return SeekTarget(SafeInt(position),delta,SafeInt(duration))
end function

function ValidPreviewResponse(value as Dynamic, target as Integer) as Boolean
    if not IsMap(value) then return false
    if Type(value.success) <> "Boolean" and Type(value.success) <> "roBoolean" then return false
    if value.success <> true then return false
    if Type(value.seconds) <> "Integer" and Type(value.seconds) <> "roInt" and Type(value.seconds) <> "roInteger" then return false
    if value.seconds <> target or target < 0 then return false
    if Type(value.jpeg) <> "String" and Type(value.jpeg) <> "roString" then return false
    return Len(value.jpeg) >= 8 and Len(value.jpeg) <= 133336
end function
