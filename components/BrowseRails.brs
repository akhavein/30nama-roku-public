function onKeyEvent(key as String,press as Boolean) as Boolean
    if not press then return false
    if key = "play" or (m.top.searchPaging and (key = "fastforward" or key = "rewind")) then
        m.top.shortcut = key
        return true
    end if
    return false
end function
