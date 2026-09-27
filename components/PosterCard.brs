sub init()
    m.art = m.top.findNode("art")
    m.title = m.top.findNode("title")
    m.placeholder = m.top.findNode("placeholder")
    m.progress = m.top.findNode("progress")
    m.progressBg = m.top.findNode("progressBg")
    m.frame = m.top.findNode("focusFrame")
end sub
sub onContent()
    item = m.top.itemContent
    if item = invalid then return
    m.art.uri = item.hdPosterUrl
    SetDisplayText(m.title,item.title,20)
    SetDisplayText(m.placeholder,item.title,20)
    ratio = item.progressRatio
    m.progress.width = 180 * ratio
    m.progressBg.visible = ratio > 0
end sub
sub onFocus()
    m.frame.opacity = m.top.focusPercent * m.top.rowFocusPercent
end sub
