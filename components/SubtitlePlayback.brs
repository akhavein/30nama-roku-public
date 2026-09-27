sub ClearCustomCaptions()
    CancelRequest("captions")
    CancelRequest("subtitle-refresh")
    m.customCaptionEnabled = false
    m.captionCues = []
    m.captionIndex = invalid
    m.captionLayer.visible = false
    m.captionText.text = ""
    m.captionNotice.text = ""
end sub

function SidecarUrl(code as String) as String
    for each option in m.subtitleOptions
        if option.code = code then return option.track
    end for
    return ""
end function

sub LoadSidecarCaptions(code as String, refreshed = false as Boolean)
    ClearCustomCaptions()
    m.captionCode = code
    m.captionRefreshed = refreshed
    m.player.globalCaptionMode = "Off"
    url = SidecarUrl(code)
    if url = "" then
        m.captionNotice.text = "This language has no compatible subtitle file."
        return
    end if
    m.customCaptionEnabled = true
    if IsMap(m.captionCache) and m.captionCache.DoesExist(code) then
        m.captionCues = m.captionCache.Lookup(code)
        m.captionIndex = BuildCaptionIndex(m.captionCues)
        UpdateCustomCaption()
        return
    end if
    m.captionNotice.text = "Loading subtitles..."
    m.requestCounter = m.requestCounter + 1
    task = CreateObject("roSGNode","SubtitleTask")
    task.helperUrl = m.helperUrl
    task.helperToken = m.helperToken
    task.url = url
    task.generation = m.generation
    task.requestId = Text(m.requestCounter)
    task.observeField("result","OnCaptionResult")
    m.tasks.captions = task
    m.top.appendChild(task)
    task.control = "run"
end sub

sub RefreshCaptionMetadata(result as Dynamic)
    if m.page <> "player" or not m.customCaptionEnabled then return
    if IsMap(result) and Truth(result.success) and IsMap(result.result) then
        data = result.result
        subtitles = data.subtitle
        if m.episode <> invalid then
            episodes = FlattenEpisodes(data.list)
            index = EpisodeIndex(episodes,m.episode.id)
            if index >= 0 then subtitles = episodes[index].subtitle
        end if
        m.subtitleOptions = SubtitleOptions(subtitles)
        LoadSidecarCaptions(m.captionCode,true)
    else
        m.captionNotice.text = "Subtitles couldn't refresh. Select the language again to retry."
    end if
end sub

sub OnCaptionResult(event as Object)
    task = event.GetRoSGNode()
    active = m.tasks.Lookup("captions")
    if active = invalid then return
    if active.requestId <> task.requestId then return
    m.tasks.Delete("captions")
    m.top.removeChild(task)
    if m.page <> "player" or task.generation <> m.generation or not m.customCaptionEnabled then return
    result = task.result
    if IsMap(result) and Truth(result.success) then
        m.captionCues = result.cues
        m.captionIndex = BuildCaptionIndex(m.captionCues)
        m.captionCache[m.captionCode] = result.cues
        print "[30nama][captions] ready cues="; m.captionCues.Count()
        m.captionNotice.text = ""
        UpdateCustomCaption()
    else if IsMap(result) and (result.status = 410 or result.status = 403) and not m.captionRefreshed then
        m.captionRefreshed = true
        m.captionNotice.text = "Refreshing subtitles..."
        Request("subtitle-refresh","stream/id/" + Text(m.title.id),{})
    else
        m.captionNotice.text = "Subtitles couldn't load. Select the language again to retry."
    end if
end sub

sub UpdateCustomCaption()
    if m.scenePreview <> invalid then
        if m.scenePreview.visible then m.captionLayer.visible = false: return
    end if
    if not m.customCaptionEnabled then return
    seconds = m.player.position - SafeInt(m.captionOffset) / 1000.0
    if IsMap(m.captionIndex) then m.captionText.text = IndexedCaptionAt(m.captionIndex,seconds) else m.captionText.text = CaptionAt(m.captionCues,seconds)
    layout = CaptionLayout(m.captionText.text,SafeInt(m.captionSize,32))
    m.captionText.font.size = layout.size
    m.captionLayer.visible = m.captionText.text <> ""
    height = layout.height
    m.captionBackground.height = height
    m.captionText.height = height - 8
    m.captionBackground.color = CaptionContrast(Text(m.captionContrast))
    m.captionLayer.translation = [80,CaptionPlacement(height,Text(m.captionPosition),m.controls.visible)]
end sub
