import {fixture} from './social-harness.mjs';
const {db,users,actor,rpc,check,rejects,finish}=await fixture();
try {
 await actor(0);
 const legacy=await rpc('social_identity','get');check(legacy.username===null&&!legacy.discoverable,'Legacy identity stays optional/private');
 const a=await rpc('social_identity','save',{displayName:'  Home   Cook  ',username:' @Home_Cook ',discoverable:true});
 check(a.displayName==='Home Cook'&&a.username==='home_cook'&&a.discoverable,'Normalized identity');
 check(Object.keys(a).sort().join(',')==='automaticallyShareNewDishes,avatarPath,discoverable,displayName,username','Only intended self fields');
 for(const username of ['admin','StayGrubby','stay_grubby','system','support'])await rejects(()=>rpc('social_identity','save',{displayName:'A',username}),'23505');
 for(const username of ['ab','_abc','abc_','a__bc','a.bc','a-bc','a bc','école','a'.repeat(25)])await rejects(()=>rpc('social_identity','save',{displayName:'A',username}),'22023');
 await actor(1);await rejects(()=>rpc('social_identity','save',{displayName:'B',username:'HOME_COOK'}),'23505');
 await actor(0);await rpc('social_identity','save',{displayName:'A',username:'new_home',discoverable:false});
 await actor(1);await rejects(()=>rpc('social_identity','save',{displayName:'B',username:'home_cook'}),'23505');
 await actor(0);check((await rpc('social_identity','save',{displayName:'A',username:'home_cook'})).username==='home_cook','Owner may reclaim own reserved handle');
 await rejects(()=>db.query('update staygrubby.profiles set display_name=$1 where account_id=$2',['Forged',users[1].id]));
 await db.exec('reset role;set role anon');await rejects(()=>rpc('social_identity','get'));
 await db.exec('reset role');
 check((await db.query('select count(*)::int n from staygrubby.ranked_items')).rows[0].n===0,'Identity creates no cooking data');
 await db.query('delete from staygrubby.accounts where id=$1',[users[0].id]);
 check((await db.query('select count(*)::int n from staygrubby.username_reservations where account_id=$1',[users[0].id])).rows[0].n===0,'Deletion cascades reservations');
}finally{await finish();}
