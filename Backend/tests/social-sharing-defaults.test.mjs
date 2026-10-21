import {fixture} from './social-harness.mjs';
const {db,users,actor,rpc,cooking,check,rejects,finish}=await fixture();
try {
 await actor(0);check((await rpc('social_identity','get')).automaticallyShareNewDishes===false,'Legacy default OFF');
 await rejects(()=>rpc('social_identity','sharing',{automaticallyShareNewDishes:true}));
 await rpc('social_identity','save',{displayName:'Private Cook',username:'private_cook',discoverable:false,automaticallyShareNewDishes:false});
 check((await rpc('social_identity','get')).automaticallyShareNewDishes===false,'Social setup may keep OFF');
 await cooking(0,1);await actor(0);
 await rpc('social_identity','sharing',{automaticallyShareNewDishes:true,peerID:users[1].id});
 check((await rpc('social_identity','get')).automaticallyShareNewDishes===true,'Account owner setting persisted');
 await actor(1);check((await rpc('social_identity','get')).automaticallyShareNewDishes===false,'Forged owner cannot change another account preference');
 await rpc('social_identity','save',{displayName:'Second Cook',username:'second_cook',discoverable:true,automaticallyShareNewDishes:true});
 check((await rpc('social_identity','get')).automaticallyShareNewDishes===true,'Setup may intentionally choose ON');
 await actor(0);await rpc('social_identity','save',{displayName:'Edited identity',username:'private_cook',discoverable:false});
 check((await rpc('social_identity','get')).automaticallyShareNewDishes===true,'Old clients preserve chosen default on name edit');
 await rpc('social_identity','sharing',{automaticallyShareNewDishes:false});
 check((await rpc('social_identity','get')).automaticallyShareNewDishes===false,'Default can change later');
 await rejects(()=>rpc('social_identity','sharing',{}),'22023');
 await db.exec('reset role');
 check((await db.query('select count(*)::int n from staygrubby.social_posts')).rows[0].n===0,'Neither setup nor changing preference publishes existing history');
 check((await db.query('select count(*)::int n from staygrubby.cooking_attempts')).rows[0].n===1,'Preference changes preserve private cooking');
 await db.exec('set role anon');await rejects(()=>rpc('social_identity','sharing',{automaticallyShareNewDishes:true}));
} finally {await finish();}
