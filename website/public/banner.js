// "Looking for MarioKart64JS?" banner: twisting neon Rainbow Road ribbons racing
// through deep space, in WebGL. Falls back to the CSS gradient on .mk-banner.
(function () {
  var cv = document.getElementById('mk-gl');
  if (!cv) return;
  var gl = cv.getContext('webgl', { alpha: false, antialias: false, premultipliedAlpha: false });
  if (!gl) { cv.remove(); return; }
  var vs = 'attribute vec2 p;void main(){gl_Position=vec4(p,0.,1.);}';
  var fs = [
    'precision highp float;uniform vec2 r;uniform float t;uniform float b;uniform float m;',
    'vec3 hue(float h){return clamp(abs(fract(h+vec3(0.,2./3.,1./3.))*6.-3.)-1.,0.,1.);}',
    'float hs(vec2 c){return fract(sin(dot(c,vec2(12.9898,78.233)))*43758.5453);}',
    // streaking star layer
    'float stars(vec2 uv,float sc,float sp,float th){',
    ' vec2 q=uv*sc;q.x+=t*sp;vec2 c=floor(q),f=fract(q)-.5;float h=hs(c);',
    ' vec2 o=vec2(hs(c+7.1),hs(c+3.7))-.5;vec2 d=(f-o*.6)*vec2(1./(1.+sp*.35*(1.+b*2.)),1.);',
    ' return step(th,h)*smoothstep(.09,0.,length(d))*(.6+.4*sin(t*7.+h*60.));}',
    // one twisting rainbow ribbon; returns premultiplied rgb in .rgb and coverage in .a
    'vec4 road(vec2 uv,float amp,float fr,float ph,float w,float sp,float tw){',
    ' float x=uv.x,a1=x*fr+ph,a2=x*fr*2.3-ph*1.7;',
    ' float c=amp*(sin(a1)+.45*sin(a2)),dc=amp*fr*(cos(a1)+.45*2.3*cos(a2));',
    ' float tc=cos(x*tw-t*.35+ph*.3);float ww=w*(.25+.75*abs(tc));',
    ' float d=(uv.y-c)/sqrt(1.+dc*dc),a=abs(d)/ww;',
    ' float s=x*1.6+t*sp;float seg=floor(s);',
    ' vec3 col=mix(hue(seg/7.),hue((seg+1.)/7.),smoothstep(.8,1.,fract(s)));',
    ' col*=(tc<0.?.45:1.)*(.55+.45*(1.-a*a));',
    ' col+=vec3(1.)*step(.55,fract(x*5.+t*sp*3.))*smoothstep(.09,.0,a)*.55;',
    ' float body=smoothstep(1.,.9,a);',
    ' float px=1.5/r.y/ww;float rail=smoothstep(px*2.,0.,abs(a-1.));',
    ' float lamp=pow(max(0.,1.-abs(fract(x*6.+t*sp*2.)-.5)*5.),3.)*smoothstep(px*5.,0.,abs(a-1.));',
    ' vec3 rc=hue(seg/7.+.5)*.5+.6;',
    ' vec3 o=col*body+rc*rail*.9+vec3(1.,.95,.8)*lamp*1.6;',
    ' o+=hue(s/7.)*exp(-max(a-1.,0.)*ww*14.)*(1.-body)*(.35+.35*b);',
    ' return vec4(o,body);}',
    'void main(){',
    ' vec2 uv=(gl_FragCoord.xy-.5*r)/r.y;float ar=r.x/r.y;',
    ' vec3 col=mix(vec3(.01,.01,.05),vec3(.06,.02,.14),gl_FragCoord.y/r.y);',
    ' float n=sin(uv.x*.7+t*.1)*sin(uv.x*1.9-t*.13+uv.y*3.)*.5+.5;',
    ' col+=mix(vec3(.25,.05,.4),vec3(.0,.25,.35),sin(uv.x*.3+t*.05)*.5+.5)*n*.18;',
    ' col+=stars(uv,9.,1.2,.93)*.35+stars(uv,5.,2.5,.95)*.6+stars(uv,3.,5.,.97);',
    ' vec4 rb=road(uv+vec2(m*.6,0.),.16,.9,t*.25+2.,.06,1.,.45);',
    ' col=col*(1.-rb.a*.6)+rb.rgb*.55;',
    ' vec4 rf=road(uv+vec2(m*1.4,0.),.2,.55,t*.4,.15,2.2,.3);',
    ' col=col*(1.-rf.a)+rf.rgb;',
    ' col*=smoothstep(0.,1.6,ar*.5-abs(uv.x))*.75+.25;',
    ' col=1.-exp(-col*1.25);',
    ' gl_FragColor=vec4(col,1.);',
    '}'].join('\n');
  function sh(type, src) {
    var s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s);
    return gl.getShaderParameter(s, gl.COMPILE_STATUS) ? s : null;
  }
  var v = sh(gl.VERTEX_SHADER, vs), f = sh(gl.FRAGMENT_SHADER, fs);
  if (!v || !f) { cv.remove(); return; }
  var pr = gl.createProgram(); gl.attachShader(pr, v); gl.attachShader(pr, f); gl.linkProgram(pr);
  if (!gl.getProgramParameter(pr, gl.LINK_STATUS)) { cv.remove(); return; }
  gl.useProgram(pr);
  gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  var lp = gl.getAttribLocation(pr, 'p'); gl.enableVertexAttribArray(lp); gl.vertexAttribPointer(lp, 2, gl.FLOAT, false, 0, 0);
  var ur = gl.getUniformLocation(pr, 'r'), ut = gl.getUniformLocation(pr, 't'),
      ub = gl.getUniformLocation(pr, 'b'), um = gl.getUniformLocation(pr, 'm');
  var mx = 0, tx = 0, boost = 0, bb = 0, still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  var a = cv.parentNode;
  a.addEventListener('mousemove', function (e) { var r = cv.getBoundingClientRect(); tx = (e.clientX - r.left) / r.width - .5; });
  a.addEventListener('mouseenter', function () { boost = 1; });
  a.addEventListener('mouseleave', function () { boost = 0; tx = 0; });
  function size() {
    var dpr = Math.min(devicePixelRatio || 1, 2), w = Math.round(cv.clientWidth * dpr), h = Math.round(cv.clientHeight * dpr);
    if (cv.width !== w || cv.height !== h) { cv.width = w; cv.height = h; gl.viewport(0, 0, w, h); }
  }
  var t = 7, last = performance.now();
  function frame(now) {
    var dt = Math.min((now - last) / 1000, .1); last = now;
    var k = Math.min(dt * 4, 1);
    bb += (boost - bb) * k; mx += (tx - mx) * k;
    t += dt * (1 + bb * 1.8);
    size();
    gl.uniform2f(ur, cv.width, cv.height); gl.uniform1f(ut, t); gl.uniform1f(ub, bb); gl.uniform1f(um, mx);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    if (!still) requestAnimationFrame(frame);
  }
  addEventListener('resize', function () { if (still) frame(performance.now()); });
  requestAnimationFrame(frame);
})();
