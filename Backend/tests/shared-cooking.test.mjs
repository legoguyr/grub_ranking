import {fixture} from './social-harness.mjs';
import {randomUUID} from 'node:crypto';
const f=await fixture(),{db,users,actor,rpc,cooking,check,rejects}=f;
try {
 for(let n=0;n<4;n++){await actor(n);await rpc('social_identity','save',{displayName:'Shared Cook '+n,username:'shared_'+n,discoverable:true});}
 const a=await cooking(0,10),b=await cooking(1,1);
 async function friends(x,y){await actor(x);await rpc('social_people','request',{peerID:users[y].id});await actor(y);await rpc('social_people','accept',{peerID:users[x].id});}
 await friends(0,1);await friends(0,2);
 await db.exec('reset role');
 const fingerprint=async n=>(await db.query("select md5(coalesce((select jsonb_agg(to_jsonb(a) order by id)::text from staygrubby.cooking_attempts a where account_id=$1),'')||coalesce((select jsonb_agg(to_jsonb(i) order by id)::text from staygrubby.ranked_items i where account_id=$1),'')||coalesce((select jsonb_agg(to_jsonb(c) order by id)::text from staygrubby.comparisons c where account_id=$1),'')) h",[users[n].id])).rows[0].h;
 const before=await fingerprint(0),beforeB=await fingerprint(1);
 await actor(0);const eid=randomUUID(),create={eventID:eid,attemptID:a.attempts[0],participantIDs:[users[1].id,users[2].id],confirmed:true};
 await rejects(()=>rpc('social_cooking','create',{...create,eventID:randomUUID(),participantIDs:[users[3].id]}));
 await rejects(()=>rpc('social_cooking','create',{...create,eventID:randomUUID(),participantIDs:[users[0].id]}));
 await rejects(()=>rpc('social_cooking','create',{...create,attemptID:b.attempts[0]}));
 const event=await rpc('social_cooking','create',create);
 check(event.participants.length===2&&event.isOwner,'Multiple independent pending invitations');
 check((await rpc('social_cooking','create',create)).id===eid,'Create retry idempotent');
 check(!JSON.stringify(event).match(/strength|score|notes|allergen|photoPath|rankedItem|comparison/),'Invitation has only safe metadata');
 await actor(3);await rejects(()=>rpc('social_cooking','event',{eventID:eid}));await rejects(()=>rpc('social_cooking','claim',{eventID:eid}));
 await actor(1);check((await rpc('social_notifications','page')).notifications.some(n=>n.kind==='invited'&&n.targetID===eid),'Recipient gets invitation');
 const origin=await rpc('social_cooking','claim',{eventID:eid});
 check((await rpc('social_cooking','claim',{eventID:eid})).itemID===origin.itemID,'Join reserves one durable personal item identity');
 await rejects(()=>rpc('social_cooking','complete',{originID:origin.id}),'40001');
 await db.exec('reset role');check(await fingerprint(1)===beforeB,'Claim/abandoned draft creates no private cook/item/evidence');
 await actor(2);await rpc('social_cooking','decline',{eventID:eid});await rejects(()=>rpc('social_cooking','claim',{eventID:eid}));
 await actor(3);await rejects(()=>rpc('social_cooking','complete',{originID:origin.id}));
 // Simulate ONLY B's independently saved/synced new cook. No A evidence is copied.
 await db.exec('reset role');const dish=randomUUID(),attempt=randomUUID();
 await db.query("insert into staygrubby.dishes(account_id,id,name,default_course_code,created_at_ref) values($1,$2,'My independently reviewed cook','main',2000)",[users[1].id,dish]);
 await db.query("insert into staygrubby.ranked_items(account_id,id,ranking_id,name,created_at_ref,strength,uncertainty) values($1,$2,$3,'B cook',2000,0,1)",[users[1].id,origin.itemID,b.ranking]);
 await db.query("insert into staygrubby.cooking_attempts(account_id,id,dish_id,ranked_item_id,course_code,sequence_number,created_at_ref,updated_at_ref,is_legacy_import) values($1,$2,$3,$4,'main',1,2000,2000,false)",[users[1].id,attempt,dish,origin.itemID]);
 await actor(1);check((await rpc('social_cooking','complete',{originID:origin.id})).completed,'Completes only after OWN synced cook exists');
 check((await rpc('social_cooking','complete',{originID:origin.id})).completed,'Complete retry idempotent');
 await actor(0);check((await rpc('social_cooking','event',{eventID:eid})).participants.find(p=>p.person.id===users[1].id).state==='joined','Owner sees actual ranked participation');
 check((await rpc('social_notifications','page')).notifications.filter(n=>n.kind==='joined').length===1,'One joined notification');
 const postID=randomUUID();await rpc('social_content','prepare',{postID,attemptID:a.attempts[1],confirmed:true,expectedRevision:0});
 await actor(3);await rejects(()=>rpc('social_cooking','recreate',{postID}));
 await actor(1);const recreated=await rpc('social_cooking','recreate',{postID});
 check(recreated.kind==='recreated'&&!recreated.completed,'Make This reserves provenance without saving a cook');
 check((await rpc('social_cooking','recreate',{postID})).id===recreated.id,'Recreate retry returns same draft');
 check(recreated.metadata.title==='Private fixture soup','Only explicit social snapshot provides title');
 check(!JSON.stringify(recreated).match(/score|strength|notes|comparison|photoPath/),'No private or unlocked numerical fields in prefill');
 await actor(0);await rpc('social_people','block',{peerID:users[1].id});
 await actor(1);await rejects(()=>rpc('social_cooking','event',{eventID:eid}));await rejects(()=>rpc('social_cooking','recreate',{postID}));
 check(!(await rpc('social_notifications','page')).notifications.some(n=>n.actor.id===users[0].id),'Blocking removes inaccessible notification targets');
 check((await rpc('social_cooking','own',{targetID:origin.itemID})).origins[0].creator==null,'Personal provenance does not leak blocked identity');
 await db.exec('reset role');check(await fingerprint(0)===before,'All source ranking/attempt/evidence rows unchanged');
 check((await db.query('select count(*)::int n from staygrubby.cooking_attempts where account_id=$1',[users[1].id])).rows[0].n===2,'Recipient has only deliberately completed private entries');
 const bAfter=await fingerprint(1);
 await db.query('delete from staygrubby.accounts where id=$1',[users[0].id]);
 check(await fingerprint(1)===bAfter,'Deleting source account preserves completed recipient cooking/ranking');
 check((await db.query('select count(*)::int n from staygrubby.shared_cooks')).rows[0].n===0,'Owner events cascade');
 check((await db.query('select creator_id,event_id,post_id from staygrubby.cooking_origins where account_id=$1',[users[1].id])).rows.every(r=>!r.creator_id&&!r.event_id&&!r.post_id),'Cross-account provenance nullifies safely');
 await db.exec('set role anon');await rejects(()=>rpc('social_cooking','own'));await rejects(()=>rpc('social_notifications','page'));
 await db.exec('reset role;set role authenticated');await rejects(()=>db.query('select * from staygrubby.cooking_origins'));
} finally {await f.finish();}
