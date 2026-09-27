sub Main()
    m.checks = 0
    Assert(ArabicVisual("سلام") = "ﻡﻼﺳ", "RTL shaping: سلام")
    Assert(ArabicVisual("آزمایش زیرنویس فارسی") = "ﯽﺳﺭﺎﻓ ﺲﯾﻮﻧﺮﯾﺯ ﺶﯾﺎﻣﺯﺁ", "RTL shaping: آزمایش زیرنویس فارسی")
    Assert(ArabicVisual("سلام (2026)") = "(2026) ﻡﻼﺳ", "RTL shaping: سلام (2026)")
    Assert(ArabicVisual("سلام Hello world!") = "!Hello world ﻡﻼﺳ", "RTL shaping: سلام Hello world!")
    Assert(ArabicVisual("می‌روم") = "ﻡﻭﺭﯽﻣ", "RTL shaping: می‌روم")
    Assert(ArabicVisual("Hello سلام") = "Hello ﻡﻼﺳ", "RTL shaping: Hello سلام")
    Assert(ArabicVisual("سال ۲۰۲۶") = "۲۰۲۶ ﻝﺎﺳ", "RTL shaping: سال ۲۰۲۶")
    Assert(ArabicVisual("Hello 2026") = "Hello 2026", "Latin text preserved")
    Assert(CaptionTime("01:02:03,250") = 3723.25, "SRT milliseconds parsed")
    Assert(CaptionTime("02:03.500") = 123.5, "VTT short timestamp parsed")
    Assert(CaptionTime("invalid") = -1, "invalid timestamp rejected")
    Assert(CaptionTime("00:61:00.000") = -1, "invalid minute range rejected")
    raw = "WEBVTT" + Chr(10) + Chr(10) + "00:00:01.000 --> 00:00:03.000 align:center" + Chr(10) + "<b>Hello &amp; world</b>" + Chr(10) + Chr(10) + "2" + Chr(10) + "00:00:04,000 --> 00:00:06,000" + Chr(10) + "Second line"
    cues = ParseCaptions(raw,false)
    Assert(cues.Count() = 2, "VTT/SRT cues parsed without trailing blank line")
    Assert(cues[0].text = "Hello & world", "markup removed and entities decoded")
    Assert(CaptionAt(cues,0.9) = "", "no cue before start")
    Assert(CaptionAt(cues,1.0) = "Hello & world", "cue begins at exact timestamp")
    Assert(CaptionAt(cues,3.0) = "", "cue ends at exclusive endpoint")
    Assert(CaptionAt(cues,4.5) = "Second line", "seek jumps to correct cue")
    Assert(CaptionAt(cues,1.5) = "Hello & world", "backward seek returns earlier cue")
    Assert(ParseCaptions("not a subtitle",true).Count() = 0, "non-subtitle response rejected")
    malformed = "00:00:05.000 --> 00:00:01.000" + Chr(10) + "Bad range"
    Assert(ParseCaptions(malformed,true).Count() = 0, "reversed cue rejected")
    Assert(Instr(1,ArabicVisual("سَلام"),Chr(1614)) > 0, "Arabic diacritics preserved")
    Assert(ArabicVisual(Chr(8235) + "سلام" + Chr(8236)) = ArabicVisual("سلام"), "direction controls do not render boxes")
    Assert(ParseCaptions(Chr(65279) + "00:00:01.000 --> 00:00:02.000" + Chr(10) + "Hi" + Chr(10),false)[0].text = "Hi", "BOM and trailing newline handled")
    Assert(CaptionHelperRoute("https://subtitle.30nama.com/file","https://helper.invalid"),"provider subtitles use configured browser helper first")
    Assert(not CaptionHelperRoute("https://subtitle.30nama.com.evil.invalid/file","https://helper.invalid"),"lookalike subtitle host never reaches helper")
    Assert(not CaptionHelperRoute("https://other.invalid/file","https://helper.invalid"),"other sidecar hosts stay direct")
    Assert(not CaptionHelperRoute("https://subtitle.30nama.com/file",""),"no configured helper keeps direct path")
    Assert(CaptionRetryable(503) and CaptionRetryable(0) and CaptionRetryable(408),"transient subtitle failures are retryable")
    Assert(not CaptionRetryable(200) and not CaptionRetryable(403) and not CaptionRetryable(410),"success and expired sidecars are not download-retried")
    Assert(not CaptionRetryable(401) and not CaptionRetryable(429),"authentication and rate limits are not retried")
    print "REGRESSION PASS: "; m.checks; " caption assertions"
end sub
sub Assert(condition as Boolean, label as String)
    if not condition then print "FAIL: ";label: stop
    m.checks = m.checks + 1
    print "PASS: ";label
end sub
