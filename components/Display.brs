' Use the bundled font only for text that needs it; preserve native typography
' for Latin UI labels. Shape display text, never the provider query or history.
function HasArabicText(value as String) as Boolean
    for i = 1 to Len(value)
        code = Asc(Mid(value,i,1))
        if code >= 1536 and code <= 1791 then return true
    end for
    return false
end function

function DisplayText(value as String) as String
    if HasArabicText(value) then return ArabicVisual(value)
    return value
end function

sub SetDisplayText(node as Object,value as String,size as Integer)
    if GetInterface(m.displayFonts,"ifAssociativeArray") = invalid then m.displayFonts = {}
    if not m.displayFonts.DoesExist(node.id) then m.displayFonts[node.id] = node.font
    if HasArabicText(value) then
        font = CreateObject("roSGNode","Font")
        font.uri = "pkg:/components/fonts/Caption-Regular.ttf"
        font.size = size
        node.font = font
    else
        node.font = m.displayFonts[node.id]
    end if
    node.text = DisplayText(value)
end sub
