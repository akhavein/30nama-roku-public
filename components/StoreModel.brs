' IDs are opaque catalog identities, never URLs or executable strings.
' Movie: title ID; episodic types: titleID:episodeID (same ID across types).
function ParseStoreLink(args as Dynamic) as Dynamic
    if not IsMap(args) then return invalid
    kind = LCase(Text(args.mediaType))
    if kind <> "movie" and kind <> "episode" and kind <> "series" and kind <> "season" then return invalid
    id = Text(args.contentId)
    if Len(id) = 0 or Len(id) > 64 then return invalid
    parts = id.Split(":")
    if parts.Count() > 2 then return invalid
    for each part in parts
        if Len(part) = 0 or Len(part) > 9 then return invalid
        for i = 1 to Len(part)
            char = Mid(part,i,1)
            if char < "0" or char > "9" then return invalid
        end for
        if SafeInt(part) <= 0 then return invalid
    end for
    if kind = "movie" and parts.Count() <> 1 then return invalid
    if kind <> "movie" and parts.Count() <> 2 then return invalid
    episodeId = 0
    if parts.Count() = 2 then episodeId = SafeInt(parts[1])
    return {titleId:SafeInt(parts[0]),episodeId:episodeId,kind:kind}
end function

function StoreEpisodeIndex(link as Object, episodes as Object, saved as Dynamic) as Integer
    match = EpisodeIndex(episodes,link.episodeId)
    if match < 0 then return -1
    if link.kind <> "series" then return match
    if IsMap(saved) then
        previous = EpisodeIndex(episodes,SafeInt(saved.episodeId))
        if previous >= 0 then
            if not Truth(saved.completed) then return previous
            if previous + 1 < episodes.Count() then return previous + 1
        end if
    end if
    ' Ordered scripted series: start at the first regular season episode.
    for i = 0 to episodes.Count() - 1
        if SafeInt(episodes[i].season) > 0 then return i
    end for
    return 0
end function

function StoreCaptionVisible(mode as String, position as Float, replayUntil as Float) as Boolean
    if mode = "On" then return true
    if mode = "Instant replay" then return position < replayUntil
    ' Roku resolves When mute into On/Off via GetCaptionsMode().
    return false
end function

function ValidServiceSession(data as Dynamic) as Boolean
    if not IsMap(data) then return false
    if Type(data.success) <> "roBoolean" and Type(data.success) <> "Boolean" then return false
    if data.success <> true then return false
    if Type(data.token) <> "roString" and Type(data.token) <> "String" then return false
    if Len(data.token) <> 43 then return false
    for i = 1 to Len(data.token)
        c = Mid(data.token,i,1)
        if Instr(1,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-",c) = 0 then return false
    end for
    if Type(data.expiresIn) <> "roInt" and Type(data.expiresIn) <> "Integer" then return false
    return data.expiresIn >= 60 and data.expiresIn <= 900
end function

function SystemCaptionColor(name as String,opacity as String,fallback as String) as String
    colors = {white:"ffffff",black:"000000",red:"ff0000",green:"00ff00",blue:"0000ff",yellow:"ffff00",magenta:"ff00ff",cyan:"00ffff"}
    color = colors.Lookup(LCase(name))
    if color = invalid then color = Mid(fallback,3,6)
    alpha = Right(fallback,2)
    if opacity = "Off" or opacity = "0%" then alpha = "00"
    if opacity = "25%" then alpha = "40"
    if opacity = "50%" then alpha = "80"
    if opacity = "75%" then alpha = "bf"
    if opacity = "100%" then alpha = "ff"
    return "0x" + color + alpha
end function
