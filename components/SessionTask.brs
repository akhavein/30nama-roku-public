sub init()
    m.top.functionName = "runSession"
end sub
sub runSession()
    if Left(m.top.origin,8) <> "https://" then m.top.result = {success:false}: return
    req = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    req.SetMessagePort(port)
    req.SetUrl(m.top.origin + "/session")
    req.SetCertificatesFile("common:/certs/ca-bundle.crt")
    req.InitClientCertificates()
    req.AddHeader("Content-Type","application/json")
    req.SetRequest("POST")
    body = FormatJson({token:m.top.token,deviceId:m.top.deviceId})
    if m.top.revoke then
        req.SetRequest("DELETE")
        req.AddHeader("Authorization","Bearer " + m.top.token)
        body = ""
    end if
    m.top.token = ""
    if not req.AsyncPostFromString(body) then m.top.result = {success:false}: return
    event = Wait(10000,port)
    if event = invalid then req.AsyncCancel(): m.top.result = {success:false}: return
    if event.GetResponseCode() <> 200 then m.top.result = {success:false}: return
    raw = event.GetString()
    if Len(raw) > 2048 then m.top.result = {success:false}: return
    data = ParseJson(raw)
    if Type(data) = "roAssociativeArray" then m.top.result = data else m.top.result = {success:false}
end sub
