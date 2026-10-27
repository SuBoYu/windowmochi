#!/usr/bin/env python3
"""Build the illustrated English guide. Requires macOS say, ffmpeg, ffprobe, Pillow."""
from pathlib import Path
import json
import math
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/media'
TMP = ROOT / '.build/walkthrough'
OUT.mkdir(parents=True, exist_ok=True)
TMP.mkdir(parents=True, exist_ok=True)
W, H, FPS = 1280, 720, 24
BG, INK, MUTED, BLUE = '#F7F5F0', '#252E43', '#647086', '#466BE8'
FONT = '/System/Library/Fonts/Supplemental/Arial.ttf'
BOLD = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'
def font(n, bold=False): return ImageFont.truetype(BOLD if bold else FONT, n)
scenes = [
    ('Meet WindowMochi', 'A little mochi. A tidier desktop.', 'WindowMochi remembers where your windows belong. This illustrated guide shows how to save a multi-display layout and bring it back with one shortcut.'),
    ('1. Launch the app', 'Open WindowMochi.app, then look in the menu bar.', 'After building the project, open dist slash WindowMochi dot app. It runs in the menu bar, so there is no regular app window. Click the mochi icon to open its menu.'),
    ('2. Allow window control', 'System Settings → Privacy & Security → Accessibility', 'Choose Grant Accessibility permission. In System Settings, enable WindowMochi under Privacy and Security, Accessibility. You make this permission change yourself. Then return to the app.'),
    ('3. Save your layout', 'Arrange windows on both displays, then save.', 'Arrange your windows across your displays. Choose Save current layout, enter a name such as Work, and click Save. You can keep several layouts for different activities.'),
    ('4. Restore in one click', 'Move your windows, then choose your saved layout.', 'Move or resize a few windows. Open the mochi menu and choose Restore Work. WindowMochi moves your open windows back to their saved displays, positions, and sizes.'),
    ('5. Switch with shortcuts', 'Keep WindowMochi running in the background.', 'Hold Control, Option, and Command, then press one through nine to restore a layout. Use the right or left arrow with the same modifiers to cycle through layouts.'),
    ('6. Choose your language', 'Language changes immediately and stays saved.', 'Open Language in the menu to choose English, Traditional Chinese, Simplified Chinese, or Japanese. By default, WindowMochi follows your system language preferences.'),
    ('Permission still not working?', 'Re-add the exact app you are running.', 'If the switch is on but window control still fails, quit the app, remove its old Accessibility entry, then add and enable the exact app you run. Reopen it without rebuilding. See the README for details.'),
]
durations = []
for i, (_, _, narration) in enumerate(scenes):
    source = TMP / f'{i}.txt'; source.write_text(narration)
    audio = TMP / f'{i}.aiff'
    subprocess.run(['say', '-v', 'Samantha', '-r', '175', '-f', str(source), '-o', str(audio)], check=True)
    info = json.loads(subprocess.check_output(['ffprobe', '-v', 'quiet', '-show_format', '-of', 'json', str(audio)]))
    durations.append(math.ceil((float(info['format']['duration']) + 1.0) * FPS) / FPS)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(audio), '-af', 'apad', '-t', str(durations[-1]), '-ar', '48000', '-ac', '1', str(TMP / f'{i}.wav')], check=True)
(TMP / 'audio.txt').write_text(''.join(f"file '{i}.wav'\n" for i in range(len(scenes))))
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', str(TMP/'audio.txt'), '-c:a', 'pcm_s16le', str(TMP/'narration.wav')], check=True)
mascot = Image.open(ROOT/'assets/branding/windowmochi-mascot-v1.png').convert('RGBA')
mascot.thumbnail((360,360), Image.Resampling.LANCZOS)
small = mascot.copy(); small.thumbnail((36,36),Image.Resampling.LANCZOS)
def text(d, xy, s, size=24, fill=INK, bold=False): d.text(xy, s, font=font(size,bold), fill=fill)
def box(d, bounds, fill='white', radius=18, outline=None): d.rounded_rectangle(bounds,radius,fill=fill,outline=outline,width=2)
def window(d, x,y,w,h,label,color):
    box(d,(x,y,x+w,y+h),color,12)
    box(d,(x,y,x+w,y+30),'#FFFFFF',12)
    for j,c in enumerate(['#FF7771','#FFCA54','#69CA78']): d.ellipse((x+12+j*17,y+10,x+21+j*17,y+19),fill=c)
    text(d,(x+14,y+48),label,20,bold=True)
def monitors(d, t=1):
    # Animated arrangement, illustrated rather than a capture of the user's desktop.
    box(d,(95,260,755,574),'#26344D',20)
    box(d,(110,276,740,555),'#E6EDFF',10)
    box(d,(805,330,1170,574),'#26344D',15)
    box(d,(820,345,1155,555),'#E9E7F8',8)
    d.rectangle((399,574,449,609),fill='#98A3B4');box(d,(330,604,520,616),'#98A3B4',6)
    box(d,(778,575,1197,592),'#98A3B4',6)
    window(d,130+int(210*(1-t)),298+int(50*(1-t)),270,226,'Browser','#BBD6FF')
    window(d,420-int(100*(1-t)),298+int(70*(1-t)),300,226,'Editor','#CBBFFF')
    window(d,837,365,300,170,'Messages','#BCE4D8')
    text(d,(288,635),'External display',21,MUTED)
    text(d,(896,635),'Built-in display',21,MUTED)
def menu(d, highlight=None):
    box(d,(770,235,1170,590),'white',18,'#DFE4EC')
    labels=['About WindowMochi','Save current layout…','Restore “Work” · 3 windows','Previous layout','Next layout','Language','Grant Accessibility permission…']
    for j,label in enumerate(labels):
        y=252+j*45
        if j==highlight: box(d,(782,y-3,1158,y+34),'#E8EEFF',8)
        text(d,(796,y+2),label,19)
def frame(scene,p):
    image=Image.new('RGB',(W,H),BG);d=ImageDraw.Draw(image)
    text(d,(56,30),'WindowMochi',25,bold=True)
    text(d,(952,36),'ILLUSTRATED QUICK START',14,MUTED)
    text(d,(56,91),scenes[scene][0],44,bold=True)
    text(d,(58,155),scenes[scene][1],25,MUTED)
    if scene==0:
        image.paste(mascot,(125,260),mascot)
        text(d,(570,295),'Save once.',41,bold=True)
        text(d,(570,357),'Restore anytime.',41,bold=True)
        text(d,(570,439),'Multiple displays · Global shortcuts',23,MUTED)
        text(d,(570,479),'English · Chinese · Japanese',23,MUTED)
    elif scene==1:
        box(d,(90,249,690,580),'white',18,'#DFE4EC')
        text(d,(125,282),'Finder / dist',24,bold=True)
        image.paste(mascot.resize((150,150)),(283,340),mascot.resize((150,150)))
        text(d,(248,510),'WindowMochi.app',23)
        menu(d)
        image.paste(small,(1115,198),small)
    elif scene==2:
        box(d,(140,245,1140,595),'white',18,'#DFE4EC')
        text(d,(180,281),'Accessibility',32,bold=True)
        text(d,(180,338),'Allow the app to move and resize windows.',23,MUTED)
        box(d,(180,407,1090,492),'#F2F4F8',12)
        image.paste(small,(205,430),small);text(d,(260,432),'WindowMochi',26,bold=True)
        enabled=p>.35
        box(d,(979,431,1051,469),BLUE if enabled else '#A6ADBA',19)
        cx=1030 if enabled else 1000;d.ellipse((cx-15,435,cx+15,465),fill='white')
        text(d,(180,537),'Enable WindowMochi itself for window control.',21,MUTED)
    elif scene==3:
        monitors(d)
        if p>.35:
            box(d,(405,276,875,501),'white',18,'#CFD7E7')
            text(d,(436,307),'Save 3 windows',28,bold=True)
            box(d,(435,365,844,412),'#F1F4FA',8)
            text(d,(450,374),'Work',24)
            box(d,(725,437,844,480),BLUE,10);text(d,(754,445),'Save',22,'white',True)
    elif scene==4:
        ease=min(1,max(0,(p-.25)/.5));ease=ease*ease*(3-2*ease)
        monitors(d,ease)
        if p<.4:
            box(d,(410,220,895,266),BLUE,10)
            text(d,(434,230),'Restore “Work” · 3 windows',23,'white',True)
    elif scene==5:
        for j,(keys,label) in enumerate([('⌃  ⌥  ⌘  1–9','Restore layouts 1–9'),('⌃  ⌥  ⌘  →','Next layout'),('⌃  ⌥  ⌘  ←','Previous layout')]):
            y=255+j*119
            box(d,(120,y,1160,y+94),'white',16,'#DFE4EC')
            # Use spelled-out modifiers to stay readable across font renderers.
            text(d,(150,y+17),['Control + Option + Command + 1–9','Control + Option + Command + →','Control + Option + Command + ←'][j],25,BLUE,True)
            text(d,(150,y+55),label,21,MUTED)
    elif scene==6:
        box(d,(265,245,1015,610),'white',18,'#DFE4EC')
        for j,label in enumerate(['Follow system','English','Traditional Chinese','Simplified Chinese','Japanese']):
            y=267+j*62
            if j==1: box(d,(287,y-3,993,y+47),'#E8EEFF',10)
            text(d,(320,y+7),label,26,BLUE if j==1 else INK,j==1)
    else:
        for j,label in enumerate(['Quit WindowMochi.','Remove its old Accessibility entry.','Add the exact app again and enable it.','Reopen it without rebuilding.']):
            y=253+j*84
            box(d,(110,y,1170,y+65),'white',12,'#DFE4EC')
            text(d,(133,y+16),f'{j+1}.  '+label,26,bold=True)
    d.rectangle((0,H-8,int(W*p),H),fill=BLUE)
    text(d,(55,684),'github.com/SuBoYu/windowmochi',16,MUTED)
    text(d,(1140,681),f'{scene+1} / {len(scenes)}',18,MUTED)
    return image

# Keep a readable poster separate from the video for GitHub's Markdown renderer.
frame(0,0).save(OUT/'windowmochi-quickstart-poster.png')
cmd=['ffmpeg','-v','error','-y','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','pipe:0','-i',str(TMP/'narration.wav'),'-c:v','libx264','-preset','fast','-crf','23','-pix_fmt','yuv420p','-c:a','aac','-b:a','128k','-movflags','+faststart','-shortest',str(OUT/'windowmochi-quickstart.mp4')]
process=subprocess.Popen(cmd,stdin=subprocess.PIPE)
try:
    for i,duration in enumerate(durations):
        count=round(duration*FPS)
        for n in range(count): process.stdin.write(frame(i,n/max(1,count-1)).tobytes())
finally:
    process.stdin.close()
assert process.wait()==0, 'Video encoding failed'
def stamp(seconds):
    ms=round(seconds*1000); return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02},{ms%1000:03}'
elapsed=0; subtitles=[]
for i,((title,subtitle,narration),duration) in enumerate(zip(scenes,durations),1):
    subtitles.append(f'{i}\n{stamp(elapsed)} --> {stamp(elapsed+duration)}\n{title}\n{subtitle}\n')
    elapsed+=duration
(OUT/'windowmochi-quickstart.srt').write_text('\n'.join(subtitles))
(OUT/'windowmochi-quickstart-transcript.md').write_text('# WindowMochi illustrated quick start\n\nEnglish narration transcript. These are illustrated examples, not a live screen recording.\n\n'+'\n\n'.join(f'## {title}\n\n{narration}' for title,_,narration in scenes)+'\n')
print(f'Created {elapsed:.1f}s English walkthrough: {OUT}/windowmochi-quickstart.mp4')
print('Scene durations:', durations)
