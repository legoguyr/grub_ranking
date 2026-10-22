import {fixture} from './social-harness.mjs';
import {randomUUID} from 'node:crypto';
const {db,users,actor,rpc,cooking,check,rejects,finish}=await fixture();
try {
 for(let n=0;n<3;n++){await actor(n);await rpc('social_identity','save',{displayName:'Cook '+n,username:'caption_cook_'+n,discoverable:true});}
 const source=await cooking(0,30);
 await db.exec('reset role');
 await db.query("update staygrubby.cooking_attempts set notes='PERSONAL NOTES MUST REMAIN PRIVATE' where account_id=$1",[users[0].id]);
 const fingerprint=async()=> (await db.query("select md5((select jsonb_agg(to_jsonb(i) order by account_id,id)::text from staygrubby.ranked_items i)||(select jsonb_agg(to_jsonb(a) order by account_id,id)::text from staygrubby.cooking_attempts a)) hash")).rows[0].hash;
 const before=await fingerprint(); await actor(0);
 const id=randomUUID(),payload={postID:id,attemptID:source.attempts[0],expectedRevision:0,confirmed:true,postDescription:'  Loved making this soup.\nWorth the wait!  ',includeAttribution:true};
 let p=(await rpc('social_content','prepare',payload)).posts[0];
 check(p.postDescription==='Loved making this soup.\nWorth the wait!','Explicit caption, trimmed edges and preserved paragraphs');
 check(p.metadata.course==='soup','Previously consented Course exposed');
 check(!JSON.stringify(p).includes('PERSONAL NOTES'),'No private note copied or serialized');
 check(!('notes' in p)&&!('tags' in p.metadata)&&!('allergens' in p.metadata)&&!('dietary' in p.metadata),'Private metadata excluded');
 check((await rpc('social_content','prepare',{...payload,postDescription:'Retry must not overwrite'})).posts[0].postDescription===p.postDescription,'Prepare retry preserves existing caption');
 check((await rpc('social_content','prepare',{...payload,postID:randomUUID(),postDescription:'Different identity retry'})).posts[0].id===id,'One active snapshot per cook');
 p=(await rpc('social_content','editDescription',{postID:id,postDescription:'Updated intentionally',notes:'NEVER ACCEPT PRIVATE FIELDS',title:'Ignored'})).posts[0];
 check(p.postDescription==='Updated intentionally'&&p.title!=='Ignored','Only caption editable');
 check(!JSON.stringify(p).includes('NEVER ACCEPT PRIVATE FIELDS'),'Unrecognized fields never echoed');
 await rejects(()=>rpc('social_content','editDescription',{postID:id}),'22023');
 for(const value of ['x'.repeat(2001),'bad\u0001text',42,{},[]]) {
  await rejects(()=>rpc('social_content','editDescription',{postID:id,postDescription:value}),'22023');
 }
 check((await rpc('social_content','editDescription',{postID:id,postDescription:'🍲'.repeat(2000)})).posts[0].postDescription.length===4000,'2000 Unicode scalars allowed within byte budget');
 check((await rpc('social_content','editDescription',{postID:id,postDescription:''})).posts[0].postDescription===null,'Empty clears description');
 await rpc('social_content','editDescription',{postID:id,postDescription:'Visible only to authorized people'});
 const legacy=(await rpc('social_content','prepare',{...payload,postID:randomUUID(),attemptID:source.attempts[1],postDescription:undefined,includeAttribution:false})).posts[0];
 check(legacy.postDescription===null&&Object.keys(legacy.metadata).length===0,'Old-client preparation has no caption or implicit metadata');
 await actor(1);await rejects(()=>rpc('social_content','editDescription',{postID:id,postDescription:'Not mine'}));
 check((await rpc('social_feed','profile',{peerID:users[0].id})).posts.length===0,'Stranger profile never reveals posts');
 await rejects(()=>rpc('social_feed','post',{postID:id}));
 await actor(0);await rpc('social_people','request',{peerID:users[1].id});await actor(1);await rpc('social_people','accept',{peerID:users[0].id});
 check((await rpc('social_feed','profile',{peerID:users[0].id})).posts.length===2,'Friend sees only author’s authorized posts');
 check((await rpc('social_feed','post',{postID:id})).posts[0].postDescription==='Visible only to authorized people','Detail and profile share authorization');
 await rejects(()=>rpc('social_content','editDescription',{postID:id,postDescription:'Still not mine'}));
 await actor(0);
 for(const attempt of source.attempts.slice(2,29)) await rpc('social_content','prepare',{postID:randomUUID(),attemptID:attempt,expectedRevision:0,confirmed:true});
 let page=await rpc('social_feed','profile');check(page.posts.length===25,'Own profile bounded page');
 const last=page.posts.at(-1); const rest=await rpc('social_feed','profile',{beforeTime:last.createdAt,beforeID:last.id});
 check(rest.posts.length===4,'Profile keyset pagination includes remaining posts');
 check(new Set([...page.posts,...rest.posts].map(p=>p.id)).size===29,'Stable IDs no duplicate page entries');
 await rejects(()=>rpc('social_feed','profile',{beforeTime:last.createdAt}),'22023');
 const draft=(await rpc('social_content','prepare',{postID:randomUUID(),attemptID:source.attempts[29],expectedRevision:0,confirmed:true,includePhoto:true,postDescription:'Draft'})).posts[0];
 check(!(await rpc('social_feed','profile')).posts.some(p=>p.id===draft.id),'Unpublished drafts absent from profile');
 await db.exec('reset role');await db.query("update staygrubby.social_posts set moderation_state='hidden' where id=$1",[id]);await actor(0);
 await rejects(()=>rpc('social_content','editDescription',{postID:id,postDescription:'Cannot revive moderation'}));
 check(!(await rpc('social_feed','profile')).posts.some(p=>p.id===id),'Own profile respects moderation');
 await db.exec('reset role');await db.query("update staygrubby.social_posts set moderation_state='active' where id=$1",[id]);await actor(0);
 await rpc('social_people','block',{peerID:users[1].id});await actor(1);
 check((await rpc('social_feed','profile',{peerID:users[0].id})).posts.length===0,'Block revokes profile grid');
 await rejects(()=>rpc('social_feed','post',{postID:id}));
 await actor(0);await rpc('social_content','delete',{postID:id});
 await rejects(()=>rpc('social_content','editDescription',{postID:id,postDescription:'Cannot resurrect'}));
 await db.exec('reset role');check(await fingerprint()===before,'Caption/profile operations preserve private items/notes/evidence');
 check((await db.query("select relrowsecurity ok from pg_class where oid='staygrubby.social_posts'::regclass")).rows[0].ok,'Posts RLS retained');
 for(const role of ['anon','authenticated']) {
  await db.exec('reset role;set role '+role);await rejects(()=>db.query('select * from staygrubby.social_posts'));
 }
 await db.exec('reset role;set role anon');await rejects(()=>rpc('social_feed','profile'));await rejects(()=>rpc('social_content','editDescription',{postID:id,postDescription:'No auth'}));
 await db.exec('reset role');
 for(const fn of ['social_post_card','social_post_card_before_description','social_content_before_description','social_feed_before_profile']) {
  check((await db.query("select bool_and(not has_function_privilege('anon',p.oid,'EXECUTE') and not has_function_privilege('authenticated',p.oid,'EXECUTE')) ok from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='staygrubby' and p.proname=$1",[fn])).rows[0].ok,'Private helper not callable: '+fn);
 }
} finally {await finish();}
