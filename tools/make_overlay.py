# TrueFrame Overlay - generator of RTSS OverlayEditor layouts (.ovl).
# https://github.com/apbrandom/trueframe-overlay  (MIT License)
#
# Build every preset:   python tools/make_overlay.py --all overlays
# Build one file:       python tools/make_overlay.py out.ovl --res=1440 [--lang=en|ru] [--debug] [--delay=3000] [--refresh=16]
#
# One layout, two languages. Everything (geometry, colors, sensors, math) is defined once below; only the words
# come from the TEXT table. English is written as a ready .ovl. RTSS can only draw ASCII (+ the degree sign), so
# every Russian word is written as a [[word|size]] placeholder into a UTF-8 .template; tools/TextSprites.ps1
# (called by install.ps1 on the player's PC) renders those words into a PNG sprite sheet and produces the final .ovl.
import os, sys, re
if len(sys.argv) >= 2 and sys.argv[1] == '--all':
    import subprocess
    outdir = sys.argv[2] if len(sys.argv) > 2 else 'overlays'
    os.makedirs(outdir, exist_ok=True)
    def build(name, res, *flags):
        subprocess.run([sys.executable, os.path.abspath(__file__), os.path.join(outdir, name), f'--res={res}', *flags], check=True)
    for res, tag in ((1080, '1080p'), (1440, '1440p'), (2160, '4k')):
        build(f'TrueFrame_{tag}.ovl', res)
        build(f'TrueFrame_{tag}_debug.ovl', res, '--debug')
        build(f'TrueFrame_{tag}_ru.template', res, '--lang=ru')
    sys.exit(0)
DEBUG='--debug' in sys.argv
LANG='en'
RES=2160
DELAY=3000    # PM_DisplayDelay, ms: PresentMon reports frames in batches with 0.5-2.5 s lag; showing data 3 s late
              # (RTSS author's value) makes the graph scroll smoothly. Graph and frametime numbers are 3 s behind, FPS is live
REFRESH=16    # PM_RefreshPeriod, ms: how often the graph/PresentMon sources are refreshed (60 Hz)
for _a in list(sys.argv):
    if _a.startswith('--res='): RES=int(_a.split('=')[1])
    if _a.startswith('--lang='): LANG=_a.split('=')[1]
    if _a.startswith('--delay='): DELAY=int(_a.split('=')[1])
    if _a.startswith('--refresh='): REFRESH=int(_a.split('=')[1])
sys.argv=[a for a in sys.argv if a!='--debug' and not a.startswith(('--res=','--lang=','--delay=','--refresh='))]
# effective text height = zoom * |font|: ~1.3% of the screen height on every preset (v11 was ~1.48%)
ZOOM,FONT={2160:(1,-28),1440:(1,-19),1080:(1,-14)}[RES]
SEP_PX=4 if RES==2160 else 2   # separator thickness in pixels (zoom no longer doubles it on 4K)
W=26; L=1; VX=13; VW=W-VX-1
C_LBL="C8C8CC"; C_VAL="FFFFFF"; C_OR="FF8A1E"
# text size tiers (percent of the base font): headers 110, body = default 100, small/secondary 80
S_HDR=110; S_SMALL=80
C_GPU="5CD65C"; C_CPU="4DA6FF"; C_RAM="B67CF5"; C_SEP="3A3A40"

# ---- words (the only language-dependent part). Units (MHz, W, GB, ms, FPS) stay Latin in every language ----
TEXT={
 'en':dict(title='PERFORMANCE', gpu='GPU', cpu='CPU', ram='RAM', frametime='Frametime',
           usage='Usage', temp='Temp', clock='Clock', power='Power', vram='VRAM', maxcore='Max core',
           used='Used', load='Load', ft='avg %FrametimeAvg%  max %FrametimeMax% ms'),
 'ru':dict(title='МОНИТОРИНГ', gpu='Видеокарта', cpu='Процессор', ram='ОЗУ', frametime='Время кадра',
           usage='Загрузка', temp='Температура', clock='Частота', power='Потребление', vram='Видеопамять', maxcore='Макс. ядро',
           used='Занято', load='Загрузка', ft='ср. %FrametimeAvg%  макс. %FrametimeMax% ms'),
}
assert set(TEXT['en'])==set(TEXT['ru']), 'EN and RU word tables must have the same keys'
if LANG not in TEXT: sys.exit(f'unknown --lang={LANG} (en | ru)')
T=TEXT[LANG]
# a run of non-ASCII characters (plus a trailing dot, e.g. "Макс.") = one word drawn as an image; the degree sign stays text
IMG_WORD=re.compile('[^\\x00-\\x7f\\u00b0]+\\.?')

def src(name, units, provider, fmt="", formula="", **extra):
    d={"Name":name,"Units":units,"Format":fmt,"Formula":formula,"Provider":provider}; d.update(extra); return d

sources=[
 src("CPU usage","%","HAL",ID="CPU usage"),
 src("CPU usage max","%","HAL",ID="CPU usage max"),
 src("CPU temperature","C","HAL",ID="CPU temperature"),
 src("CPU temperature","C","HwInfo",SensorInst="0",ReadingType="1",ReadingName="CPU Package,CPU (Tctl/Tdie)"),
 src("CPU temperature","C","AIDA",ID="TCPUPKG,TCPU"),
 src("CPU temperature","C","MSI Afterburner",SrcId="00000080",Gpu="FFFFFFFF",SrcName=""),
 src("CPU temperature","C","LHM",ID="/amdcpu/0/temperature/0,/amdcpu/0/temperature/1,/amdcpu/0/temperature/2,/amdcpu/0/temperature/3,/amdcpu/0/temperature/4,/amdcpu/0/temperature/5"),
 src("CPU clock","MHz","HAL",ID="CPU clock"),
 src("CPU clock","MHz","LHM",ID="/amdcpu/0/clock/1,/amdcpu/0/clock/2,/amdcpu/0/clock/3,/amdcpu/0/clock/0"),
 src("CPU power","W","HAL",fmt="%.1f",ID="CPU power"),
 src("CPU power","W","HwInfo",fmt="%.1f",SensorInst="0",ReadingType="5",ReadingName="CPU Package Power,CPU Package Power (SMU)"),
 src("CPU power","W","AIDA",fmt="%.1f",ID="PCPUPKG"),
 src("CPU power","W","MSI Afterburner",fmt="%.1f",SrcId="00000100",Gpu="FFFFFFFF",SrcName=""),
 src("CPU power","W","LHM",fmt="%.1f",ID="/amdcpu/0/power/0,/amdcpu/0/power/1,/amdcpu/0/power/2,/amdcpu/0/power/3"),
 src("GPU1 usage","%","HAL",ID="GPU1 usage"),
 src("GPU1 temperature","C","HAL",ID="GPU1 temperature"),
 src("GPU1 clock","MHz","HAL",ID="GPU1 clock"),
 src("GPU1 power","W","HAL",fmt="%.1f",ID="GPU1 power"),
 src("GPU1 memory usage","GB","HAL",fmt="%.1f",formula="x/1024",ID="GPU1 memory usage"),
 src("GPU1 total memory","GB","HAL",fmt="%.1f",formula="x/1024",ID="GPU1 total memory"),
 src("RAM usage","GB","HAL",fmt="%.1f",formula="x/1024",ID="RAM usage"),
 src("Total RAM","GB","HAL",fmt="%.1f",formula="x/1024",ID="Total RAM"),
 src("RAM usage percent","%","HAL",ID="RAM usage percent"),
 # PresentMon: lows (classic <FR10L>/<FR01L> only fill in benchmark mode), real fps, worst recent frametime
 src("msBetweenPresents","ms","PresentMon",ID="msBetweenPresents"),
 # what actually reaches the screen (smooth with DLSS FG + flip metering; present intervals zigzag 0/real)
 src("msBetweenDisplayChange","ms","PresentMon",ID="msBetweenDisplayChange"),
 # Frame generation detection. With FG each real frame is followed by k-1 near-zero present gaps, so the sorted
 # present intervals look like {short x (k-1)/k, long x 1/k}. Percentiles are robust against stalls (a single 1 s
 # freeze must not fake an FG detection). k = 1 + [p40 short] + [p60 short] + [p71 short], short = < 30% of p90.
 src("PMp90","ms","HAL",fmt="%.1f",formula="percentile(msBetweenPresents,90)",ID="Stub"),
 src("PMp71","ms","HAL",fmt="%.1f",formula="percentile(msBetweenPresents,71)",ID="Stub"),
 src("PMp60","ms","HAL",fmt="%.1f",formula="percentile(msBetweenPresents,60)",ID="Stub"),
 src("PMp40","ms","HAL",fmt="%.1f",formula="percentile(msBetweenPresents,40)",ID="Stub"),
 src("FGMult","x","HAL",fmt="%.0f",formula="1+(PMp40<0.3*PMp90)+(PMp60<0.3*PMp90)+(PMp71<0.3*PMp90)",ID="Stub"),
 src("FGActive","","HAL",formula="if(validate(FGMult),FGMult>1,0)",ID="Stub"),
 src("NotFG","","HAL",formula="1-FGActive",ID="Stub"),
 src("RealFPS","FPS","HAL",fmt="%.0f",formula="FrameratePresented/FGMult",ID="Stub"),
 src("IsPresentMonDataAvailable","","PresentMon",formula="validate(x)",ID="msBetweenPresents"),
 src("FrameratePresented1Dot0PLow","FPS","HAL",fmt="%.0f",formula="1000/percentile(msBetweenPresents,99)",ID="Stub"),
 src("FrameratePresented","FPS","PresentMon",fmt="%.0f",ID="FrameratePresented"),
 # PresentMon buffer holds per-frame samples: avg of last 60 frames (~1 s) and worst frame of last 300 (~5 s)
 src("FrametimeAvg","ms","HAL",fmt="%.1f",formula="swavg(msBetweenDisplayChange,60)",ID="Stub"),
 src("FrametimeMax","ms","HAL",fmt="%.0f",formula="swmax(msBetweenDisplayChange,300)",ID="Stub"),
]

if DEBUG:
    sources += [
     src("FramerateDisplayed","FPS","PresentMon",fmt="%.0f",ID="FramerateDisplayed"),
     src("CPUFrametime","ms","PresentMon",ID="CPUFrametime"),
     src("DbgCF","ms","HAL",fmt="%.1f",formula="swavg(CPUFrametime,120)",ID="Stub"),
     src("PMDropped","","PresentMon",ID="Dropped"),
     src("msReportingLag","ms","PresentMon",fmt="%.0f",ID="msReportingLag"),
     src("DbgLag","ms","HAL",fmt="%.0f",formula="swmax(msReportingLag,300)",ID="Stub"),
     src("DbgDrop","","HAL",fmt="%.0f",formula="100*swavg(PMDropped,120)",ID="Stub"),
    ]

layers=[]
def lay(name,text,x,y,w,h,origin=0,color=None,bg=None,size=None,fixed=True,vis=None):
    if LANG!='en': text=IMG_WORD.sub(lambda m: f'[[{m.group(0)}|{size or 100}]]', text)
    d=[("Name",name),("Text",text),("PositionX",x),("PositionY",y),("ExtentX",w),("ExtentY",h),("ExtentOrigin",origin)]
    if fixed: d.append(("FixedAlignment",1))
    if size: d.append(("Size",size))
    if color: d.append(("TextColor",color))
    if bg: d.append(("BgndColor",bg))
    if vis: d.append(("VisibilitySource",vis))
    layers.append(d)
def thr(s,warn,crit,base=C_VAL):
    return f"{base},,{warn},FFD60A,{warn},{crit},FF453A,{crit},({s},0)"
def row(y,key,val,vcolor=C_VAL):
    name=TEXT['en'][key]      # layer names are always English, so both languages share the same layer structure
    lay(name,T[key],-L,-y,-(VX-L),-1,3,C_LBL)
    lay(name+" value",val,-VX,-y,-VW,-1,5,vcolor)
def header(y,key,color):
    lay(f"sep{y}","",-L,-y,-(W-2*L),SEP_PX,0,bg="FF"+C_SEP)
    lay(f"hdr{y}",T[key],-L,-y,-(W-2*L),-1,3,color,size=S_HDR)

# Graph: RTSS graph flags (hex in tag): 1=filled, 8=bar, 10=own bgnd, 20=vertical, 40=mirrored, 80=autoscale
G_TOP=19; G_H=4          # graph area: rows 19..22 (row 18 = FRAMETIME header)
G_MAX=50                 # fixed 0..50 ms scale (20 fps floor)
G_FLAGS_LINE="0"         # plain line, newest sample on the right (flag 40 "mirrored" only flips scroll direction)

DEG='\u00b0C'            # degree sign = byte 0xB0, the only non-ASCII character RTSS can draw as text
H=28+(3 if DEBUG else 0)
lay("Background","",0,0,-W,-H,0,bg="FF1A1A1E")
lay("Title small",T['title'],-L,0,-11,-1,3,C_VAL)
lay("DateTime","%Date%   %Time24%",-12,0,-13,-1,5,C_LBL,size=S_SMALL)
header(1,'gpu',C_GPU)
lay("GPU name","%GPU%   %VRAM%",-L,-2,-(W-2*L),-1,3,C_LBL,size=S_SMALL)   # RTSS macros %GPU% / %CPU% / %RAM% are filled per PC; own row, they can be long
row(3,'usage',"%GPU1 usage% %",C_GPU)
row(4,'temp',f"%GPU1 temperature% {DEG}",thr("GPU1 temperature",75,85))
row(5,'clock',"%GPU1 clock% MHz")
row(6,'power',"%GPU1 power% W")
row(7,'vram',"%GPU1 memory usage% / %GPU1 total memory% GB")
header(8,'cpu',C_CPU)
lay("CPU name","%CPU%",-L,-9,-(W-2*L),-1,3,C_LBL,size=S_SMALL)
row(10,'usage',"%CPU usage% %",thr("CPU usage",85,95))
row(11,'maxcore',"%CPU usage max% %",thr("CPU usage max",90,98))
row(12,'temp',f"%CPU temperature% {DEG}",thr("CPU temperature",85,95))
row(13,'clock',"%CPU clock% MHz")
row(14,'power',"%CPU power% W")
header(15,'ram',C_RAM)
lay("RAM size","%RAM%",-L,-15,-(W-2*L),-1,5,C_LBL,size=S_SMALL)
row(16,'used',"%RAM usage% / %Total RAM% GB")
row(17,'load',"%RAM usage percent% %",thr("RAM usage percent",85,95))
header(18,'frametime',C_OR)
lay("FT values",T['ft'],-L,-18,-(W-2*L),-1,5,C_VAL,size=S_SMALL,vis="IsPresentMonDataAvailable")
lay("Graph bg","",-L,-G_TOP,-(W-2*L),-G_H,0,bg="FF0E0E12")
# one graph for every case: time between frames that actually reached the screen (correct with and without frame generation)
lay("Graph line",f"<G=msBetweenDisplayChange,0,0,1,0,{G_MAX},{G_FLAGS_LINE}>",-L,-G_TOP,-(W-2*L),-G_H,0,"FF"+C_OR)
Y=G_TOP+G_H
lay("FPS label","FPS",-L,-Y,-10,-2,3,C_VAL,size=160)
lay("FPS fg","<FR> (%RealFPS%)",-11,-Y,-(W-11-L),-2,5,C_OR,size=150,vis="FGActive")
lay("FPS","<FR>",-11,-Y,-(W-11-L),-2,5,C_OR,size=150,vis="NotFG")
lay("Lows label","1% Low",-L,-(Y+2),-(VX-L),-1,3,C_LBL,vis="IsPresentMonDataAvailable")
lay("Lows value","%FrameratePresented1Dot0PLow% FPS",-VX,-(Y+2),-VW,-1,5,C_VAL,vis="IsPresentMonDataAvailable")
lay("API","<API>   <RES>",-L,-(Y+3),-(W-2*L),-1,3,C_LBL,size=S_SMALL)
if DEBUG:
    lay("dbg1","DBG mult %FGMult%  p40 %PMp40%  p90 %PMp90%",-L,-(Y+4),-(W-2*L),-1,3,C_LBL,size=70)
    lay("dbg2","pres %FrameratePresented%  disp %FramerateDisplayed%",-L,-(Y+5),-(W-2*L),-1,3,C_LBL,size=70)
    lay("dbg3","cf %DbgCF%  drop %DbgDrop% pct  lag %msReportingLag%/%DbgLag% ms",-L,-(Y+6),-(W-2*L),-1,3,C_LBL,size=70)
lay("Cursor position placeholder",'" \b"',0,-H,0,0,0,fixed=False)

out=["[Master]","Implementation=2","FontFace=Segoe UI Semibold",f"FontHeight={FONT}","FontWeight=400",f"ZoomRatio={ZOOM}",
"[Settings]","Name=TrueFrame Overlay",f"EnvVars=PM_RefreshPeriod={REFRESH};PM_DisplayDelay={DELAY}","RefreshPeriod=1000","LockUserSettings=1","EmbeddedImage=","PingAddr=",
"[General]",f"Sources={len(sources)}","Tables=0",f"Layers={len(layers)}"]
keys=["Name","Units","Format","Formula","Provider","ID","SensorInst","ReadingType","ReadingName","SrcId","Gpu","SrcName"]
for i,s in enumerate(sources):
    out.append(f"[Source{i}]"); out += [f"{k}={s[k]}" for k in keys if k in s]
for i,d in enumerate(layers):
    out.append(f"[Layer{i}]"); out += [f"{k}={v}" for k,v in d]
p=sys.argv[1]
# en: finished .ovl (ASCII + 0xB0). ru: UTF-8 .template with [[word|size]] placeholders, finished on the player's PC by TextSprites.ps1
open(p,"wb").write(("\r\n".join(out)+"\r\n").encode("latin-1" if LANG=='en' else "utf-8"))
print(len(layers),"layers,",len(sources),"sources ->",p)
