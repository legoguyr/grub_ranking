#!/usr/bin/env python3
"""Read-only repository allowlist/privileged-secret audit; never prints values."""
import pathlib,re,subprocess
root=pathlib.Path(__file__).resolve().parents[1]
paths=set(subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=root).decode().split('\0'))-{''}
patterns={
 'private_key':r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
 'supabase_secret':r'sb_secret_[A-Za-z0-9_-]{10,}',
 'github_token':r'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})',
 'aws_key':r'AKIA[A-Z0-9]{16}',
 'bearer':r'Bearer\s+eyJ[A-Za-z0-9._-]{40,}',
 'jwt':r'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}',
 'password_uri':r'(?:postgres|postgresql)://[^\s/:]+:[^\s@]{4,}@'}
findings=[];count=0
for name in sorted(paths):
 p=root/name
 if not p.is_file():continue
 if p.suffix.lower() in {'.p8','.p12','.key','.mobileprovision','.ipa'} or name.startswith(('.local-backups/','Backend/tests/node_modules/','supabase/.temp/','supabase/.branches/','Website/public/')):findings.append((name,'local/privileged file'))
 try:content=p.read_text()
 except UnicodeError:continue
 count+=1
 for label,pattern in patterns.items():
  if re.search(pattern,content):findings.append((name,label))
if findings:raise SystemExit('Unsafe file/pattern names: '+repr(findings))
print(f'PASS privileged-secret/local-artifact scan: {count} text files; zero findings')
