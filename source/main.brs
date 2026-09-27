sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    input = CreateObject("roInput")
    input.SetMessagePort(port)
    scene = screen.CreateScene("App")
    screen.Show()
    if Type(args) = "roAssociativeArray" then scene.launchArgs = args
    while true
        msg = Wait(0,port)
        if Type(msg) = "roSGScreenEvent" then
            if msg.IsScreenClosed() then return
        else if Type(msg) = "roInputEvent" then
            if msg.IsInput() then scene.launchArgs = msg.GetInfo()
        end if
    end while
end sub
