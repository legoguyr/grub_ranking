import {fixture} from './social-harness.mjs';
import {randomUUID} from 'node:crypto';
const {db,users,actor,rpc,cooking,check,rejects,finish}=await fixture();
try {
 for(let n=0;n<3;n++){await actor(n);await rpc('social_identity','save',{displayName:'Cook '+n,username:'feed_'+n,discoverable:true});}
 const source=await cooking(0,30);await actor(0);
 for(const attemptID of source.attempts)await rpc('social_content','prepare',{postID:randomUUID(),attemptID,expectedRevision:0,confirmed:true});
 await db.exec('reset role');await db.query("update staygrubby.social_posts set created_at='2026-10-20T12:00:00Z'");
 await actor(0);const own=(await rpc('social_feed','page')).posts;check(own.length===25,'Author feed bounded');
 check(own.every((p,i)=>!i||p.id<own[i-1].id),'Timestamp ties ordered by id');
 const last=own.at(-1);const second=(await rpc('social_feed','page',{beforeTime:last.createdAt,beforeID:last.id})).posts;
 check(second.length===5&&!second.some(p=>own.some(o=>o.id===p.id)),'Keyset pagination covers all posts without duplication');
 await rejects(()=>rpc('social_feed','page',{beforeID:last.id}),'22023');
 await actor(1);check((await rpc('social_feed','page')).posts.length===0,'Stranger feed empty');
 await rejects(()=>rpc('social_feed','post',{postID:last.id}));
 await actor(0);await rpc('social_people','request',{peerID:users[1].id});await actor(1);await rpc('social_people','accept',{peerID:users[0].id});
 check((await rpc('social_feed','page')).posts.length===25,'Friends see published posts');
 await actor(0);await rpc('social_identity','save',{displayName:'Cook 0',username:'feed_0',discoverable:false});await actor(1);
 check((await rpc('social_feed','page')).posts.length===25,'Discoverability off does not hide existing friend posts');
 await rpc('social_people','remove',{peerID:users[0].id});check((await rpc('social_feed','page')).posts.length===0,'Removed friend loses feed');
 await actor(0);await rpc('social_people','request',{peerID:users[1].id});await actor(1);await rpc('social_people','accept',{peerID:users[0].id});
 await rpc('social_people','block',{peerID:users[0].id});check((await rpc('social_feed','page')).posts.length===0,'Blocked pair loses feed');
 await actor(0);await rpc('social_content','delete',{postID:last.id});await rejects(()=>rpc('social_feed','post',{postID:last.id}));
 await db.exec('reset role');await db.query("update staygrubby.social_posts set moderation_state='hidden' where id=$1",[own[0].id]);
 await actor(0);check(!(await rpc('social_feed','page')).posts.some(p=>p.id===own[0].id),'Hidden post excluded even from author feed');
 const card=(await rpc('social_feed','post',{postID:second[0].id})).posts[0];
 check(!('attemptID' in card)&&!('source_attempt_id' in card)&&!('notes' in card),'Feed exposes snapshots only');
 await db.exec('reset role');await db.query("update staygrubby.accounts set status='deleting' where id=$1",[users[0].id]);await actor(0);
 await rejects(()=>rpc('social_feed','page'));await db.exec('reset role;set role anon');await rejects(()=>rpc('social_feed','page'));
}finally{await finish();}
