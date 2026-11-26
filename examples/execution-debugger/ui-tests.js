// Browser tests against the normal app.py entry point, with no alternate UI.
// On a freshly loaded page: await (await import('/ui-tests.js')).runAll()
const $=id=>document.getElementById(id);
function check(condition,message){if(!condition)throw Error(message);}
async function settled(){
  const deadline=performance.now()+20000;
  while($('open').disabled){if(performance.now()>deadline)throw Error('Replay UI timed out');await new Promise(resolve=>setTimeout(resolve,25));}
}
async function click(id){$(id).click();await settled();check($('error').hidden,$('error').textContent);}
async function upload(value){
  const files=new DataTransfer();files.items.add(new File([value],'episode.json',{type:'application/json'}));
  $('file').files=files.files;$('file').dispatchEvent(new Event('change',{bubbles:true}));await settled();
}
export const scenarios={
  initial:async()=>{check(document.title==='Moxi execution debugger','Wrong entry point');check($('viewer').hidden,'Fresh viewer must be empty');check($('compare').disabled,'Compare needs an episode');},
  open:async()=>{await click('open');check($('actions').children.length===13,'Expected 12 samples plus stored async result');check($('selection').textContent.includes('tick 12 (120 ms)'),'Missing logical timestamp');check($('state').textContent.includes('No retained sample → 25'),'Sample not applied');check($('work').rows[0].cells[1].textContent==='1','Reading must rebuild');check($('work').rows[1].cells[1].textContent==='0','Unrelated peak must not rebuild');check($('frame').querySelector('svg'),'Missing real Moxi frame');},
  reopen:async()=>{await upload(JSON.stringify(await (await fetch('/fixture')).json()));check($('error').hidden,'Reopen failed');check($('actions').children.length===13,'Reopened action count differs');check($('state').textContent.includes('No retained sample → 25'),'Reopen did not reset the replay');},
  inspect:async()=>{$('actions').lastElementChild.click();check($('selection').textContent.includes('time unknown'),'Invented async timestamp');check($('state').textContent.includes('Unavailable → 84'),'Stored result not applied');check($('work').rows[0].cells[1].textContent==='0','Reading rebuilt on peak action');check($('frame').textContent.includes('84'),'Frame does not show result');},
  compare:async()=>{await click('compare');check($('comparison').textContent.includes('final state matches. Selected frame matches.'),'Comparison mismatch');check($('comparison').textContent.includes('[13, 2] vs broad [14, 14]'),'Not measuring actual replay work');check($('comparison').textContent.includes('[0, 1] vs [1, 1]'),'Selected action not correlated');check($('other-frame').innerHTML===$('frame').innerHTML,'Comparison frames differ');},
  repeat:async()=>{await click('repeat');check($('comparison').textContent.includes('vs localized [13, 2]'),'Repeat work differs');check($('comparison').textContent.includes('Selected frame matches'),'Repeat frame differs');},
  dropped:async()=>{$('capacity').value='5';$('capacity').dispatchEvent(new Event('change',{bubbles:true}));await settled();check($('actions').children.length===5,'Trace capacity ignored');check($('actions').firstElementChild.textContent.startsWith('#9 '),'Dropped actions still shown');check($('gaps').textContent.includes('Trace drops: 8 of 13'),'Missing trace loss indication');check($('gaps').textContent.includes('Source eviction: 12'),'Source and trace loss conflated');},
  missing:async()=>{await upload(JSON.stringify(await (await fetch('/missing-fixture')).json()));check($('error').hidden,'Missing data must remain inspectable');check($('gaps').textContent.includes('Missing retained ticks: 13'),'Missing sample hidden');check($('gaps').textContent.includes('MISSING; cannot replay peak'),'Missing result fabricated');check(!$('actions').textContent.includes('async-result'),'Invented result action');$('actions').lastElementChild.click();check($('frame').textContent.includes('Unavailable'),'Missing result frame not retained');},
  malformed:async()=>{const before=$('frame').innerHTML;await upload('{broken');check(!$('error').hidden,'Malformed JSON was accepted');check($('frame').innerHTML===before,'Failed reopen destroyed last valid frame');},
  recover:async()=>{await click('open');check($('error').hidden,'Error did not clear');check($('gaps').textContent.includes('Async result: recorded peak 84'),'Recovery failed');},
  empty:async()=>{const episode=await (await fetch('/missing-fixture')).json();episode.samples=[];await upload(JSON.stringify(episode));check($('error').hidden,'Empty episode rejected');check($('actions').children.length===0,'Empty episode invented actions');check($('selection').textContent==='No retained actions','Empty frame not explained');await click('open');},
  httpBoundary:async()=>{for(const [body,status] of [[{mode:'unsupported',capacity:5},400],['x'.repeat(10000),413]]){const response=await fetch('/replay',{method:'POST',body:typeof body==='string'?body:JSON.stringify(body)});check(response.status===status,`Boundary expected ${status}, got ${response.status}`);}},
  layout:async()=>{check(document.documentElement.scrollWidth<=innerWidth,'Page overflows viewport');const box=$('frame').getBoundingClientRect();check(box.width>250,'Frame collapsed');},
};
export async function run(name){if(!scenarios[name])throw Error('Unknown UI test');await scenarios[name]();return {scenario:name,outcome:'pass',viewport:[innerWidth,innerHeight]};}
export async function runAll(){const results=[];for(const name of Object.keys(scenarios))results.push(await run(name));return results;}
