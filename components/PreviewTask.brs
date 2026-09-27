sub init()
    m.top.functionName = "FetchPreview"
end sub
sub FetchPreview()
    req = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    req.SetMessagePort(port)
    req.SetCertificatesFile("common:/certs/ca-bundle.crt")
    req.InitClientCertificates()
    req.SetUrl(m.top.helperUrl + "/preview")
    req.AddHeader("Authorization","Bearer " + m.top.helperToken)
    req.AddHeader("Content-Type","application/json")
    result = {success:false}
    if req.AsyncPostFromString(FormatJson({url:m.top.url,seconds:m.top.seconds})) then
        event = Wait(11000,port)
        if event <> invalid then
            result.status = event.GetResponseCode()
            if event.GetResponseCode() = 200 then
                raw = event.GetString()
                if Len(raw) <= 140000 then
                    parsed = ParseJson(raw)
                    if Type(parsed) = "roAssociativeArray" then result = parsed
                end if
            end if
        end if
    end if
    req.AsyncCancel()
    m.top.result = result
end sub
