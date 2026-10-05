(function () {
  var ua = navigator.userAgent, p = navigator.platform || '';
  var os = /Mac/.test(p) || /Mac OS/.test(ua) ? ['macOS', 'macos-universal.zip']
    : /Win/.test(p) ? ['Windows', 'windows-x86_64.zip']
    : /aarch64|arm64/i.test(ua) && /Linux/.test(ua) ? ['Linux arm64', 'linux-arm64.tar.gz']
    : /Linux|X11/.test(ua) ? ['Linux', 'linux-x86_64.tar.gz'] : null;
  var links = [].slice.call(document.querySelectorAll('[data-asset]'));
  var hero = document.getElementById('hero-dl');
  function setOs() {
    if (!os) return;
    hero.querySelector('[data-os]').textContent = os[0];
    var m = links.filter(function (a) { return a.dataset.asset === os[1]; })[0];
    if (m) { hero.href = m.href; m.style.outline = '3px solid #fff'; m.style.outlineOffset = '3px'; }
  }
  setOs();
  fetch('https://api.github.com/repos/AgentiLoop/GoKart/releases/latest').then(function (r) { return r.ok ? r.json() : null; }).then(function (rel) {
    if (!rel || !rel.assets) return;
    links.forEach(function (a) {
      var as = rel.assets.filter(function (x) { return x.name.slice(-a.dataset.asset.length) === a.dataset.asset; })[0];
      if (as) a.href = as.browser_download_url;
    });
    document.getElementById('ver').textContent = String(rel.tag_name || '').replace(/^v/, '') || '0.0.2';
    setOs();
  }).catch(function () {});

  var lb = document.getElementById('lb'), lbi = lb.querySelector('img');
  document.addEventListener('click', function (e) {
    var t = e.target;
    if (t.tagName === 'IMG' && t.closest('.card,.modes,.split')) { lbi.src = t.src; lbi.alt = t.alt; lb.hidden = false; }
    else if (!lb.hidden) lb.hidden = true;
  });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') lb.hidden = true; });

  var f = document.getElementById('fb-form'), st = document.getElementById('fb-status');
  f.addEventListener('submit', function (e) {
    e.preventDefault();
    var d = Object.fromEntries(new FormData(f).entries());
    if (!d.message || d.message.trim().length < 3) { st.className = 'err'; st.textContent = 'Please write a message first.'; return; }
    var b = f.querySelector('button'); b.disabled = true; st.className = ''; st.textContent = 'Sending...';
    fetch('/api/feedback', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(d) })
      .then(function (r) { return r.json().catch(function () { return {}; }).then(function (j) { return [r.ok, j]; }); })
      .then(function (x) {
        if (x[0]) { st.className = 'ok'; st.textContent = 'Thanks! Your feedback was sent.'; f.reset(); }
        else { st.className = 'err'; st.textContent = x[1].error || 'Could not send. Please email gokart@gokart.games.'; }
      })
      .catch(function () { st.className = 'err'; st.textContent = 'Network error. Please email gokart@gokart.games.'; })
      .then(function () { b.disabled = false; });
  });
})();
