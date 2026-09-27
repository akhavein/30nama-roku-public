#!/usr/bin/env python3
"""Execute actual BrightScript model/controller code; no live credentials required."""
import pathlib, re, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parent.parent
model = (root / 'components/Model.brs').read_text()
all_source = '\n'.join((root / ('components/'+name)).read_text() for name in ['App.brs','Playback.brs','Reliability.brs','Sync.brs','Search.brs','Experience.brs','Intro.brs','CloudWatchlist.brs'])
names = ['OnApiResult','CancelRequest','CancelPageRequests','Request','NextEpisode','CompletePlayback','SavePlayback','RestartPlayback','TogglePause','PersistHistory','PlayerKey','OnKeyboardClosed','CloseKeyboard','KeyboardMessage','SeekBy','OnSeekCommit','CheckpointPosition','InvalidateSessionRequests','CancelSearchEdit','CancelOlderMediaProgress','RecordEpisode','OnViewerActivity','OnBrowseShortcut','CloudGlobalTag','UpdateIntro','ActiveIntroTarget','SkipIntro']
controller=[]
for name in names:
    match=re.search(r'(?mi)^(sub|function) '+name+r'\(.*?^end \1\s*$',all_source,re.S)
    assert match,name
    controller.append(match.group())
subtitle_source = (root/'components/SubtitlePlayback.brs').read_text()
subtitle_controller = '\n'.join(re.search(r'(?mi)^(sub|function) '+name+r'\(.*?^end \1\s*$',subtitle_source,re.S).group() for name in ['SidecarUrl','OnCaptionResult','RefreshCaptionMetadata'])
buffer_controller = re.search(r'(?mi)^sub OnBufferTimeout\(.*?^end sub\s*$',all_source,re.S).group()
search_names = ['StartSearch','SearchCacheGet','CacheSearch','HandleSearchResult','CommitSearch','RememberSearchFocus','RestoreSearchSnapshot','CancelSearchEdit']
search_controller = '\n'.join(re.search(r'(?mi)^(sub|function) '+name+r'\(.*?^end \1\s*$',all_source,re.S).group() for name in search_names)
for filename, source in [('previews.brs',model+'\n'+(root/'components/Previews.brs').read_text()),('cloud-watchlist.brs',model+'\n'+(root/'components/CloudWatchlist.brs').read_text()),('intro.brs',model+'\n'+(root/'components/Intro.brs').read_text()),('watching-controller.brs',model+'\n'+(root/'components/Experience.brs').read_text()),('watching.brs',model),('reliability.brs',model+'\n'+(root/'components/Reliability.brs').read_text()),('search.brs',model+'\n'+search_controller),('sync-controller.brs',model+'\n'+(root/'components/Sync.brs').read_text()),('features.brs',model+'\n'+(root/'components/Captions.brs').read_text()),('sync.brs',model),('buffer-controller.brs',buffer_controller),('subtitle-controller.brs',model+'\n'+(root/'components/Captions.brs').read_text()+'\n'+subtitle_controller),('logic.brs',model),('controllers.brs',model+'\n'+'\n'.join(controller)),('captions.brs',(root/'components/Captions.brs').read_text())]:
    # brs scans its working directory; never give it the shared system /tmp.
    with tempfile.TemporaryDirectory(prefix='roku-brs-') as test_dir:
        script=pathlib.Path(test_dir)/filename
        script.write_text(source+'\n'+(root/'tests'/filename).read_text())
        result=subprocess.run([str(root/'node_modules/.bin/brs'),str(script)],cwd=test_dir,capture_output=True,text=True)
        print(result.stdout,end='')
        if result.stderr:print(result.stderr,end='')
        assert result.returncode==0 and 'REGRESSION PASS' in result.stdout and 'FAIL:' not in result.stdout,filename
