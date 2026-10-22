import {fixture} from './social-harness.mjs';
import {randomUUID} from 'node:crypto';
const {db,users,actor,rpc,cooking,check,rejects,finish}=await fixture();
for(let n=0;n<3;n++){await actor(n);await rpc('social_identity','save',{displayName:'Recipe Cook '+n,username:'recipe_cook_'+n,discoverable:true});}
async function friends(a,b){await actor(a);await rpc('social_people','request',{peerID:users[b].id});await actor(b);await rpc('social_people','accept',{peerID:users[a].id});}
await friends(0,1);await friends(0,2);
const a=await cooking(0),b=await cooking(1),c=await cooking(2);
const rid=randomUUID(),reservation=randomUUID();
await actor(0);await rpc('recipes','save',{recipeID:rid,recipe:{title:'Original recipe',ingredients:['Lemon'],steps:['Cook'],source:'A cookbook',course:'soup'},visibility:'friends'});
const origin=await rpc('recipes','begin',{recipeID:rid,originID:reservation});
// Only disposable fixture graphs. Simulate a distinct cook saved/synced by the native flow.
async function saved(n,ranking,claim){
 await db.exec('reset role');const dish=randomUUID(),attempt=randomUUID();
 await db.query("insert into staygrubby.dishes(account_id,id,name,default_course_code,created_at_ref) values($1,$2,'Reviewed own recipe cook','soup',2000)",[users[n].id,dish]);
 await db.query("insert into staygrubby.ranked_items(account_id,id,ranking_id,name,created_at_ref,strength,uncertainty) values($1,$2,$3,'Own version',2000,0,1)",[users[n].id,claim.itemID,ranking]);
 await db.query("insert into staygrubby.cooking_attempts(account_id,id,dish_id,ranked_item_id,course_code,sequence_number,created_at_ref,updated_at_ref,is_legacy_import) values($1,$2,$3,$4,'soup',1,2000,2000,false)",[users[n].id,attempt,dish,claim.itemID]);return attempt;
}
const attempt=await saved(0,a.ranking,origin);await actor(0);await rpc('recipes','complete',{originID:origin.id});
const postID=randomUUID();await rpc('social_content','prepare',{postID,attemptID:attempt,expectedRevision:0,confirmed:true,includeAttribution:true});
await actor(1);const post=(await rpc('social_feed','post',{postID})).posts[0];check(post.recipeID===rid,'authorized post exposes recipe reference');
const rerun=await rpc('social_cooking','recreate',{postID});check(rerun.recipeOriginID&&rerun.recipeSnapshot.source==='A cookbook','Run It Back keeps original recipe source');check(rerun.kind==='recreated'&&rerun.id!==origin.id,'social origin remains independent');
check((await rpc('social_cooking','recreate',{postID})).recipeOriginID===rerun.recipeOriginID,'retry does not duplicate recipe origin');
await rejects(()=>rpc('recipes','complete',{originID:rerun.recipeOriginID,attemptID:attempt}),'40001');
await saved(1,b.ranking,rerun);await actor(1);await rpc('recipes','complete',{originID:rerun.recipeOriginID});await rpc('social_cooking','complete',{originID:rerun.id});
const provenance=await rpc('social_cooking','own',{targetID:rerun.itemID});check(provenance.origins[0].creator.id===users[0].id,'social inspiration survives');
check((await rpc('recipes','provenance',{targetID:rerun.itemID})).cooks[0].snapshot.source==='A cookbook','source attribution separate');
await actor(0);const event=randomUUID();await rpc('social_cooking','create',{eventID:event,attemptID:attempt,participantIDs:[users[2].id],confirmed:true});
await actor(2);const joined=await rpc('social_cooking','claim',{eventID:event});check(joined.recipeOriginID&&joined.recipeSnapshot.title==='Original recipe','shared cooking interoperates with recipe');
await rejects(()=>rpc('recipes','complete',{originID:origin.id}));await rejects(()=>rpc('social_cooking','complete',{originID:rerun.id}));
await actor(0);await rpc('recipes','save',{recipeID:rid,expectedRevision:1,recipe:{title:'Changed recipe',ingredients:[],steps:[],source:'Changed source'},visibility:'private'});
await actor(1);check(!(await rpc('social_feed','post',{postID})).posts[0].recipeID,'private recipe reference no longer disclosed');
check((await rpc('recipes','provenance',{targetID:rerun.itemID})).cooks[0].snapshot.source==='A cookbook','historical cooking not rewritten');
const legacyID=randomUUID();await actor(0);await rpc('social_content','prepare',{postID:legacyID,attemptID:a.attempts[0],expectedRevision:0,confirmed:true});await actor(1);
check(!(await rpc('social_cooking','recreate',{postID:legacyID})).recipeOriginID,'legacy posts remain safe without forced recipe backfill');
await db.exec('reset role');const before=(await db.query('select to_jsonb(a) a from staygrubby.cooking_attempts a where account_id=$1 order by id',[users[1].id])).rows;
await db.query('delete from staygrubby.accounts where id=$1',[users[0].id]);
check(JSON.stringify((await db.query('select to_jsonb(a) a from staygrubby.cooking_attempts a where account_id=$1 order by id',[users[1].id])).rows)===JSON.stringify(before),'account deletion preserves survivor private cooks byte-for-byte');
await actor(1);check((await rpc('recipes','provenance',{targetID:rerun.itemID})).cooks[0].recipeID===null,'deleted creator reference nullified');
check((await rpc('social_cooking','own',{targetID:rerun.itemID})).origins[0].creator===null,'deleted social creator no longer exposed');
await finish();
