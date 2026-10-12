sub Main()
    m.checks = 0
    for each tag in ["cloud-write","login","easy-code","easy-poll","easy-verify","progress","fixture"]
        for each status in [0,-28,429,503]
            Assert(not ApiMayRetry(tag,status),"mutations/approval/controller-managed operations never transport-retry")
        end for
    end for
    for each tag in ["catalog","search","detail","stream","next-prefetch"]
        Assert(ApiMayRetry(tag,-28) and ApiMayRetry(tag,429) and ApiMayRetry(tag,503),"known reads retry transient transport failures")
        Assert(not ApiMayRetry(tag,200) and not ApiMayRetry(tag,401) and not ApiMayRetry(tag,403),"successful/auth/denied reads never retry")
    end for
    Assert(ApiRetryDelay(invalid) = 1000,"missing headers use bounded backoff")
    Assert(ApiRetryDelay([{ "Retry-After":"3" }]) = 3000,"numeric Retry-After honored")
    Assert(ApiRetryDelay([{ "retry-after":"0" }]) = 1000,"zero delay retains minimum spacing")
    Assert(ApiRetryDelay([{ "retry-after":"2" },{ "RETRY-AFTER":"10" }]) = 10000,"duplicate headers take longest supported delay")
    for each value in ["11","99999999999999999999","-1","1.5","Wed, 21 Oct 2026 07:28:00 GMT","junk"]
        Assert(ApiRetryDelay([{ "Retry-After":value }]) = -1,"long or ambiguous Retry-After never causes an early automatic retry")
    end for
    Assert(ApiRetryDelay([{ "Retry-After":{} }]) = -1,"malformed header cannot crash retry policy")
    Assert(not ApiResponseTooLarge("easy-verify",String(32768,"x")),"exact response ceiling is accepted")
    Assert(ApiResponseTooLarge("easy-verify",String(32769,"x")),"oversized auth response rejected before JSON parsing")
    Assert(ApiResponseTooLarge("helper-health",String(8193,"x")),"helper responses have a smaller ceiling")
    Assert(ApiResponseLimit("catalog") > ApiResponseLimit("profile"),"catalog and profile ceilings reflect payload size")
    Assert(not ApiResponseTooLarge("profile",invalid),"missing transport body handled separately")
    print "REGRESSION PASS: ";m.checks;" API policy assertions"
end sub
sub Assert(ok as Boolean,label as String)
    if not ok then print "FAIL: ";label: stop
    m.checks = m.checks + 1
end sub
