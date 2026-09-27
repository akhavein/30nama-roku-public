sub Main()
    m.checks = 0
    m.api = {token:"fixture"}
    m.title = {id:100}
    m.episode = {id:12}
    m.status = {}
    m.player = {state:"paused"}
    m.requests = 0
    m.saves = 0
    m.closes = 0
    ResetPlaybackSession()
    Assert(RecoverPlayback(),"failed source allows one fresh metadata recovery")
    Assert(m.saves=1 and m.recoveryPaused and m.requestedEpisodeId=12,"recovery preserves pause, checkpoint and episode identity")
    Assert(not RecoverPlayback() and m.requests=1,"metadata recovery cannot loop")
    m.refreshAttempts=0
    m.api.token=""
    Assert(not RecoverPlayback(),"expired login is not retried as a media failure")
    m.api.token="fixture"
    m.page="player"
    m.nextPending=false
    m.seekPending=false
    m.seekSettling=false
    m.advanceClock={elapsed:21000,TotalMilliseconds:function()
        return m.elapsed
    end function}
    before=m.closes
    OnPlaybackHealth()
    Assert(m.closes=before,"intentional pause never triggers stall recovery")
    m.player.state="playing"
    m.advanceClock.elapsed=1000
    OnPlaybackHealth()
    Assert(m.closes=before,"advancing playback never triggers stall recovery")
    m.advanceClock.elapsed=21000
    m.seekSettling=true
    OnPlaybackHealth()
    Assert(m.closes=before,"pending seek has its own timeout, not a false stall")
    m.seekSettling=false
    m.canFallback=true
    OnPlaybackHealth()
    Assert(m.closes=before,"stall tries compatible fallback before metadata refresh")
    m.canFallback=false
    m.refreshAttempts=1
    OnPlaybackHealth()
    Assert(m.closes=before+1 and Instr(1,m.status.text,"saved")>0,"exhausted recovery returns an actionable saved-progress message")
    m.page="player"
    m.nextPrefetch=invalid
    m.registry={Read:function(key)
        if key="audio_language" then return "en"
        if key="audio_description" then return "false"
        return "off"
    end function}
    HandleNextPrefetch({success:true,result:{list:{"1":[{data:{id:13,season:1,number:3}}]}}})
    Assert(m.nextPrefetch=invalid,"prefetch cannot substitute the wrong episode")
    HandleNextPrefetch({success:true,result:{list:{"1":[{data:{id:12,season:1,number:2},file:{url:"https://example.test/a.m3u8"}}]}}})
    Assert(m.nextPrefetch.episode.id=12,"prefetch retains exact next episode only")
    m.pendingAudio=true
    m.player.availableAudioTracks=[{Track:"new-track-id",Language:"eng"}]
    OnAvailableAudio()
    Assert(m.player.audioTrack="new-track-id" and not m.pendingAudio,"audio preference resolves newly assigned track IDs")
    print "REGRESSION PASS: ";m.checks;" reliability assertions"
end sub
sub Assert(ok as Boolean,label as String)
    if not ok then print "FAIL: ";label:stop
    m.checks=m.checks+1
    print "PASS: ";label
end sub
sub SavePlayback()
    m.saves=m.saves+1
end sub
sub ClosePlayback(save)
    m.closes=m.closes+1
end sub
sub Request(tag,action,payload)
    m.requests=m.requests+1
end sub
function TryNextSource() as Boolean
    return m.canFallback=true
end function
function NextEpisode() as Dynamic
    return {id:12}
end function
