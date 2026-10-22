import {fixture} from './social-harness.mjs';
import {randomUUID} from 'node:crypto';
const {db,users,actor,rpc,cooking,check,rejects,finish}=await fixture();
try {
 const sigmoid=x=>x>=0?1/(1+Math.exp(-x)):Math.exp(x)/(1+Math.exp(x));
 const expected=(s,r)=>r==='Liked it'?7+3*sigmoid(s/1.6-.4):r==='It was fine'?4.8+3*sigmoid(s/1.6):r==="Didn't like it"?1+4.8*sigmoid(s/1.6):1+9*sigmoid(s/2);
 for(const reaction of [null,'Liked it','It was fine',"Didn't like it"]){
  for(const strength of [-12,-4,-2,0,.1,2,4,12]) {
   const metadata=reaction?Buffer.from(JSON.stringify({initialReaction:reaction})):null;
   const actual=(await db.query('select staygrubby.calibrated_cooking_score($1,$2) score',[strength,metadata])).rows[0].score;
   check(Math.abs(actual-expected(strength,reaction))<1e-12,`Server/client formula vector ${strength}/${reaction}`);
  }
 }
 for(const metadata of [{initialReaction:'Liked it',latestSemanticReaction:"Didn't like it"},{initialReaction:'Liked it',latestSemanticReaction:'future'},{initialReaction:'Liked it',latestSemanticReaction:42}]) {
  const actual=(await db.query('select staygrubby.calibrated_cooking_score(2,$1) score',[Buffer.from(JSON.stringify(metadata))])).rows[0].score;
  const latest=metadata.latestSemanticReaction==="Didn't like it"?metadata.latestSemanticReaction:'Liked it';
  check(Math.abs(actual-expected(2,latest))<1e-12,'Latest explicit assessment with initial fallback');
 }
 check((await db.query('select staygrubby.calibrated_cooking_score(0,$1) score',[Buffer.from('legacy')])).rows[0].score===5.5,'Malformed legacy fallback');
 const source=await cooking(0,10),locked=await cooking(1,1);
 await db.query("update staygrubby.ranked_items set session_diagnostics=$1 where account_id=$2",[Buffer.from(JSON.stringify({initialReaction:'Liked it'})),users[0].id]);
 const fingerprint=(await db.query("select md5(jsonb_agg(to_jsonb(t)-'row_version'-'server_updated_at' order by account_id,id)::text) hash from staygrubby.ranked_items t")).rows[0].hash;
 await actor(0);await rpc('social_identity','save',{displayName:'Cook',username:'score_cook',discoverable:true});
 const payload={postID:randomUUID(),attemptID:source.attempts[0],expectedRevision:0,confirmed:true};
 let post=(await rpc('social_content','prepare',payload)).posts[0];check(post.scoreText==='8.2','New snapshot uses calibrated score');
 await db.exec('reset role');await db.query("update staygrubby.ranked_items set session_diagnostics=$1 where account_id=$2",[Buffer.from(JSON.stringify({initialReaction:'Liked it',latestSemanticReaction:"Didn't like it"})),users[0].id]);
 await actor(0);post=(await rpc('social_content','prepare',payload)).posts[0];check(post.scoreText==='8.2','Existing shared snapshot preserved after assessment change');
 const next=(await rpc('social_content','prepare',{...payload,postID:randomUUID(),attemptID:source.attempts[1]})).posts[0];
 check(Number(next.scoreText)<5.8,'Next snapshot uses latest completed reaction');
 await rpc('social_content','delete',{postID:post.id});
 const repost=(await rpc('social_content','prepare',{...payload,postID:randomUUID()})).posts[0];check(Number(repost.scoreText)<5.8,'Explicit new snapshot reflects current assessment');
 await actor(1);await rpc('social_identity','save',{displayName:'Other',username:'locked_cook',discoverable:true});
 const hidden=(await rpc('social_content','prepare',{...payload,postID:randomUUID(),attemptID:locked.attempts[0]})).posts[0];check(hidden.scoreText===null,'Unlock is still ten distinct eligible items');
 await db.exec('reset role');await db.query("update staygrubby.ranked_items set session_diagnostics=$1 where account_id=$2",[Buffer.from(JSON.stringify({initialReaction:'Liked it'})),users[0].id]);
 check((await db.query("select md5(jsonb_agg(to_jsonb(t)-'row_version'-'server_updated_at' order by account_id,id)::text) hash from staygrubby.ranked_items t")).rows[0].hash===fingerprint,'Publication never modifies ranking state');
 for(const role of ['anon','authenticated']) {
  await db.exec('reset role;set role '+role);
  await rejects(()=>db.query('select staygrubby.calibrated_cooking_score(0,null)'));
  await rejects(()=>db.query("select staygrubby.social_content_before_calibration('own','{}')"));
 }
} finally { await finish(); }
