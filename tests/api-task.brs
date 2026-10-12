sub Main()
    m.checks = 0
    ResetTransport("search",[Reply(503,"",[{"Retry-After":"3"}]),Reply(200,"{""success"":true}")])
    executeRequest()
    Assert(m.transfer.starts = 2 and m.sleeps[0] = 3000 and m.top.result.success,"read retries 503 after server delay and returns successful result")
    ResetTransport("search",[Reply(429,"",[{"Retry-After":"11"}])])
    executeRequest()
    Assert(m.transfer.starts = 1 and m.top.httpStatus = 429 and m.sleeps.Count() = 0,"long rate-limit delay ends without an early retry")
    ResetTransport("cloud-write",[Reply(503,"{}")])
    executeRequest()
    Assert(m.transfer.starts = 1 and m.top.result.success = false,"Watchlist mutation is never retransmitted on failure")
    ResetTransport("profile",[Reply(200,String(65537,"x"))])
    executeRequest()
    Assert(m.top.result.error = "response_too_large" and m.transfer.starts = 1,"oversized profile is rejected before parsing without retry")
    ResetTransport("search",[invalid,Reply(200,"{""success"":true}")])
    executeRequest()
    Assert(m.transfer.starts = 2 and m.sleeps[0] = 1000,"timeout retries a read with a nonzero delay")
    ResetTransport("search",[Reply(403,"{""success"":true}")])
    executeRequest()
    Assert(m.transfer.starts = 1 and not m.top.result.success and m.top.httpStatus = 403,"challenge denial cannot become success or trigger retries")
    ResetTransport("search",[Reply(0,"{""success"":true}"),Reply(0,"{""success"":true}")])
    executeRequest()
    Assert(not m.top.result.success and m.top.httpStatus = 0,"zero transport status is never invented as HTTP 200")
    ResetTransport("search",[Reply(200,"not json")])
    executeRequest()
    Assert(m.top.result.error = "invalid_json" and m.transfer.starts = 1,"invalid JSON fails without replay")
    ResetTransport("search",[])
    m.top.payload = {query:String(16385,"x")}
    executeRequest()
    Assert(m.transfer.starts = 0 and m.top.result.error = "request_too_large","oversized outgoing body never reaches transport")
    print "REGRESSION PASS: ";m.checks;" API Task assertions"
end sub
sub ResetTransport(tag as String,responses as Object)
    m.responses = responses: m.sleeps = []
    m.top = {tag:tag,action:"fixture",base:"https://provider.example.test",token:"",payload:{},requestId:"synthetic",apiKey:"fixture-key",version:"1",platform:"fixture",language:"en"}
    m.transfer = {starts:0,SetMessagePort:sub(port)
    end sub,SetUrl:sub(url)
    end sub,SetRequest:sub(method)
    end sub,SetCertificatesFile:sub(path)
    end sub,InitClientCertificates:sub()
    end sub,AddHeader:sub(key,value)
    end sub,Escape:function(value)
        return value
    end function,AsyncPostFromString:function(body)
        m.starts = m.starts + 1
        return true
    end function,AsyncGetToString:function()
        m.starts = m.starts + 1
        return true
    end function,AsyncCancel:sub()
    end sub}
end sub
function FakeTransfer() as Object
    return m.transfer
end function
function FakePort() as Object
    return {GetMessage:function()
        return invalid
    end function}
end function
function FakeClock() as Object
    return {Mark:sub()
    end sub,TotalMilliseconds:function()
        return 100
    end function}
end function
function FakeWait(timeout as Integer,port as Object) as Dynamic
    return m.responses.Shift()
end function
sub FakeSleep(delayMs as Integer)
    m.sleeps.Push(delayMs)
end sub
function Reply(status as Integer,body as String,headers = invalid as Dynamic) as Object
    return {status:status,body:body,headers:headers,GetResponseCode:function()
        return m.status
    end function,GetString:function()
        return m.body
    end function,GetResponseHeadersArray:function()
        return m.headers
    end function}
end function
sub Assert(ok as Boolean,label as String)
    if not ok then print "FAIL: ";label: stop
    m.checks = m.checks + 1
end sub
