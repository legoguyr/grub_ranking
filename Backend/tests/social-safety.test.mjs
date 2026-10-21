import {fixture} from './social-harness.mjs';
import {randomUUID} from 'node:crypto';
const {db,users,actor,rpc,cooking,check,rejects,finish}=await fixture();
try{
 for(let n=0;n<3;n++){await actor(n);await rpc('social_identity','save',{displayName:'Cook '+n,username:'cook_'+n,discoverable:true});}
 await actor(0);await rpc('social_people','request',{peerID:users[1].id});await actor(1);await rpc('social_people','accept',{peerID:users[0].id});
 const source=await cooking(1),post=randomUUID(),comment=randomUUID();
 await db.query("insert into staygrubby.social_posts(id,author_id,source_attempt_id,title,published) values($1,$2,$3,'Shared soup',true)",[post,users[1].id,source.attempts[0]]);
 await db.query("insert into staygrubby.social_comments(id,post_id,author_id,body) values($1,$2,$3,'Nice soup')",[comment,post,users[1].id]);
 async function visible(n){await db.exec('reset role');return (await db.query('select staygrubby.social_can_view($1,$2) ok',[users[n].id,post])).rows[0].ok;}
 check(await visible(0),'Current friend visible');check(await visible(1),'Author visible');check(!await visible(2),'Stranger invisible');
 await actor(2);await rejects(()=>rpc('social_report','report',{targetType:'post',targetID:post,reason:'spam'}));
 await actor(0);
 for(const [kind,target] of [['profile',users[1].id],['post',post],['comment',comment]]){
  check((await rpc('social_report','report',{targetType:kind,targetID:target,reason:'spam',context:' Optional context '})).reported,'Valid report '+kind);
  await rpc('social_report','report',{targetType:kind,targetID:target,reason:'spam'});
 }
 await rejects(()=>rpc('social_report','report',{targetType:'post',targetID:post,reason:'invented'}),'22023');
 await rejects(()=>db.query('select * from staygrubby.social_reports'));
 await rejects(()=>db.query("select api.moderate_social_content('post',$1,'hidden')",[post]));
 await actor(1);await rejects(()=>db.query('select * from staygrubby.social_reports'));
 await db.exec('reset role');check((await db.query('select count(*)::int n from staygrubby.social_reports')).rows[0].n===3,'Duplicate reports deduplicated');
 await db.query("select api.moderate_social_content('post',$1,'hidden')",[post]);check(!await visible(0),'Moderation hides post');
 await db.query("select api.moderate_social_content('post',$1,'active')",[post]);
 await db.query("select api.moderate_social_content('profile',$1,'hidden')",[users[1].id]);
 await actor(1);await rejects(()=>rpc('social_identity','get'));
 check((await db.query('select api.open_account_library() value')).rows[0].value.graph.attempts.length===1,'Moderation never blocks private cooking');
 await actor(0);check(!(await rpc('social_people','search',{query:'cook_1'})).people.length,'Hidden profile not discoverable');
 await db.exec('reset role');await db.query("select api.moderate_social_content('profile',$1,'active')",[users[1].id]);
 await actor(0);await rpc('social_people','block',{peerID:users[1].id});check(!await visible(0),'Block removes content access');
 await actor(0);await rejects(()=>rpc('social_report','report',{targetType:'post',targetID:post,reason:'spam'}));
 await rpc('social_people','unblock',{peerID:users[1].id});check(!await visible(0),'Unblock does not restore friendship/content');
 await actor(0);await rpc('social_people','request',{peerID:users[1].id});await actor(1);await rpc('social_people','accept',{peerID:users[0].id});
 await db.exec('reset role');await db.query("update staygrubby.social_posts set deleted_at=now() where id=$1",[post]);check(!await visible(0),'Deleted post invisible');
 await db.query('delete from staygrubby.accounts where id=$1',[users[1].id]);
 for(const table of ['social_posts','social_comments','social_likes','social_reports'])check((await db.query(`select count(*)::int n from staygrubby.${table}`)).rows[0].n===0,'Account deletion cascades '+table);
 await db.exec('set role anon');await rejects(()=>rpc('social_report','report',{targetType:'profile',targetID:users[0].id,reason:'spam'}));
}finally{await finish();}
