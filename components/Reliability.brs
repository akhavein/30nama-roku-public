sub ResetPlaybackSession()
    m.introSkipped = false
    m.refreshAttempts = 0
    m.recoveringStream = false
    m.recoveryPaused = false
    m.nextPrefetch = invalid
    m.prefetchAttempted = false
    m.playbackClock = CreateObject("roTimespan")
    m.playbackClock.Mark()
    m.startupMeasured = false
    m.playbackMetrics = {startupMs:0,recoveries:0,bufferEvents:0}
end sub

function RecoverPlayback() as Boolean
    if SafeInt(m.refreshAttempts) >= 1 or m.api.token = "" then return false
    m.refreshAttempts = SafeInt(m.refreshAttempts) + 1
    m.recoveryPaused = m.pauseAfterSeek = true or m.player.state = "paused"
    SavePlayback()
    ClosePlayback(false)
    m.recoveringStream = true
    m.startOver = false
    m.streamIntent = "play"
    if m.episode <> invalid then m.streamIntent = "episode": m.requestedEpisodeId = m.episode.id
    m.status.text = "Refreshing playback once. Your position is saved..."
    Request("stream","stream/id/" + Text(m.title.id),{})
    return true
end function

sub OnPlaybackHealth()
    if m.page <> "player" or m.nextPending = true then return
    if m.player.state <> "playing" then return
    if m.seekSettling = true or m.seekPending = true then return
    if m.advanceClock = invalid then return
    if m.advanceClock.TotalMilliseconds() < 20000 then return
    print "[30nama][recovery] no position advancement"
    if TryNextSource() then return
    if RecoverPlayback() then return
    ClosePlayback(true)
    m.status.text = "Playback stopped advancing. Your progress is saved. Press Play to retry."
end sub

sub OnSeekCommit()
    if m.page <> "player" or m.seekPending <> true then return
    m.seekPending = false
    m.seekSettling = true
    m.seekClock = CreateObject("roTimespan")
    m.seekClock.Mark()
    m.lastGoodPosition = m.seekTarget
    m.player.seek = m.seekTarget
    SavePlayback()
end sub

function CheckpointPosition() as Integer
    if m.seekPending = true or m.seekSettling = true then return SafeInt(m.seekTarget)
    position = SafeInt(m.player.position)
    if position < 5 and SafeInt(m.lastGoodPosition) >= 5 then return SafeInt(m.lastGoodPosition)
    return position
end function

sub OnAvailableAudio()
    if m.page <> "player" or m.pendingAudio <> true then return
    options = AudioOptions(m.player.availableAudioTracks)
    language = m.registry.Read("audio_language")
    description = m.registry.Read("audio_description") = "true"
    index = PreferredAudio(options,language,description)
    if index >= 0 then
        m.player.audioTrack = options[index].track
        m.pendingAudio = false
    end if
end sub

sub MaybePrefetchNext()
    if m.autoplay <> true or m.prefetchAttempted = true or m.playCompleted then return
    duration = SafeInt(m.player.duration)
    remaining = duration - SafeInt(m.player.position)
    if duration <= 0 or remaining > 60 or remaining < 0 then return
    if NextEpisode() = invalid then return
    m.prefetchAttempted = true
    Request("next-prefetch","stream/id/" + Text(m.title.id),{})
end sub

sub HandleNextPrefetch(result as Dynamic)
    if m.page <> "player" or not IsMap(result) or not Truth(result.success) then return
    if not IsMap(result.result) then return
    episodes = FlattenEpisodes(result.result.list)
    ep = NextEpisode()
    if ep = invalid then return
    index = EpisodeIndex(episodes,ep.id)
    if index < 0 then return
    m.nextPrefetch = {episode:episodes[index],saved:CreateObject("roDateTime").AsSeconds()}
    PrefetchNextCaption()
end sub

sub PrefetchNextCaption()
    code = m.registry.Read("subtitle_preference")
    if code <> "fa" and code <> "en" then return
    ep = m.nextPrefetch.episode
    url = ""
    for each option in SubtitleOptions(ep.subtitle)
        if option.code = code then url = option.track
    end for
    if url = "" then return
    m.requestCounter = m.requestCounter + 1
    task = CreateObject("roSGNode","SubtitleTask")
    task.helperUrl = m.helperUrl
    task.helperToken = m.helperToken
    task.url = url
    task.generation = m.generation
    task.requestId = Text(m.requestCounter)
    m.prefetchCaptionCode = code
    task.observeField("result","OnPrefetchedCaption")
    m.tasks["caption-prefetch"] = task
    m.top.appendChild(task)
    task.control = "run"
end sub

sub OnPrefetchedCaption(event as Object)
    task = event.GetRoSGNode()
    active = m.tasks.Lookup("caption-prefetch")
    if active = invalid then return
    if active.requestId <> task.requestId then return
    m.tasks.Delete("caption-prefetch")
    m.top.removeChild(task)
    if task.generation <> m.generation or m.page <> "player" then return
    if not IsMap(m.nextPrefetch) then return
    if IsMap(task.result) and Truth(task.result.success) then
        m.nextPrefetch.captionCode = m.prefetchCaptionCode
        m.nextPrefetch.cues = task.result.cues
    end if
end sub
