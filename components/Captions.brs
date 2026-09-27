' UTF-8 sidecar subtitles and Arabic/Persian visual shaping for Roku's LTR label renderer.
function CaptionTime(raw as String) as Float
    value = raw.Trim().Replace(",", ".")
    valid = CreateObject("roRegex", "^([0-9]{1,3}:)?[0-9]{1,2}:[0-9]{2}([.][0-9]{1,3})?$", "")
    if not valid.IsMatch(value) then return -1.0
    parts = value.Split(":")
    if parts.Count() < 2 or parts.Count() > 3 then return -1.0
    seconds = Val(parts[parts.Count()-1])
    minutes = Val(parts[parts.Count()-2])
    hours = 0
    if parts.Count() = 3 then hours = Val(parts[0])
    if seconds < 0 or seconds >= 60 or minutes < 0 or minutes >= 60 then return -1.0
    return hours * 3600 + minutes * 60 + seconds + 0.0
end function

function ParseCaptions(raw as String, rtl as Boolean) as Object
    cues = []
    if Len(raw) > 4000000 then return cues
    raw = raw.Replace(Chr(13), "").Replace(Chr(65279), "")
    blocks = raw.Split(Chr(10) + Chr(10))
    stripTags = CreateObject("roRegex", "<[^>]*>", "")
    for each block in blocks
        lines = block.Split(Chr(10))
        for i = 0 to lines.Count() - 1
            arrow = Instr(1,lines[i],"-->")
            if arrow > 0 then
                times = lines[i].Split("-->")
                startTime = CaptionTime(times[0])
                ending = times[1].Trim().Split(" ")[0]
                endTime = CaptionTime(ending)
                caption = ""
                for j = i + 1 to lines.Count() - 1
                    line = stripTags.ReplaceAll(lines[j], "")
                    line = line.Replace("&amp;","&").Replace("&lt;","<").Replace("&gt;",">").Replace("&nbsp;"," ")
                    if rtl then line = CaptionVisualLine(line)
                    if caption <> "" then caption = caption + Chr(10)
                    caption = caption + line
                end for
                caption = caption.Trim()
                if startTime >= 0 and endTime > startTime and caption <> "" then
                    cues.Push({start:startTime,finish:endTime,text:caption})
                    if cues.Count() >= 10000 then return cues
                end if
                exit for
            end if
        end for
    end for
    return cues
end function

function CaptionAt(cues as Object, seconds as Float) as String
    result = ""
    for each cue in cues
        if cue.start <= seconds and seconds < cue.finish then
            if result <> "" then result = result + Chr(10)
            result = result + cue.text
        end if
    end for
    return result
end function

' Bucket once on load, not a full-film scan on every 250 ms position event.
' Preserve input ordering and overlapping cues, including seeks backwards.
function BuildCaptionIndex(cues as Object) as Object
    index = {buckets:{},long:[],all:cues}
    for each cue in cues
        first = Int(cue.start / 60)
        last = Int(cue.finish / 60)
        if last - first > 120 then
            index.long.Push(cue)
        else
            for bucket = first to last
                key = bucket.ToStr().Trim()
                if not index.buckets.DoesExist(key) then index.buckets[key] = []
                index.buckets[key].Push(cue)
            end for
        end if
    end for
    return index
end function

function IndexedCaptionAt(index as Object,seconds as Float) as String
    if index.long.Count() > 0 then return CaptionAt(index.all,seconds)
    key = Int(seconds / 60).ToStr().Trim()
    result = ""
    if index.buckets.DoesExist(key) then result = CaptionAt(index.buckets[key],seconds)
    extra = CaptionAt(index.long,seconds)
    if extra <> "" then
        if result <> "" then result = result + Chr(10)
        result = result + extra
    end if
    return result
end function

function ArabicMark(code as Integer) as Boolean
    return (code >= 1552 and code <= 1562) or (code >= 1611 and code <= 1631) or code = 1648 or (code >= 1750 and code <= 1773)
end function

function ArabicVisual(raw as String) as String
    if m.arabicForms = invalid then m.arabicForms = ArabicForms()
    chars = []
    for i = 1 to Len(raw)
        chars.Push(Mid(raw,i,1))
    end for
    shaped = []
    i = 0
    while i < chars.Count()
        code = Asc(chars[i])
        forms = m.arabicForms.Lookup(code.ToStr().Trim())
        if forms <> invalid then
            before = i - 1
            while before >= 0
                if not ArabicMark(Asc(chars[before])) and Asc(chars[before]) <> 8205 then exit while
                before = before - 1
            end while
            after = i + 1
            while after < chars.Count()
                if not ArabicMark(Asc(chars[after])) and Asc(chars[after]) <> 8205 then exit while
                after = after + 1
            end while
            previous = invalid
            following = invalid
            if before >= 0 then previous = m.arabicForms.Lookup(Asc(chars[before]).ToStr().Trim())
            if after < chars.Count() then following = m.arabicForms.Lookup(Asc(chars[after]).ToStr().Trim())
            joinBefore = false
            joinAfter = false
            if previous <> invalid then joinBefore = previous[2] > 0 and forms[1] > 0
            if following <> invalid then joinAfter = forms[2] > 0 and following[1] > 0
            slot = 0
            if joinBefore then slot = 1
            if joinAfter then slot = 2
            if joinBefore and joinAfter then slot = 3
            glyph = forms[slot]
            ' Lam-alef ligatures; preserve surrounding joining behavior.
            if code = 1604 and after = i + 1 and after < chars.Count() then
                alef = Asc(chars[after])
                ligature = 0
                if alef = 1570 then ligature = 65269
                if alef = 1571 then ligature = 65271
                if alef = 1573 then ligature = 65273
                if alef = 1575 then ligature = 65275
                if ligature > 0 then
                    glyph = ligature
                    if joinBefore then glyph = glyph + 1
                    i = i + 1
                end if
            end if
            shaped.Push(Chr(glyph))
        else if code <> 8204 and code <> 8205 and code <> 8206 and code <> 8207 and not (code >= 8234 and code <= 8238) and not (code >= 8294 and code <= 8297) then
            shaped.Push(chars[i])
        end if
        i = i + 1
    end while
    directions = []
    hasRtl = false
    for each char in shaped
        code = Asc(char)
        direction = "N"
        if (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or (code >= 1632 and code <= 1641) or (code >= 1776 and code <= 1785) then direction = "L"
        if (code >= 1536 and code <= 1791 and direction <> "L") or (code >= 64336 and code <= 65279) then direction = "R": hasRtl = true
        directions.Push(direction)
    end for
    if not hasRtl then return raw
    paragraph = "R"
    for j = 0 to shaped.Count() - 1
        code = Asc(shaped[j])
        if directions[j] = "R" then exit for
        if (code >= 65 and code <= 90) or (code >= 97 and code <= 122) then paragraph = "L": exit for
    end for
    for j = 0 to directions.Count() - 1
        if directions[j] = "N" then
            leftDir = paragraph
            rightDir = paragraph
            k = j - 1
            while k >= 0
                if directions[k] <> "N" then leftDir = directions[k]: exit while
                k = k - 1
            end while
            k = j + 1
            while k < directions.Count()
                if directions[k] <> "N" then rightDir = directions[k]: exit while
                k = k + 1
            end while
            if leftDir = rightDir then directions[j] = leftDir else directions[j] = paragraph
        end if
    end for
    runs = []
    segment = ""
    direction = "R"
    for j = 0 to shaped.Count() - 1
        if directions[j] <> direction and segment <> "" then runs.Push({text:segment,dir:direction}): segment = ""
        direction = directions[j]
        segment = segment + shaped[j]
    end for
    if segment <> "" then runs.Push({text:segment,dir:direction})
    visual = ""
    for stepIndex = 0 to runs.Count() - 1
        j = stepIndex
        if paragraph = "R" then j = runs.Count() - 1 - stepIndex
        runText = runs[j].text
        if runs[j].dir = "R" then runText = ReverseArabicRun(runText)
        visual = visual + runText
    end for
    return visual
end function

function ReverseArabicRun(raw as String) as String
    visual = ""
    cluster = ""
    for i = 1 to Len(raw)
        char = Mid(raw,i,1)
        code = Asc(char)
        if ArabicMark(code) then
            cluster = cluster + char
        else
            visual = cluster + visual
            if char = "(" then char = ")" else if char = ")" then char = "("
            if char = "[" then char = "]" else if char = "]" then char = "["
            cluster = char
        end if
    end for
    return cluster + visual
end function

function ArabicForms() as Object
    return {
        "1569":[65152, 0, 0, 0],
        "1570":[65153, 65154, 0, 0],
        "1571":[65155, 65156, 0, 0],
        "1572":[65157, 65158, 0, 0],
        "1573":[65159, 65160, 0, 0],
        "1574":[65161, 65162, 65163, 65164],
        "1575":[65165, 65166, 0, 0],
        "1576":[65167, 65168, 65169, 65170],
        "1577":[65171, 65172, 0, 0],
        "1578":[65173, 65174, 65175, 65176],
        "1579":[65177, 65178, 65179, 65180],
        "1580":[65181, 65182, 65183, 65184],
        "1581":[65185, 65186, 65187, 65188],
        "1582":[65189, 65190, 65191, 65192],
        "1583":[65193, 65194, 0, 0],
        "1584":[65195, 65196, 0, 0],
        "1585":[65197, 65198, 0, 0],
        "1586":[65199, 65200, 0, 0],
        "1587":[65201, 65202, 65203, 65204],
        "1588":[65205, 65206, 65207, 65208],
        "1589":[65209, 65210, 65211, 65212],
        "1590":[65213, 65214, 65215, 65216],
        "1591":[65217, 65218, 65219, 65220],
        "1592":[65221, 65222, 65223, 65224],
        "1593":[65225, 65226, 65227, 65228],
        "1594":[65229, 65230, 65231, 65232],
        "1601":[65233, 65234, 65235, 65236],
        "1602":[65237, 65238, 65239, 65240],
        "1603":[65241, 65242, 65243, 65244],
        "1604":[65245, 65246, 65247, 65248],
        "1605":[65249, 65250, 65251, 65252],
        "1606":[65253, 65254, 65255, 65256],
        "1607":[65257, 65258, 65259, 65260],
        "1608":[65261, 65262, 0, 0],
        "1609":[65263, 65264, 64488, 64489],
        "1610":[65265, 65266, 65267, 65268],
        "1649":[64336, 64337, 0, 0],
        "1655":[64477, 0, 0, 0],
        "1657":[64358, 64359, 64360, 64361],
        "1658":[64350, 64351, 64352, 64353],
        "1659":[64338, 64339, 64340, 64341],
        "1662":[64342, 64343, 64344, 64345],
        "1663":[64354, 64355, 64356, 64357],
        "1664":[64346, 64347, 64348, 64349],
        "1667":[64374, 64375, 64376, 64377],
        "1668":[64370, 64371, 64372, 64373],
        "1670":[64378, 64379, 64380, 64381],
        "1671":[64382, 64383, 64384, 64385],
        "1672":[64392, 64393, 0, 0],
        "1676":[64388, 64389, 0, 0],
        "1677":[64386, 64387, 0, 0],
        "1678":[64390, 64391, 0, 0],
        "1681":[64396, 64397, 0, 0],
        "1688":[64394, 64395, 0, 0],
        "1700":[64362, 64363, 64364, 64365],
        "1702":[64366, 64367, 64368, 64369],
        "1705":[64398, 64399, 64400, 64401],
        "1709":[64467, 64468, 64469, 64470],
        "1711":[64402, 64403, 64404, 64405],
        "1713":[64410, 64411, 64412, 64413],
        "1715":[64406, 64407, 64408, 64409],
        "1722":[64414, 64415, 0, 0],
        "1723":[64416, 64417, 64418, 64419],
        "1726":[64426, 64427, 64428, 64429],
        "1728":[64420, 64421, 0, 0],
        "1729":[64422, 64423, 64424, 64425],
        "1733":[64480, 64481, 0, 0],
        "1734":[64473, 64474, 0, 0],
        "1735":[64471, 64472, 0, 0],
        "1736":[64475, 64476, 0, 0],
        "1737":[64482, 64483, 0, 0],
        "1739":[64478, 64479, 0, 0],
        "1740":[64508, 64509, 64510, 64511],
        "1744":[64484, 64485, 64486, 64487],
        "1746":[64430, 64431, 0, 0],
        "1747":[64432, 64433, 0, 0],
    }
end function

function CaptionVisualLine(raw as String) as String
    output = ""
    logical = ""
    for each word in raw.Split(" ")
        if Len(logical) + Len(word) > 54 and logical <> "" then
            if output <> "" then output = output + Chr(10)
            output = output + ArabicVisual(logical)
            logical = ""
        end if
        if logical <> "" then logical = logical + " "
        logical = logical + word
    end for
    if logical <> "" then
        if output <> "" then output = output + Chr(10)
        output = output + ArabicVisual(logical)
    end if
    return output
end function

function CaptionHelperRoute(url as String,helper as String) as Boolean
    return helper <> "" and Left(url,28) = "https://subtitle.30nama.com/"
end function

function CaptionRetryable(status as Integer) as Boolean
    return status <= 0 or status = 408 or (status >= 500 and status <= 599)
end function
