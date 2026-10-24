import json,zipfile,hashlib,math,html
from pathlib import Path
out=Path(__file__).parent
cats=['Пользователи','Настройки','Фото','Музыка','Видео','Игра','Сеть','PlayStation Network','Друзья']
icons=['♙','⚙','▣','♫','▶','✚','◎','◈','♟']
rows=[['Выключить систему','Создать пользователя','Пользователь 1'],['Обновление системы','Настройки игры','Настройки видео','Настройки музыки','Настройки чата','Настройки системы','Настройки темы','Настройки даты и времени','Настройки энергосбережения','Настройки аксессуаров','Настройки экрана','Настройки звука','Настройки безопасности','Настройки сети'],['Фотоальбом','Устройство USB','Галерея фотографий'],['Список воспроизведения','Устройство USB','Музыкальная библиотека'],['Видеоколлекция','Устройство USB','Редактор видео'],['Управление сохранёнными данными','Управление данными игры','Memory Card Utility','Диск не вставлен','Демонстрационная игра'],['Интернет-браузер','Поиск в Интернете','Дистанционное воспроизведение','Информационная доска'],['Войти','Создать учётную запись','PlayStation Store','Управление учётной записью'],['Добавить друга','Сообщения','Список друзей','Профиль']]
assets={};cost=[]
def costume(name,body):
 s=('<svg xmlns="http://www.w3.org/2000/svg" width="960" height="720" viewBox="0 0 960 720">'+body+'</svg>').encode();h=hashlib.md5(s).hexdigest();assets[h+'.svg']=s;cost.append(dict(name=name,assetId=h,md5ext=h+'.svg',dataFormat='svg',rotationCenterX=480,rotationCenterY=360))
for c,rs in enumerate(rows):
 for j in range(14):
  k=min(j,len(rs)-1)
  b='<g fill="white" font-family="Arial, sans-serif"> <text x="58" y="60" font-size="18" opacity=".65">PS3     XMB™</text><text x="590" y="60" font-size="15">24/10     15:30    ◉</text>'
  for i,n in enumerate(cats):
   x=230+(i-c)*112
   b+=f'<text x="{x}" y="220" font-size="{48 if i==c else 32}" opacity="{1 if i==c else .45}" text-anchor="middle">{icons[i]}</text>'
  b+=f'<text x="230" y="258" font-size="18" text-anchor="middle">{cats[c]}</text>'
  for i,n in enumerate(rs):
   y=350+(i-k)*58
   if 285<y<640:b+=f'<text x="216" y="{y}" font-size="{22 if i==k else 17}" opacity="{1 if i==k else .4}">◇</text><text x="280" y="{y}" font-size="{24 if i==k else 18}" opacity="{1 if i==k else .45}">{html.escape(n)}</text>'
  b+='<text x="65" y="685" font-size="15" opacity=".7">← → Категории    ↑ ↓ Пункты    Пробел: открыть    Esc: назад    T: цвет</text></g>'
  costume(str(c*14+j+1),b)
blocks={};idx=0
def block(op,inputs={},fields={},top=False):
 global idx
 idx+=1;i='b'+str(idx);blocks[i]=dict(opcode=op,next=None,parent=None,inputs=inputs,fields=fields,shadow=False,topLevel=top);return i
def chain(ids):
 for a,b in zip(ids,ids[1:]):blocks[a]['next']=b;blocks[b]['parent']=a
 return ids[0]
def num(n):return [1,[4,str(n)]]
def var(n):return [3,[12,n,n],[4,'0']]
def expr(op,a,b):return block(op,{'NUM1':a,'NUM2':b})
def script(key,ids):
 h=block('event_whenflagclicked' if key is None else 'event_whenkeypressed',fields={} if key is None else {'KEY_OPTION':[key,None]},top=True);chain([h]+ids)
def setv(n,v):return block('data_setvariableto',{'VALUE':v},{'VARIABLE':[n,n]})
def change(n,v):return block('data_changevariableby',{'VALUE':num(v)},{'VARIABLE':[n,n]})
script(None,[setv('category',num(5)),setv('item',num(0))])
for key,delta in [('right arrow',1),('left arrow',8)]:
 a=expr('operator_add',var('category'),num(delta));m=block('operator_mod',{'NUM1':[3,a,[4,'0']],'NUM2':num(9)});script(key,[setv('category',[3,m,[4,'0']]),setv('item',num(0))])
for key,delta in [('down arrow',1),('up arrow',13)]:
 a=expr('operator_add',var('item'),num(delta));m=block('operator_mod',{'NUM1':[3,a,[4,'0']],'NUM2':num(14)});script(key,[setv('item',[3,m,[4,'0']])])
m=expr('operator_multiply',var('category'),num(14));a=expr('operator_add',[3,m,[4,'0']],var('item'));a2=expr('operator_add',[3,a,[4,'0']],num(1));sw=block('looks_switchcostumeto',{'COSTUME':[3,a2,[4,'1']]});loop=block('control_forever',{'SUBSTACK':[2,sw]});blocks[sw]['parent']=loop;script(None,[loop])
script('space',[block('looks_sayforsecs',{'MESSAGE':[1,[10,'Это демонстрация интерфейса PS3. Сервисы PSN и игры PS3 недоступны.']], 'SECS':num(2)})])
base=dict(variables={},lists={},broadcasts={},blocks={},comments={},currentCostume=0,costumes=[],sounds=[],volume=100)
stage=dict(base,isStage=True,name='Stage',variables={'category':['category',5],'item':['item',0]},tempo=60,videoTransparency=50,videoState='on',textToSpeechLanguage=None)
sprite=dict(base,isStage=False,name='XMB',blocks=blocks,costumes=cost,visible=True,x=0,y=0,size=50,direction=90,draggable=False,rotationStyle='don\'t rotate',layerOrder=2)
# Animated translucent waves behind the menu.
cost=[]
for f in range(30):
 b='<defs><linearGradient id="g" x2="0" y2="1"><stop stop-color="#091c31"/><stop offset=".6" stop-color="#184f68"/><stop offset="1" stop-color="#050b16"/></linearGradient></defs><path fill="url(#g)" d="M0 0H960V720H0Z"/>'
 for line in range(10):
  pts=' '.join(f'{x},{390+math.sin(x/210+f/30*math.tau+line*.06)*44+line*3}' for x in range(0,981,14));b+=f'<polyline points="{pts}" fill="none" stroke="#bdefff" stroke-width="1.2" opacity="{.18-line*.012}"/>'
 costume(str(f),b)
blocks={};idx=0
n=block('looks_nextcostume');w=block('control_wait',{'DURATION':num(.05)});chain([n,w]);lp=block('control_forever',{'SUBSTACK':[2,n]});blocks[n]['parent']=lp;script(None,[lp]);wave=dict(base,isStage=False,name='Wave',blocks=blocks,costumes=cost,visible=True,x=0,y=0,size=50,direction=90,draggable=False,rotationStyle='don\'t rotate',layerOrder=1)
p=dict(targets=[stage,wave,sprite],monitors=[],extensions=[],meta={'semver':'3.0.0','vm':'0.2.0','agent':'PS3 XMB fan simulator'})
with zipfile.ZipFile(out/'PS3-XMB.sb3','w',zipfile.ZIP_DEFLATED) as z:
 z.writestr('project.json',json.dumps(p,ensure_ascii=False));
 for name,data in assets.items():z.writestr(name,data)
print('Built',len(assets),'assets')
