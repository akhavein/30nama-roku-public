sub init()
    m.top.functionName = "GenerateEasyQr"
end sub

sub GenerateEasyQr()
    ' Only bounded, already-validated provider URLs enter this task. Never log text.
    if Len(m.top.text) > 96 or Len(m.top.text) = 0 then
        m.top.result = {ok:false}
        return
    end if
    qr = QrCode()
    ecl = qr.Ecc[1]
    qr.encodeSegments(qr.QrSegment.makeSegments(m.top.text),ecl,1,6,0,false)
    pixel = 8
    side = (qr.size + 8) * pixel
    bitmap = CreateObject("roBitmap",{width:side,height:side,AlphaEnable:false})
    if bitmap = invalid then
        m.top.result = {ok:false}
        return
    end if
    bitmap.DrawRect(0,0,side,side,&hffffffff)
    for y = 0 to qr.size - 1
        for x = 0 to qr.size - 1
            if qr.modules[y][x] = 1 then bitmap.DrawRect((x+4)*pixel,(y+4)*pixel,pixel,pixel,&h000000ff)
        end for
    end for
    bitmap.Finish()
    png = bitmap.GetPng(0,0,side,side)
    if png = invalid then
        m.top.result = {ok:false}
        return
    end if
    ok = png.WriteFile(m.top.path)
    m.top.result = {ok:ok,path:m.top.path,side:side}
end sub
