' Provider device linking for sideload builds. No passwords or third-party QR services.
function EasyLoginCode(result as Dynamic) as String
    if not IsMap(result) then return ""
    if not Truth(result.success) or not IsMap(result.result) then return ""
    code = Text(result.result.code)
    if not CreateObject("roRegex","^[A-Za-z0-9_-]{4,32}$","").IsMatch(code) then return ""
    if Text(result.result.url) <> "https://30nama.com/auth/" + code then return ""
    return code
end function

function EasyLoginToken(result as Dynamic) as String
    if not IsMap(result) then return ""
    if not Truth(result.success) or not IsMap(result.result) then return ""
    token = Text(result.result.usertoken)
    if Len(token) < 1 or Len(token) > 8192 then return ""
    return token
end function

sub ShowEasyLogin()
    if m.keyboard <> invalid then CloseKeyboard()
    EnterPage("easy-login","Sign in with your phone")
    m.easyPanel.visible = true
    m.easyButtons.content = MakeLabels(["Get a new code","Cancel"])
    m.easyButtons.jumpToItem = 1
    m.easyButtons.setFocus(true)
    m.hint.text = "Back cancels • Approve only the code shown on your TV"
    m.status.text = "Creating a secure sign-in code..."
    m.easyCode.text = ""
    m.easyCountdown.text = ""
    m.easyQr.uri = ""
    m.easySerial = SafeInt(m.easySerial) + 1
    m.easyClock = CreateObject("roTimespan")
    m.easyClock.Mark()
    m.easyState = {phase:"creating",code:"",nextPollMs:5000,failures:0}
    m.easyTimer.control = "start"
    Request("easy-code","qrcode/",{})
end sub

sub StopEasyLogin()
    if m.easyTimer <> invalid then m.easyTimer.control = "stop"
    if m.tasks <> invalid then
        for each tag in ["easy-code","easy-poll","easy-verify"]
            CancelRequest(tag)
        end for
    end if
    if m.easyQrTask <> invalid then
        m.easyQrTask.unobserveField("result")
        m.easyQrTask.control = "stop"
        m.top.removeChild(m.easyQrTask)
        m.easyQrTask = invalid
    end if
    if m.easyQr <> invalid then m.easyQr.uri = ""
    if Text(m.easyQrFile) <> "" then DeleteFile(m.easyQrFile)
    m.easyQrFile = ""
    m.easyCandidate = ""
    m.easyState = invalid
    m.easyClock = invalid
    if m.easyPanel <> invalid then m.easyPanel.visible = false
end sub

sub EasyLoginFailure(message as String)
    StopEasyLogin()
    m.easyPanel.visible = true
    m.easyCode.text = ""
    m.easyCountdown.text = ""
    m.status.text = message
    m.easyButtons.jumpToItem = 0
    m.easyButtons.setFocus(true)
end sub

sub OnEasyLoginButton()
    if m.easyButtons.itemSelected = 0 then
        ShowEasyLogin()
    else
        m.pendingStoreLink = invalid
        ShowAccount()
        QueueStoreRendered()
    end if
end sub

sub OnEasyLoginTick()
    if m.page <> "easy-login" or not IsMap(m.easyState) then return
    elapsed = m.easyClock.TotalMilliseconds()
    if elapsed >= 300000 then
        EasyLoginFailure("Code expired. Choose Get a new code to try again.")
        return
    end if
    remaining = Int((300000 - elapsed) / 1000)
    seconds = Text(remaining mod 60)
    if Len(seconds) = 1 then seconds = "0" + seconds
    m.easyCountdown.text = "Time left: " + Text(Int(remaining / 60)) + ":" + seconds
    if elapsed < m.easyState.nextPollMs then return
    if m.easyState.phase = "verify-wait" then
        if m.tasks.DoesExist("easy-verify") then return
        m.easyState.phase = "verifying"
        Request("easy-verify","user",{})
        return
    end if
    if m.easyState.phase <> "waiting" then return
    if m.tasks.DoesExist("easy-poll") then return
    m.easyState.nextPollMs = elapsed + 5000
    Request("easy-poll","qrlogin/code/" + m.easyState.code,{})
end sub

sub HandleEasyLogin(tag as String, result as Dynamic, httpStatus as Integer)
    if m.page <> "easy-login" or not IsMap(m.easyState) then return
    if m.easyClock.TotalMilliseconds() >= 300000 then
        EasyLoginFailure("Code expired. Choose Get a new code to try again.")
        return
    end if
    if tag = "easy-code" then
        if m.easyState.phase <> "creating" then return
        code = EasyLoginCode(result)
        if code = "" or httpStatus < 200 or httpStatus >= 300 then
            EasyLoginFailure("Couldn't create a code. Check your connection and try again.")
            return
        end if
        m.easyState.code = code
        m.easyState.phase = "waiting"
        m.easyState.nextPollMs = m.easyClock.TotalMilliseconds() + 5000
        m.easyCode.text = code
        m.status.text = "Scan the QR code, sign in on your phone, and approve this TV."
        StartEasyQr(code)
    else if tag = "easy-poll" then
        if m.easyState.phase <> "waiting" then return
        token = EasyLoginToken(result)
        if token <> "" and httpStatus >= 200 and httpStatus < 300 then
            m.easyCandidate = token
            m.easyState.verifyFailures = 0
            m.easyState.phase = "verifying"
            m.status.text = "Approved. Verifying your account..."
            Request("easy-verify","user",{})
        else if httpStatus = 403 then
            EasyLoginFailure("Sign-in service denied the request. Try again later; your existing account is unchanged.")
        else if httpStatus = 401 or httpStatus = 404 or httpStatus = 410 then
            EasyLoginFailure("This code is no longer available. Get a new code.")
        else if httpStatus <= 0 or httpStatus = 429 or httpStatus >= 500 then
            m.easyState.failures = m.easyState.failures + 1
            delay = 5000 * (m.easyState.failures + 1)
            if delay > 30000 then delay = 30000
            m.easyState.nextPollMs = m.easyClock.TotalMilliseconds() + delay
            m.status.text = "Connection interrupted. Retrying until this code expires..."
        else
            if httpStatus < 200 or httpStatus >= 300 or not IsMap(result) then
                EasyLoginFailure("Couldn't read the sign-in response. Get a new code to try again.")
                return
            end if
            if Truth(result.success) or Text(result.error) = "invalid_json" then
                EasyLoginFailure("Couldn't read the sign-in response. Get a new code to try again.")
                return
            end if
            ' Provider returns success:false while waiting for approval; not a login failure.
            m.easyState.failures = 0
            m.easyState.nextPollMs = m.easyClock.TotalMilliseconds() + 5000
            m.status.text = "Waiting for approval on your phone..."
        end if
    else if tag = "easy-verify" then
        if m.easyState.phase <> "verifying" then return
        if httpStatus <= 0 or httpStatus = 429 or httpStatus >= 500 then
            m.easyState.verifyFailures = SafeInt(m.easyState.verifyFailures) + 1
            if m.easyState.verifyFailures <= 3 then
                m.easyState.phase = "verify-wait"
                m.easyState.nextPollMs = m.easyClock.TotalMilliseconds() + 5000 * m.easyState.verifyFailures
                m.status.text = "Approved. Connection interrupted; retrying account verification..."
                return
            end if
        end if
        valid = false
        if IsMap(result) and httpStatus >= 200 and httpStatus < 300 then
            if Truth(result.success) and IsMap(result.result) then valid = SafeInt(result.result.userid) > 0
        end if
        if not valid then
            EasyLoginFailure("Couldn't verify the account. Get a new code to try again.")
            return
        end if
        token = m.easyCandidate
        owner = Text(result.result.userid)
        StopEasyLogin()
        InvalidateSessionRequests()
        previousOwner = m.registry.Read("account_owner")
        if previousOwner <> "" and previousOwner <> owner then ClearLocalViewingData()
        m.api.token = token
        m.userId = SafeInt(result.result.userid)
        m.syncToken = token
        m.registry.Write("session_token",token)
        m.registry.Write("account_owner",owner)
        m.registry.Flush()
        ShowAccount()
        m.status.text = "Signed in successfully"
        ReportStoreAuthentication()
        EnsureManagedSession()
        LoadRemoteHistory()
        ResumeStoreLink()
    end if
end sub

sub OnEasyQrReady(event as Object)
    task = event.GetRoSGNode()
    if m.easyQrTask = invalid then return
    if task.serial <> m.easySerial or m.page <> "easy-login" then return
    if IsMap(task.result) and Truth(task.result.ok) then
        ' Preserve integer module sizes; no interpolation of the QR bitmap.
        m.easyQr.width = task.result.side
        m.easyQr.height = task.result.side
        m.easyQr.uri = task.result.path
    end if
    task.unobserveField("result")
    m.top.removeChild(task)
    m.easyQrTask = invalid
end sub

sub StartEasyQr(code as String)
    m.easyQrFile = "tmp:/easy-login-" + Text(m.easySerial) + ".png"
    task = CreateObject("roSGNode","EasyQrTask")
    task.text = "https://30nama.com/auth/" + code
    task.path = m.easyQrFile
    task.serial = m.easySerial
    task.observeField("result","OnEasyQrReady")
    m.easyQrTask = task
    m.top.appendChild(task)
    task.control = "run"
end sub

function ProviderRequestToken(tag as String, currentToken as String, candidate as Dynamic) as String
    if tag = "easy-code" or tag = "easy-poll" then return ""
    if tag = "easy-verify" then return Text(candidate)
    return currentToken
end function
