' Pure transport policy shared by the Task and executable regression tests.
function ApiResponseLimit(tag as String) as Integer
    if Left(tag,5) = "easy-" or tag = "login" then return 32768
    if tag = "profile" then return 65536
    if tag = "helper-health" or tag = "progress" then return 8192
    if tag = "catalog" or tag = "remote-history" then return 2097152
    if tag = "stream" or tag = "next-prefetch" or tag = "search" then return 1048576
    return 262144
end function

function ApiMayRetry(tag as String, status as Integer) as Boolean
    readOnly = tag = "catalog" or tag = "search" or tag = "detail" or tag = "stream" or tag = "next-prefetch"
    return readOnly and (status <= 0 or status = 429 or status >= 500)
end function

function ApiRetryDelay(headers as Dynamic) as Integer
    delayMs = 1000
    if GetInterface(headers,"ifArray") = invalid then return delayMs
    for each header in headers
        if GetInterface(header,"ifAssociativeArray") <> invalid then
            for each key in header.Keys()
                if LCase(key) = "retry-after" then
                    value = header[key]
                    if GetInterface(value,"ifString") = invalid then return -1
                    value = value.Trim()
                    ' Dates/ambiguous or long waits are not shortened. Return the
                    ' response without an automatic retry rather than retry early.
                    if not CreateObject("roRegex","^[0-9]{1,5}$","").IsMatch(value) then return -1
                    seconds = value.ToInt()
                    if seconds > 10 then return -1
                    if seconds * 1000 > delayMs then delayMs = seconds * 1000
                end if
            end for
        end if
    end for
    return delayMs
end function

function ApiResponseTooLarge(tag as String, raw as Dynamic) as Boolean
    if GetInterface(raw,"ifString") = invalid then return false
    return Len(raw) > ApiResponseLimit(tag)
end function
