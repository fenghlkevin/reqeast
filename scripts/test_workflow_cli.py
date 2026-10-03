#!/usr/bin/env python3
"""Local HTTP fixture for CLI chaining, row isolation, reports and CI exit codes."""
import json,tempfile,threading,subprocess,sys,shutil
from pathlib import Path
from http.server import HTTPServer,BaseHTTPRequestHandler
root=Path(tempfile.mkdtemp(prefix='reqeast-cli-e2e-'));(root/'requests').mkdir()
ids=['11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-333333333333']
seen=[]
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_POST(self):
  body=json.loads(self.rfile.read(int(self.headers.get('Content-Length',0))) or b'{}');seen.append((self.path,body,self.headers.get('Authorization')))
  if self.path=='/login': self.reply(200,{'data':{'token':'token-'+body['username']}})
  else:
   assert self.headers['Authorization']=='Bearer token-'+body['username']
   self.reply(201,{'data':{'id':42}})
 def do_GET(self):
  seen.append((self.path,None,self.headers.get('Authorization')));self.reply(200,{'success':True})
 def reply(self,status,body):
  data=json.dumps(body).encode();self.send_response(status);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
server=HTTPServer(('127.0.0.1',0),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
manifest={'format':1,'name':'Order demo','requestIds':ids,'workflows':[{'name':'Order test','requestIds':ids,'stopOnFailure':True}], 'environments':[{'id':'env','name':'Test','variables':[{'key':'baseUrl','value':f'http://127.0.0.1:{server.server_port}','enabled':True}]}]}
(root/'reqeast.json').write_text(json.dumps(manifest))
for i,name in enumerate(['Login','Create order','Query order']):
 data={'method':'GET' if i==2 else 'POST','url':'{{baseUrl}}'+['/login','/orders','/orders/{{orderId}}'][i],'authType':'none' if i==0 else 'bearer','authToken':'{{token}}','bodyType':'json' if i<2 else 'none','bodyContent':'{"username":"{{username}}"}','workflow':{'extractions':[], 'assertions':[{'kind':'status','expected':'201' if i==1 else '200','enabled':True}]}}
 if i<2:data['workflow']['extractions']=[{'pointer':'/data/token' if i==0 else '/data/id','variable':'token' if i==0 else 'orderId','enabled':True}]
 (root/'requests'/f'{ids[i]}.json').write_text(json.dumps({'id':ids[i],'name':name,'httpData':data}))
(root/'cases.csv').write_text('username\nalice\nbob\n')
cli=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[1]/'rust/target/release/reqeast-cli'
def run(extra=[]):return subprocess.run([str(cli),'run',str(root),'--workflow','Order test','--data',str(root/'cases.csv'),'--report',str(root/'run-report.json'),*extra],capture_output=True,text=True)
r=run();assert r.returncode==0,(r.stdout,r.stderr);report=json.loads((root/'run-report.json').read_text());assert len(report)==6 and all(x['passed'] for x in report)
assert [x[0] for x in seen]==['/login','/orders','/orders/42']*2
assert seen[4][2]=='Bearer token-bob'
assert 'token-alice' not in (root/'run-report.json').read_text()
request=root/'requests'/f'{ids[2]}.json';data=json.loads(request.read_text());data['httpData']['workflow']['assertions'][0]['expected']='404';request.write_text(json.dumps(data));seen.clear()
r=run();assert r.returncode==1 and len(seen)==3,(r.stdout,r.stderr,seen)
report=json.loads((root/'run-report.json').read_text());assert report[-1]['passed']==False
r=run(['--environment','Missing']);assert r.returncode==2
server.shutdown();shutil.rmtree(root);print('CLI e2e passed: chained extraction, CSV row isolation, JSON report, stop-on-failure and exit codes 0/1/2')
