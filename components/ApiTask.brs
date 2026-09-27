sub init()
    m.top.functionName = "executeRequest"
end sub

sub executeRequest()
    timer = CreateObject("roTimespan")
    timer.Mark()
    print "[30nama][api] start id="; m.top.requestId; " action="; m.top.action
    req = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    req.SetMessagePort(port)
    req.SetUrl(m.top.base + "/" + m.top.action)
    if m.top.tag = "progress" then
        req.SetUrl(m.top.helperUrl + "/progress")
        if m.top.helperToken <> "" then req.AddHeader("Authorization","Bearer " + m.top.helperToken)
    end if
    req.SetRequest("POST")
    if m.top.tag = "helper-health" then
        req.SetUrl(m.top.helperUrl + "/health")
        req.SetRequest("GET")
        if m.top.helperToken <> "" then req.AddHeader("Authorization","Bearer " + m.top.helperToken)
    end if
    req.SetCertificatesFile("common:/certs/ca-bundle.crt")
    req.InitClientCertificates()
    req.AddHeader("Content-Type", "application/x-www-form-urlencoded")
    req.AddHeader("c-api-key", m.top.apiKey)
    req.AddHeader("c-app-version", m.top.version)
    req.AddHeader("c-language", m.top.language)
    req.AddHeader("c-platform", m.top.platform)
    req.AddHeader("c-useragent", "30nama Roku TV")
    if m.top.tag <> "helper-health" and m.top.token <> invalid and m.top.token <> "" then req.AddHeader("c-token", m.top.token)
    payload = m.top.payload
    body = ""
    if payload <> invalid then
        for each key in payload.Keys()
            if body <> "" then body = body + "&"
            body = body + req.Escape(key) + "=" + req.Escape(payload[key].ToStr())
        end for
    end if
    if m.top.tag = "progress" then
        req.AddHeader("Content-Type","application/json")
        body = FormatJson({apiKey:m.top.apiKey,token:m.top.token,progress:payload})
    end if
    attempts = 1
    timeout = 15000
    if m.top.tag = "search" or m.top.tag = "catalog" or m.top.tag = "detail" or m.top.tag = "stream" or m.top.tag = "next-prefetch" then attempts = 2: timeout = 6000
    if m.top.tag = "progress" then timeout = 22000
    raw = invalid
    for attempt = 1 to attempts
        raw = invalid
        m.top.httpStatus = 0
        started = false
        if m.top.tag = "helper-health" then started = req.AsyncGetToString() else started = req.AsyncPostFromString(body)
        if not started then exit for
        event = Wait(timeout, port)
        if event <> invalid then
            m.top.httpStatus = event.GetResponseCode()
            raw = event.GetString()
            if m.top.httpStatus >= 200 and m.top.httpStatus < 500 then exit for
        end if
        req.AsyncCancel()
        ' Cancelled transfer's port is drained before the bounded retry.
        while port.GetMessage() <> invalid
        end while
    end for
    m.top.elapsedMs = timer.TotalMilliseconds()
    if raw = invalid then
        req.AsyncCancel()
        m.top.httpStatus = 0
        print "[30nama][api] end id="; m.top.requestId; " action="; m.top.action; " status=no_response elapsed_ms="; m.top.elapsedMs
        m.top.result = {success:false, error:"no_response"}
        return
    end if
    if type(raw) = "Integer" then
        m.top.httpStatus = raw
        print "[30nama][api] end id="; m.top.requestId; " action="; m.top.action; " status="; raw; " elapsed_ms="; m.top.elapsedMs
        m.top.result = {success:false, error:"http_status", status:raw}
        return
    end if
    if m.top.httpStatus = 0 then m.top.httpStatus = 200
    if m.top.httpStatus < 200 or m.top.httpStatus >= 300 then
        print "[30nama][api] end id="; m.top.requestId; " status="; m.top.httpStatus; " elapsed_ms="; m.top.elapsedMs
        m.top.result = {success:false, error:"http_status", status:m.top.httpStatus}
        return
    end if
    parsed = ParseJson(raw)
    if m.top.tag = "helper-health" and GetInterface(parsed,"ifAssociativeArray") <> invalid then parsed.success = parsed.ok = true
    if GetInterface(parsed,"ifAssociativeArray") = invalid then
        print "[30nama][api] end id="; m.top.requestId; " action="; m.top.action; " status=invalid_json elapsed_ms="; m.top.elapsedMs
        m.top.result = {success:false, error:"invalid_json"}
    else
        successText = "invalid"
        if GetInterface(parsed.success,"ifToStr") <> invalid then successText = parsed.success.ToStr()
        print "[30nama][api] end id="; m.top.requestId; " action="; m.top.action; " status="; m.top.httpStatus; " success="; successText; " elapsed_ms="; m.top.elapsedMs
        m.top.result = parsed
    end if
end sub
