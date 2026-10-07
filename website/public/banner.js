// "Looking for MarioKart64JS?" banner: a rainbow-road warp tunnel in WebGL.
// Falls back to the CSS gradient on .mk-banner if WebGL is unavailable.
(function () {
  var cv = document.getElementById('mk-gl');
  if (!cv) return;
  var gl = cv.getContext('webgl', { alpha: false, antialias: false, premultipliedAlpha: false });
  if (!gl) { cv.remove(); return; }
  var vs = 'attribute vec2 p;void main(){gl_Position=vec4(p,0.,1.);}';
  var fs = [
    'precision mediump float;uniform vec2 r;uniform float t;uniform vec2 m;',
    'vec3 rb(float h){return .5+.5*cos(6.2831*(h+vec3(0.,.33,.67)));}',
    'float hs(vec2 c){return fract(sin(dot(c,vec2(12.9898,78.233)))*43758.5453);}',
    'void main(){',
    ' vec2 uv=(gl_FragCoord.xy-.5*r)/r.y;',
    ' uv.x-=(m.x-.5)*r.x/r.y*.25;',
    ' float d=abs(uv.y)+.045, z=.32/d, x=uv.x*z*.55;',
    ' float hue=fract(x*.04+z*.18-t*.9);',
    ' vec3 road=pow(rb(hue),vec3(2.2));',
    ' float seam=smoothstep(.06,0.,abs(fract(z*1.2-t*3.)-.5)-.44);',
    ' road=mix(road,vec3(1.),seam*.3);',
    ' float lane=smoothstep(.04,0.,abs(fract(x*.5)-.5)-.47);',
    ' road+=lane*.35;',
    ' float fog=exp(-z*.09);',
    ' vec3 col=vec3(.02,.02,.08)+road*fog*.85;',
    ' vec2 s=gl_FragCoord.xy+vec2(t*90.,0.);vec2 c=floor(s/3.);float h=hs(c);',
    ' col+=step(.992,h)*(1.-fog)*(.6+.4*sin(t*6.+h*90.))*vec3(1.,.95,.8);',
    ' col*=.62+.38*smoothstep(0.,.5,abs(uv.x)/(r.x/r.y*.5));',
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
  var ur = gl.getUniformLocation(pr, 'r'), ut = gl.getUniformLocation(pr, 't'), um = gl.getUniformLocation(pr, 'm');
  var mx = .5, tx = .5, boost = 0, still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  var a = cv.parentNode;
  a.addEventListener('mousemove', function (e) { var b = cv.getBoundingClientRect(); tx = (e.clientX - b.left) / b.width; });
  a.addEventListener('mouseenter', function () { boost = 1; });
  a.addEventListener('mouseleave', function () { boost = 0; tx = .5; });
  function size() {
    var dpr = Math.min(devicePixelRatio || 1, 2), w = Math.round(cv.clientWidth * dpr), h = Math.round(cv.clientHeight * dpr);
    if (cv.width !== w || cv.height !== h) { cv.width = w; cv.height = h; gl.viewport(0, 0, w, h); }
  }
  var t = 0, last = performance.now(), spd = 1;
  function frame(now) {
    var dt = Math.min((now - last) / 1000, .1); last = now;
    spd += ((boost ? 2.6 : 1) - spd) * Math.min(dt * 4, 1);
    t += dt * spd * .5; mx += (tx - mx) * Math.min(dt * 5, 1);
    size();
    gl.uniform2f(ur, cv.width, cv.height); gl.uniform1f(ut, t); gl.uniform2f(um, mx, .5);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    if (!still) requestAnimationFrame(frame);
  }
  addEventListener('resize', function () { if (still) frame(performance.now()); });
  requestAnimationFrame(frame);
})();
