sub init()
    m.top.functionName = "FetchSubtitles"
end sub
sub FetchSubtitles()
    req = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    req.SetMessagePort(port)
    req.SetCertificatesFile("common:/certs/ca-bundle.crt")
    req.InitClientCertificates()
    req.EnableEncodings(true)
    ' This provider requires a browser. Use the paired bridge first instead of
    ' depending on the CDN returning exactly 403 (it can also return empty 503).
    useHelper = CaptionHelperRoute(m.top.url,m.top.helperUrl)
    timeout = 15000
    if useHelper then
        req.SetUrl(m.top.helperUrl + "/subtitle")
        if m.top.helperToken <> "" then req.AddHeader("Authorization","Bearer " + m.top.helperToken)
        req.AddHeader("Content-Type","application/json")
        timeout = 25000
    else
        req.SetUrl(m.top.url)
    end if
    status = 0
    raw = ""
    for attempt = 1 to 2
        started = false
        if useHelper then started = req.AsyncPostFromString(FormatJson({url:m.top.url})) else started = req.AsyncGetToString()
        status = 0
        raw = ""
        if started then
            event = Wait(timeout,port)
            if event <> invalid then status = event.GetResponseCode(): raw = event.GetString()
        end if
        if not CaptionRetryable(status) or attempt = 2 then exit for
        req.AsyncCancel()
        while port.GetMessage() <> invalid
        end while
        Sleep(500)
    end for
    req.AsyncCancel()
    print "[30nama][captions] fetch status="; status; " bytes="; Len(raw)
    if status < 200 or status >= 300 then m.top.result = {success:false,status:status}: return
    cues = ParseCaptions(raw,true)
    print "[30nama][captions] parsed cues="; cues.Count()
    m.top.result = {success:cues.Count() > 0,cues:cues,status:status}
end sub
