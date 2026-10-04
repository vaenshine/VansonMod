# Build the local screenshot gallery after run_ui_review.sh.
from pathlib import Path
import shutil, json, plistlib
root=Path(__file__).resolve().parents[1]
version=plistlib.loads((root/'Resources/Info.plist').read_bytes())['CFBundleShortVersionString']
dest=root/'release/ui-preview'
(dest/'screenshots').mkdir(parents=True,exist_ok=True)
source=root/'.theos/ui-review/screenshots'
for p in source.glob('*.png'): shutil.copy2(p,dest/'screenshots'/p.name)
titles={
'toolbox-add-script':'新增脚本','script-info':'编辑脚本信息',
'settings-update-trollstore':'更新 · TrollStore 安装','settings-update-missing-package':'更新 · 安装包待发布','settings-update-package-manager':'更新 · 包管理器渠道','settings-update-installer-unavailable':'更新 · 安装器未就绪','settings-update-handoff-failed':'更新 · 跳转失败',
'search-zero-fuzzy-first':'模糊搜索 · 首轮零结果','search-zero-fuzzy-expanded':'模糊搜索 · 多轮后零结果','search-zero-fuzzy-repeat':'连续模糊 · 零结果','search-zero-fuzzy-repeat-first':'连续模糊 · 首次比较','search-zero-fuzzy-legacy':'定值模糊 · 零结果','search-zero-exact':'精确搜索 · 零结果','search-zero-group':'联合搜索 · 零结果','search-zero-filter':'结果筛选 · 零结果','search-zero-fuzzy-init-empty':'模糊初始化 · 空结果','search-zero-fuzzy-init-failed':'模糊初始化 · 失败重试',
'settings-version-idle':'版本 · 待检查','settings-version-checking':'版本 · 检查中','settings-version-current':'版本 · 最新','settings-version-available':'版本 · 有更新','settings-version-failed':'版本 · 检查失败','toolbox-connected':'工具箱进程信息','patch-connected':'RVA 进程信息','add-pointer':'添加指针链','add-pointer-invalid':'指针链输入校验','toolbox-add-lock':'手动锁定','patch-save':'保存 RVA 补丁','search-connected':'已连接进程','search-fuzzy':'模糊扫描重置','applications':'应用与进程','search':'内存搜索','patch':'RVA 补丁','toolbox':'工具箱','settings':'设置',
'pointer-search':'指针搜索','pointer-editor':'项目编辑','pointer-verifier':'指针校验','pointer-sessions':'指针会话',
'search-filters':'内存筛选面板',
'pointer-card':'指针卡片','signature-card':'特征码卡片','patch-card':'补丁卡片','backups':'备份库','modules':'模块选择',
'hex-row-editor':'Hex 行编辑','settings-function':'设置 · 功能配置','settings-about':'设置 · 关于','settings-footer':'设置底部说明','patch-manager-batch':'补丁批量操作','toolbox-batch':'工具箱批量操作','memory-browser':'内存浏览','hex-browser':'Hex 浏览','string-editor':'字符串编辑','signature-search':'特征码分析',
'inspector':'指令检查器','watchpoints':'监视点','process-audit':'进程审计','script-editor':'脚本编辑','script-tools':'命令库','script-guide':'脚本示例'}
entries=[]
for path in source.glob('*.png'):
 key=path.stem; labels=[]
 while True:
  matched=False
  for suffix,label in [('-keyboard','键盘展开'),('-dark','深色'),('-compact','小屏'),('-large-type','大字号'),('-landscape','横屏'),('-long-id','长 Bundle ID')]:
   if key.endswith(suffix):
    key=key[:-len(suffix)]; labels.append(label); matched=True; break
  if not matched: break
 labels=labels or ['常规']; variant=' · '.join(labels)
 group='主页面' if key.startswith('settings') or key in ['applications','search','patch','toolbox','toolbox-batch','toolbox-connected'] else '脚本' if key.startswith('script') else '指针与补丁' if key.startswith(('pointer','add-pointer','patch-save','patch-connected')) or key in ['signature-card','patch-card','backups','patch-manager-batch'] else '内存与调试'
 note='模拟器 WebKit 缺少中文字体；Mac 原生预览已确认中文正常。' if key=='script-guide' else ''
 entries.append(dict(file=path.name,title=titles.get(key,key),variant=variant,variants=labels,group=group,key=key,note=note))
order=list(titles)
entries.sort(key=lambda e:(0 if e['variant']=='常规' else 1,order.index(e['key']) if e['key'] in order else 99,e['variant']))
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>VansonMod · 本地界面预览</title>
<style>*{box-sizing:border-box}body{margin:0;background:#f4f5f9;color:#171827;font:15px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}header{padding:42px 5vw 28px;background:#fff;border-bottom:1px solid #e5e7ef}h1{font-size:32px;letter-spacing:-1px;margin:8px 0 12px}.eyebrow{font-size:12px;font-weight:700;letter-spacing:2px;color:#5856d6}p{line-height:1.8;color:#68697b;max-width:840px}nav{display:flex;flex-wrap:wrap;gap:8px;padding:22px 5vw 10px}button,a.download{font:inherit;border:1px solid #dddfee;border-radius:24px;padding:10px 18px;background:#fff;color:#4c4e63;cursor:pointer;text-decoration:none}button.active{background:#5856d6;border-color:#5856d6;color:white}.download{display:inline-block;margin-right:8px}.meta{padding:0 5vw;color:#747688}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));align-items:start;gap:26px;padding:22px 5vw 60px}article{background:#fff;padding:16px;border:1px solid #e5e7ef;border-radius:20px;box-shadow:0 6px 24px #23264305}h2{font-size:17px;margin:0 0 8px}small{color:#7b7e92}article img{display:block;width:100%;height:auto;border-radius:13px;margin-top:14px;border:1px solid #f0f0f4}article a{display:block}dialog{padding:12px;border:0;border-radius:16px;background:#fff;max-width:96vw;max-height:96vh}dialog::backdrop{background:#111422cc}dialog img{display:block;max-width:90vw;max-height:84vh;width:auto;height:auto}dialog button{margin-bottom:10px}footer{padding:0 5vw 32px;color:#747688}@media(min-width:1300px){main{grid-template-columns:repeat(4,minmax(240px,1fr))}}</style>
<header><div class="eyebrow">VANSONMOD · LOCAL REVIEW</div><h1>VansonMod __VERSION__ · 界面预览</h1><p>真实 UIKit 页面截图，涵盖主页面、内存调试、指针、补丁与脚本。应用名称、进程和卡片采用示例数据；内存页面读取测试进程自己的缓冲区。点击截图可放大查看。键盘状态截图展示应用避让区域，系统键盘由独立窗口绘制。</p><a class="download" href="VansonMod_Mac_preview_v__VERSION__.zip">Mac 交互预览</a><a class="download" href="VansonMod_UI_preview_v__VERSION__.tipa">本地 TIPA 安装包</a><a class="download" href="com.vanson.modifier___VERSION___iphoneos-arm.deb">Rootful DEB</a></header>
<nav id="groups"></nav><nav id="variants"></nav><p class="meta" id="count"></p><main id="gallery"></main><footer>所有产物均保留本地。目标进程附加、内存写入及监视点的完整验证需要设备环境。</footer><dialog id="preview"><button onclick="this.closest('dialog').close()">关闭</button><img alt="页面放大预览"></dialog><script>
const entries=ENTRIES;let group='全部',variant=new URLSearchParams(location.search).get('theme')==='dark'?'深色':'常规';
const groups=['全部','主页面','内存与调试','指针与补丁','脚本'];const variants=['常规','深色','小屏','大字号','横屏','键盘展开','全部状态'];
function controls(id,values,selected,choose){const area=document.getElementById(id);area.replaceChildren();for(const value of values){const b=document.createElement('button');b.textContent=value;b.className=value===selected?'active':'';b.setAttribute('aria-pressed',String(value===selected));b.onclick=()=>{choose(value);render()};area.append(b)}}
function render(){controls('groups',groups,group,v=>group=v);controls('variants',variants,variant,v=>variant=v);const items=entries.filter(e=>(group==='全部'||e.group===group)&&(variant==='全部状态'||e.variants.includes(variant)));document.getElementById('count').textContent=`显示 ${items.length} 张 · 共 ${entries.length} 张截图`;const gallery=document.getElementById('gallery');gallery.replaceChildren();for(const e of items){const card=document.createElement('article'),heading=document.createElement('h2'),meta=document.createElement('small'),a=document.createElement('a'),img=document.createElement('img');heading.textContent=e.title;meta.textContent=e.group+' · '+e.variant+(e.note?' · '+e.note:'');img.src='screenshots/'+e.file;img.alt=e.title+'，'+e.variant;img.loading='lazy';a.href=img.src;a.onclick=ev=>{ev.preventDefault();const d=document.getElementById('preview');d.querySelector('img').src=img.src;d.querySelector('img').alt=img.alt;d.showModal()};a.append(img);card.append(heading,meta,a);gallery.append(card)}}render();document.getElementById('preview').onclick=e=>{if(e.target.tagName==='DIALOG')e.target.close()};
</script></html>'''.replace('ENTRIES',json.dumps(entries,ensure_ascii=False)).replace('__VERSION__',version)
(dest/'index.html').write_text(page)
print(f'Gallery: {dest}/index.html ({len(entries)} screenshots)')
