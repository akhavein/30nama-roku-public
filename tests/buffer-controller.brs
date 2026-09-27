sub Main()
    m.checks = 0
    m.closed = 0
    m.page = "home"
    m.status = {text:""}
    m.player = {state:"buffering"}
    OnBufferTimeout()
    Assert(m.closed = 0, "late buffer timer cannot close another page")
    m.page = "player"
    m.player.state = "playing"
    OnBufferTimeout()
    Assert(m.closed = 0, "recovered playback ignores stale buffer timer")
    m.player.state = "paused"
    OnBufferTimeout()
    Assert(m.closed = 0, "paused playback never times out")
    m.player.state = "buffering"
    OnBufferTimeout()
    Assert(m.closed = 1 and m.saved, "stalled stream closes through progress-preserving path")
    Assert(Instr(1,m.status.text,"retry") > 0, "stalled stream offers explicit retry")
    print "REGRESSION PASS: ";m.checks;" buffer controller assertions"
end sub
sub ClosePlayback(save)
    m.closed = m.closed + 1
    m.saved = save
end sub
sub Assert(condition as Boolean,label as String)
    if not condition then print "FAIL: ";label: stop
    m.checks = m.checks + 1
    print "PASS: ";label
end sub

function TryNextSource() as Boolean
    return false
end function

function RecoverPlayback() as Boolean
    return false
end function
