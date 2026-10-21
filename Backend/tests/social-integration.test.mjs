import {fixture} from './social-harness.mjs';
import {randomUUID} from 'node:crypto';
const {db,users,actor,rpc,cooking,check,rejects,finish}=await fixture();
try{
 await actor(3);const legacy=(await db.query('select api.open_account_library() value')).rows[0].value;
 check(legacy.graph.dishes.length===0,'Legacy account without social identity keeps private cooking access');
 check((await rpc('social_identity','get')).username===null,'No forced social identity');
 for(let n=0;n<3;n++){await actor(n);await rpc('social_identity','save',{displayName:'Integrated Cook '+n,username:'integrated_'+n,discoverable:true});}
 const own=await cooking(0,10);await cooking(1,1);
 const fingerprint=async(owner)=>{await db.exec('reset role');return (await db.query("select md5(jsonb_build_object('items',(select jsonb_agg(to_jsonb(i) order by id) from staygrubby.ranked_items i where account_id=$1),'attempts',(select jsonb_agg(to_jsonb(a) order by id) from staygrubby.cooking_attempts a where account_id=$1),'evidence',(select jsonb_agg(to_jsonb(c) order by id) from staygrubby.comparisons c where account_id=$1),'revision',(select sync_revision from staygrubby.accounts where id=$1))::text) hash",[owner])).rows[0].hash;};
 const before=await fingerprint(users[0].id),otherBefore=await fingerprint(users[1].id);
 await actor(0);await rpc('social_identity','save',{displayName:'Renamed Cook',username:'renamed_cook',discoverable:false});
 await actor(1);await rejects(()=>rpc('social_identity','save',{displayName:'Impersonator',username:'integrated_0',discoverable:true}),'23505');
 await actor(0);
 for(let n=1;n<3;n++){await rpc('social_people','request',{peerID:users[n].id});await actor(n);await rpc('social_people','accept',{peerID:users[0].id});await actor(0);}
 const postID=randomUUID(),photo=(await rpc('social_content','prepare',{postID,attemptID:own.attempts[0],confirmed:true,expectedRevision:0,includePhoto:true})).posts[0];
 await db.query("select set_config('storage.operation','object.upload',false)");await db.query("insert into storage.objects(bucket_id,name,metadata) values('social-photos',$1,'{\"size\":100,\"mimetype\":\"image/jpeg\"}')",[photo.photoPath]);await rpc('social_content','publish',{postID});
 await actor(1);check((await rpc('social_feed','page')).posts.length===1,'Existing friend sees undiscoverable author post');
 check((await db.query('select count(*)::int n from staygrubby.cooking_attempts')).rows[0].n===1,'Friend sees only own private cook, never the shared source graph');
 await rpc('social_interactions','like',{postID});const commentID=randomUUID();await rpc('social_interactions','comment',{postID,commentID,body:'Delicious!'});
 await actor(2);await rpc('social_report','report',{targetType:'comment',targetID:commentID,reason:'other',context:'Synthetic integration review'});
 await rpc('social_people','block',{peerID:users[1].id});
 check((await rpc('social_interactions','comments',{postID})).comments.length===0,'Blocked commenter cannot leak through a shared third-party post');
 await actor(0);await rpc('social_people','remove',{peerID:users[1].id});
 check((await rpc('social_feed','post',{postID})).posts[0].likeCount===0,'Removed participant no longer contributes visible engagement');
 check(await fingerprint(users[0].id)===before,'Identity, friendships, posts, photos and engagement preserve private caches/evidence/identities/revision');
 check(await fingerprint(users[1].id)===otherBefore,'Another private library remains unchanged');
 await actor(0);await db.query('select api.begin_account_deletion()');
 await rejects(()=>rpc('social_feed','page'));
 await actor(2);check((await rpc('social_feed','page')).posts.length===0,'Deleting author immediately disappears before graph erasure');
 await db.exec('reset role;set role service_role');
 await db.query("select api.advance_account_deletion($1,'apple_revoked')",[users[0].user]);await db.query("select api.advance_account_deletion($1,'storage_cleared')",[users[0].user]);
 await rejects(()=>db.query('select api.erase_account_data($1)',[users[0].user]),'55000');
 await db.exec('reset role');await db.query("delete from storage.objects where bucket_id='social-photos' and name=$1",[photo.photoPath]);await db.exec('set role service_role');
 await db.query('select api.erase_account_data($1)',[users[0].user]);await db.exec('reset role');
 for(const table of ['username_reservations','social_posts','social_comments','social_likes','social_reports'])check((await db.query(`select count(*)::int n from staygrubby.${table}`)).rows[0].n===0,table+' cascades on disposable account erasure');
 check((await db.query('select count(*)::int n from staygrubby.friendships where low_id=$1 or high_id=$1',[users[0].id])).rows[0].n===0,'Friendships cascade');
 check((await db.query('select count(*)::int n from staygrubby.social_blocks where blocker_id=$1 or blocked_id=$1',[users[0].id])).rows[0].n===0,'Owned block references cascade');
 check(await fingerprint(users[1].id)===otherBefore,'Deletion leaves another account cooking untouched');
 await db.exec('reset role');await db.query('delete from auth.users where id=$1',[users[0].user]);await actor(0);await rejects(()=>rpc('social_feed','page'));
 await db.exec('reset role');check((await db.query('select count(*)::int n from staygrubby.accounts where id=$1',[users[0].id])).rows[0].n===0,'Stale social calls cannot reprovision a deleted account');
 const internal=(await db.query("select count(*)::int n from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='staygrubby' and p.proname in ('social_post_card','social_can_view','social_participant','social_actor','social_person') and has_function_privilege('authenticated',p.oid,'execute')")).rows[0].n;
 check(internal===0,'No client access to arbitrary-viewer internal helper overloads');
}finally{await finish();}
