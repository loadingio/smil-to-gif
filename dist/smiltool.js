// Generated by LiveScript 1.3.1
var slice$ = [].slice;
(function(module){
  var pathFromList, transformFromList, animToString, imageCache, fetchImage, _fetchImages, fetchImages, freezeTraverse, restoreAnimation, prepare, dummy, getDummyStyle, traverse, smiltool, smilToSvg, svgToDataurl, smilToDataurl, urlToDataurl, smilToImg, smilToPng, dataurlToI8a, i8aToBlob, dataurlToBlob, svgToBlob, dataurlToArraybuffer, imgurlToArraybuffer, iBuffer, apngtool, i8asToApngI8a;
  pathFromList = function(list){
    var ret, i$, to$, i, item;
    ret = [];
    for (i$ = 0, to$ = list.numberOfItems; i$ < to$; ++i$) {
      i = i$;
      item = list.getItem(i);
      ret.push(item.pathSegTypeAsLetter + ['r1', 'r2', 'angle', 'largeArcFlag', 'sweepFlag', 'x1', 'y1', 'x2', 'y2', 'x', 'y'].filter(fn$).map(fn1$).join(" "));
    }
    return ret.join("");
    function fn$(it){
      return item[it] != null;
    }
    function fn1$(it){
      if (it === 'largeArcFlag' || it === 'sweepFlag') {
        if (item[it]) {
          return 1;
        } else {
          return 0;
        }
      } else {
        return item[it];
      }
    }
  };
  transformFromList = function(list){
    var ret, i$, to$, i, item, mat;
    ret = [];
    for (i$ = 0, to$ = list.numberOfItems; i$ < to$; ++i$) {
      i = i$;
      item = list.getItem(i);
      mat = item.matrix;
      ret.push("matrix(" + mat.a + "," + mat.b + "," + mat.c + "," + mat.d + "," + mat.e + "," + mat.f + ")");
    }
    return ret.join(" ");
  };
  animToString = function(input){
    var ref$;
    if ((ref$ = typeof input) === 'string' || ref$ === 'number') {
      return input;
    }
    if (input.animVal) {
      if ((ref$ = typeof input.animVal) === 'string' || ref$ === 'number') {
        return input.animVal;
      }
      if ((ref$ = typeof input.animVal.value) === 'string' || ref$ === 'number') {
        return input.animVal.value;
      }
      if (!input.animVal.numberOfItems) {
        return "";
      }
      return transformFromList(input.animVal);
    } else if (input.numberOfItems && ((input.getItem && input.getItem(0)) || input[0]).pathSegType != null) {
      return pathFromList(input);
    }
    return "";
  };
  imageCache = {};
  fetchImage = function(url, width, height){
    return new Promise(function(res, rej){
      var img, ref$;
      if (/^data:/.exec(url)) {
        return res(url);
      }
      if (imageCache[url]) {
        return res(imageCache[url]);
      }
      img = new Image();
      ref$ = img.style;
      ref$.width = width ? width + "px" : void 8;
      ref$.height = height ? height + "px" : void 8;
      img.onload = function(){
        var ref$, width, height, canvas, ctx, ret;
        ref$ = [img.width, img.height], width = ref$[0], height = ref$[1];
        canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;
        ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, width, height);
        ctx.fillStyle = 'rgba(255,255,255,0)';
        ctx.fillRect(0, 0, width, height);
        ctx.drawImage(img, 0, 0, width, height);
        ret = canvas.toDataURL();
        imageCache[url] = ret;
        return res(res);
      };
      return img.src = url;
    });
  };
  _fetchImages = function(node, hash){
    var promises, href, width, height, i$, to$, i, child;
    hash == null && (hash = {});
    promises = [];
    if (/^#/.exec(node.nodeName)) {
      return [];
    }
    href = node.getAttributeNS('http://www.w3.org/1999/xlink', 'href') || node.getAttribute('href');
    if (href && !/^#/.exec(href)) {
      width = node.getAttribute('width');
      height = node.getAttribute('height');
      promises.push(fetchImage(href, width, height, hash).then(function(it){
        return hash[href] = it;
      }));
    }
    for (i$ = 0, to$ = node.childNodes.length; i$ < to$; ++i$) {
      i = i$;
      child = node.childNodes[i];
      promises = promises.concat(_fetchImages(child, hash));
    }
    return promises;
  };
  fetchImages = function(node, hash){
    hash == null && (hash = {});
    return Promise.all(_fetchImages(node, hash));
  };
  freezeTraverse = function(node, option, delay){
    var style, i$, to$, i, child, results$ = [];
    option == null && (option = {});
    delay == null && (delay = 0);
    if (/^#text/.exec(node.nodeName)) {
      return node.textContent;
    } else if (/^#/.exec(node.nodeName)) {
      return "";
    }
    style = window.getComputedStyle(node);
    if (!(node._delay != null)) {
      node._delay = parseFloat(style["animation-delay"] || 0);
    }
    if (!(node._dur != null)) {
      node._dur = parseFloat(style["animation-duration"] || 0);
    }
    node.style["animation-play-state"] = "paused";
    node.style["animation-delay"] = (node._delay - delay) + "s";
    for (i$ = 0, to$ = node.childNodes.length; i$ < to$; ++i$) {
      i = i$;
      child = node.childNodes[i];
      results$.push(freezeTraverse(child, option, delay));
    }
    return results$;
  };
  restoreAnimation = function(node){
    var i$, to$, i, results$ = [];
    if (/^#text/.exec(node.nodeName)) {
      return node.textContent;
    } else if (/^#/.exec(node.nodeName)) {
      return "";
    }
    node.style["animation-play-state"] = "running";
    node.style["animation-delay"] = (node._delay || 0) + "s";
    for (i$ = 0, to$ = node.childNodes.length; i$ < to$; ++i$) {
      i = i$;
      results$.push(restoreAnimation(node.childNodes[i]));
    }
    return results$;
  };
  prepare = function(node, delay, option){
    var ref$, p, n;
    option == null && (option = {});
    ref$ = [node.parentNode, node.nextSibling], p = ref$[0], n = ref$[1];
    p.removeChild(node);
    if (n) {
      p.insertBefore(node, n);
    } else {
      p.appendChild(node);
    }
    if (node.pauseAnimations != null) {
      node.pauseAnimations();
      if (delay != null) {
        node.setCurrentTime(delay);
      }
    }
    freezeTraverse(node, option, delay);
    return traverse(node, option);
  };
  dummy = document.createElementNS("http://www.w3.org/2000/svg", "circle");
  getDummyStyle = function(){
    if (!dummy.defStyle) {
      if (!dummy.parentNode) {
        document.body.appendChild(dummy);
      }
      dummy.defStyle = window.getComputedStyle(dummy);
    }
    return dummy.defStyle;
  };
  traverse = function(node, delay, option){
    var ref$, attrs, styles, subtags, animatedProperties, style, dummyStyle, i$, to$, i, child, dur, begin, path, length, ptr, name, value, len$, v, k, ret;
    delay == null && (delay = 1);
    option == null && (option = {});
    if (/^#text/.exec(node.nodeName)) {
      return node.textContent;
    } else if (/^#/.exec(node.nodeName)) {
      return "";
    }
    ref$ = [[], [], [], {}], attrs = ref$[0], styles = ref$[1], subtags = ref$[2], animatedProperties = ref$[3];
    style = getComputedStyle(node);
    dummyStyle = getDummyStyle();
    if (option.cssAnimation || option.withCss) {
      /* new method - 10x faster. Need to include all related classes */
      for (i$ = 0, to$ = node.style.length; i$ < to$; ++i$) {
        i = i$;
        if (!((ref$ = node.style[i]) === 'transform' || ref$ === 'opacity')) {
          styles.push([node.style[i], style[node.style[i]]]);
        }
      }
      styles.push(['transform', style.transform]);
      styles.push(['opacity', style.opacity]);
      /* old method */
      /*
      for k,v of style =>
        attr = node.getAttribute(k)
        inline-style = node.getAttribute('style') or ''
        if (
          !(/^\d+$|^cssText$/.exec(k) or (dummy-style[k] == v and !~inline-style.indexOf(k))) and
          !(option.no-animation and /animation/.exec(k))
        ) =>
          styles.push [k.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase!, v]
      */
    }
    if (node.nodeName === 'svg') {
      animatedProperties["xmlns"] = "http://www.w3.org/2000/svg";
      animatedProperties["xmlns:xlink"] = "http://www.w3.org/1999/xlink";
    }
    for (i$ = 0, to$ = node.childNodes.length; i$ < to$; ++i$) {
      i = i$;
      child = node.childNodes[i];
      if (/^animate/.exec(child.nodeName) && option.noAnimation) {
        continue;
      }
      if (/^animateMotion/.exec(child.nodeName)) {
        dur = child.getSimpleDuration();
        begin = +child.getAttribute("begin").replace("s", "");
        path = document.querySelector(child.querySelector("mpath").getAttributeNS("http://www.w3.org/1999/xlink", "href"));
        length = path.getTotalLength();
        ptr = path.getPointAtLength(length * ((child.getCurrentTime() - begin) % dur) / dur);
        animatedProperties["transform"] = "translate(" + ptr.x + " " + ptr.y + ")";
      } else if (/^animate/.exec(child.nodeName)) {
        name = child.getAttribute('attributeName');
        value = node[name] || style.getPropertyValue(name);
        if (name === 'd') {
          value = node.animatedPathSegList || node.getAttribute('d');
        }
        animatedProperties[name] = animToString(value);
      } else {
        subtags.push(traverse(child, delay, option));
      }
    }
    for (i$ = 0, len$ = (ref$ = node.attributes).length; i$ < len$; ++i$) {
      v = ref$[i$];
      if (v.name === 'style') {
        continue;
      }
      if (animatedProperties[v.name] != null) {
        attrs.push([v.name, animatedProperties[v.name]]);
        delete animatedProperties[v.name];
      } else if ((v.name === 'xlink:href' || v.name === 'href') && option.hrefs && option.hrefs[v.value]) {
        attrs.push([v.name, option.hrefs[v.value]]);
      } else {
        attrs.push([v.name, v.value]);
      }
    }
    for (k in animatedProperties) {
      v = animatedProperties[k];
      attrs.push([k, v]);
    }
    if (option.noAnimation) {
      attrs.map(function(it){
        if (it[0] === 'class') {
          return it[1] = it[1].split(' ').filter(function(it){
            return !/^ld-/.exec(it);
          }).join(' ');
        }
      });
    }
    styles.sort(function(a, b){
      if (b[0] > a[0]) {
        return 1;
      } else if (b[0] < a[0]) {
        return -1;
      } else {
        return 0;
      }
    });
    styles.map(function(it){
      if (it[1] && typeof it[1] === 'string') {
        return it[1] = it[1].replace(/"/g, "'");
      }
    });
    attrs.map(function(it){
      if (it[1] && typeof it[1] === 'string') {
        return it[1] = it[1].replace(/"/g, "'");
      }
    });
    ret = [
      "<" + node.nodeName, attrs.length ? " " + attrs.map(function(it){
        return it[0] + "=\"" + it[1] + "\"";
      }).join(" ") : void 8, styles.length ? " style=\"" + styles.map(function(it){
        return it[0] + ":" + it[1];
      }).join(";") + "\" " : void 8, ">", subtags.join("\n").trim(), "</" + node.nodeName + ">"
    ].filter(function(it){
      return it;
    }).join("");
    return ret;
  };
  smiltool = module.smiltool = {};
  smiltool.smilToSvg = smilToSvg = function(root, delay, option){
    option == null && (option = {});
    return new Promise(function(res, rej){
      var hash, _;
      hash = {};
      root.pauseAnimations();
      if (delay != null) {
        root.setCurrentTime(delay);
      }
      _ = function(){
        return fetchImages(root, hash).then(function(){
          var ret;
          if (option.cssAnimation) {
            prepare(root, delay, option);
          }
          ret = traverse(root, delay, import$({
            hrefs: hash
          }, option));
          if (option.cssAnimation) {
            restoreAnimation(root);
          }
          root.unpauseAnimations();
          return res("<?xml version=\"1.0\" encoding=\"utf-8\"?>" + ret);
        });
      };
      if (option.forceRedraw) {
        return requestAnimationFrame(function(it){
          return _(it);
        });
      } else {
        return _();
      }
    });
  };
  smiltool.svgToDataurl = svgToDataurl = function(svg){
    return new Promise(function(res, rej){
      return res("data:image/svg+xml," + encodeURIComponent(svg));
    });
  };
  smiltool.smilToDataurl = smilToDataurl = function(root, delay, option){
    return smilToSvg(root, delay, option).then(function(svg){
      return svgToDataurl(svg);
    });
  };
  smiltool.urlToDataurl = urlToDataurl = function(url, width, height, type, quality){
    width == null && (width = 100);
    height == null && (height = 100);
    type == null && (type = "image/png");
    quality == null && (quality = 0.92);
    return new Promise(function(res, rej){
      var img;
      img = new Image();
      img.onload = function(){
        var canvas, ctx;
        canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;
        ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, width, height);
        return res(canvas.toDataURL(type, quality));
      };
      return img.src = url;
    });
  };
  smiltool.dataurlToImg = urlToDataurl;
  smiltool.smilToImg = smilToImg = function(root, width, height, delay, type, quality, option){
    width == null && (width = 100);
    height == null && (height = 100);
    type == null && (type = "image/png");
    quality == null && (quality = 0.92);
    return smilToDataurl(root, delay, option).then(function(dataurl){
      return urlToDataurl(dataurl, width, height, type, quality);
    });
  };
  smiltool.smilToPng = smilToPng = function(root, width, height, delay, quality, option){
    width == null && (width = 100);
    height == null && (height = 100);
    quality == null && (quality = 0.92);
    return smilToImg(root, width, height, delay, "image/png", quality, option);
  };
  smiltool.pngIendFix = function(a8){
    a8[a8.length - 4] = 0xae;
    a8[a8.length - 3] = 0x42;
    a8[a8.length - 2] = 0x60;
    a8[a8.length - 1] = 0x82;
    return a8;
  };
  smiltool.dataurlToI8a = dataurlToI8a = function(url){
    return new Promise(function(res, rej){
      var content, bin, len, len32, a8, a32, ref$, i, j, i$, tailLen;
      content = url.split(',')[1];
      if (/base64/.exec(url)) {
        bin = atob(content);
      } else {
        bin = decodeURIComponent(content);
      }
      len = bin.length;
      len32 = len >> 2;
      a8 = new Uint8Array(len);
      a32 = new Uint32Array(a8.buffer, 0, len32);
      ref$ = [0, 0], i = ref$[0], j = ref$[1];
      for (i$ = 0; i$ < len32; ++i$) {
        i = i$;
        a32[i] = bin.charCodeAt(j++) | bin.charCodeAt(j++) << 8 | bin.charCodeAt(j++) << 16 | bin.charCodeAt(j++) << 24;
      }
      tailLen = len & 3;
      for (i$ = tailLen; i$ < 0; ++i$) {
        i = i$;
        a8[j] = bin.charCodeAt(j);
        j++;
      }
      return res(smiltool.pngIendFix(a8));
    });
  };
  smiltool.i8aToBlob = i8aToBlob = function(i8a, type){
    type == null && (type = 'image/png');
    return new Promise(function(res, rej){
      return res(new Blob([i8a], {
        type: type
      }));
    });
  };
  smiltool.dataurlToBlob = dataurlToBlob = function(url, type){
    type == null && (type = 'image/png');
    return dataurlToI8a(url).then(function(i8a){
      return i8aToBlob(i8a, type);
    });
  };
  smiltool.svgToBlob = svgToBlob = function(svg, type){
    type == null && (type = 'image/png');
    return svgToDataurl(svg).then(function(url){
      return dataurlToI8a(url);
    }).then(function(i8a){
      return i8aToBlob(i8a, type);
    });
  };
  smiltool.smilToBlob = svgToBlob = function(svg, delay, type, option){
    type == null && (type = 'image/png');
    return smilToSvg(root, delay, option).then(function(svg){
      svgToDataurl(svg).then(function(url){});
      dataurlToI8a(url).then(function(i8a){});
      return i8aToBlob(i8a, type);
    });
  };
  smiltool.dataurlToArraybuffer = dataurlToArraybuffer = function(dataurl){
    return new Promise(function(res, rej){
      var splitted, byteString, mimeString, ab, ia, i$, to$, i;
      splitted = dataurl.split(',');
      byteString = atob(splitted[1]);
      mimeString = splitted[0].split(':')[1].split(';')[0];
      ab = new ArrayBuffer(byteString.length);
      ia = new Uint8Array(ab);
      for (i$ = 0, to$ = byteString.length; i$ < to$; ++i$) {
        i = i$;
        ia[i] = byteString.charCodeAt(i);
      }
      return res(ab);
    });
  };
  smiltool.imgurlToArraybuffer = imgurlToArraybuffer = function(url, width, height, type, quality){
    type == null && (type = 'image/png');
    quality == null && (quality = 0.92);
    return new Promise(function(res, rej){
      var img;
      img = new Image();
      img.onload = function(){
        var w, h, canvas, ctx, dataurl;
        w = width != null
          ? width
          : img.width;
        h = height != null
          ? height
          : img.height;
        canvas = document.createElement("canvas");
        canvas.width = w;
        canvas.height = h;
        ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, w, h);
        ctx.fillStyle = '#ffffff';
        ctx.fillStyle = 'rgba(255,255,255,0)';
        ctx.fillRect(0, 0, w, h);
        ctx.drawImage(img, 0, 0, img.width, img.height, (w - img.width) / 2, (h - img.height) / 2, img.width, img.height);
        dataurl = canvas.toDataURL(type, quality);
        return dataurlToArraybuffer(dataurl).then(function(ab){
          return res(ab);
        });
      };
      return img.src = url;
    });
  };
  if (typeof GIF != 'undefined' && GIF !== null) {
    smiltool.imgsToGif = function(data, paramOption, paramGifOption){
      return new Promise(function(res, rej){
        var option, gifOption, ref$, gif, i$, len$, item;
        option = import$({
          slow: 0,
          width: 100,
          height: 100,
          frames: 30,
          duration: 1,
          progress: function(){}
        }, paramOption);
        gifOption = (ref$ = import$({
          worker: 2,
          quality: 1
        }, paramGifOption), ref$.width = option.width, ref$.height = option.height, ref$);
        gif = new GIF(gifOption);
        gif.on('finished', function(blob){
          var img;
          img = new Image();
          img.src = URL.createObjectURL(blob);
          return res({
            gif: img,
            frames: data.imgs,
            blob: blob
          });
        });
        for (i$ = 0, len$ = (ref$ = data.imgs).length; i$ < len$; ++i$) {
          item = ref$[i$];
          gif.addFrame(item.img, item.option);
        }
        gif.on('progress', function(v){
          if (option.progress) {
            return option.progress(100 * (v * 0.5 + 0.5));
          }
        });
        return gif.render();
      });
    };
    smiltool.smilToGif = function(node, paramOption, paramGifOption, smil2svgopt){
      paramOption == null && (paramOption = {});
      paramGifOption == null && (paramGifOption = {});
      smil2svgopt == null && (smil2svgopt = {});
      return smiltool.smilToImgs(node, paramOption, smil2svgopt).then(function(ret){
        return smiltool.imgsToGif(ret, paramOption, paramGifOption);
      });
    };
  }
  smiltool.imgsToPngs = function(data, paramOption){
    var option, zip, promises;
    paramOption == null && (paramOption = {});
    option = import$({
      width: 100,
      height: 100
    }, paramOption);
    zip = new JSZip();
    promises = data.imgs.map(function(d, i){
      return urlToDataurl(data.imgs[i].src, option.width, option.height).then(function(it){
        return dataurlToBlob(it);
      }).then(function(blob){
        return zip.file("frame-" + i + ".png", blob);
      });
    });
    return Promise.all(promises).then(function(){
      return zip.generateAsync({
        type: 'blob'
      });
    }).then(function(it){
      return {
        blob: it,
        frames: data.imgs
      };
    });
  };
  smiltool.smilToPngs = function(node, paramOption, smil2svgopt){
    paramOption == null && (paramOption = {});
    smil2svgopt == null && (smil2svgopt = {});
    return smiltool.smilToImgs(node, paramOption, smil2svgopt).then(function(ret){
      return smiltool.imgsToPngs(ret, paramOption);
    });
  };
  smiltool.smilToImgs = function(node, paramOption, smil2svgopt){
    paramOption == null && (paramOption = {});
    smil2svgopt == null && (smil2svgopt = {});
    return new Promise(function(res, rej){
      var imgs, option, handler, render, _;
      imgs = [];
      option = import$({
        slow: 0,
        width: 100,
        height: 100,
        frames: 30,
        duration: 1,
        progress: function(){}
      }, paramOption);
      handler = {
        imgs: [],
        option: option
      };
      render = function(){
        return res(handler);
      };
      _ = function(t){
        var p, ref$;
        p = (ref$ = 100 * t / option.duration) < 100 ? ref$ : 100;
        option.progress(p * 0.5);
        if (t > option.duration) {
          return render();
        }
        if (paramOption.step) {
          paramOption.step(t);
        }
        return smilToSvg(node, t, smil2svgopt).then(function(ret){
          var img, x$, delay;
          img = new Image();
          x$ = img.style;
          x$.width = option.width + "px";
          x$.height = option.height + "px";
          img.src = "data:image/svg+xml;," + encodeURIComponent(ret);
          delay = Math.round(option.duration * 1000 / option.frames);
          handler.imgs.push({
            img: img,
            option: {
              delay: delay
            },
            src: img.src
          });
          imgs.push(img);
          return setTimeout(function(){
            return _(t + option.duration / option.frames);
          }, option.slow);
        });
      };
      return setTimeout(function(){
        return _(0);
      }, option.slow);
    });
  };
  iBuffer = function(input){
    if (typeof input === 'number') {
      this.ua = new Uint8Array(input);
      this.length = input;
    } else {
      this.ua = input;
      this.length = input.length;
    }
    return this;
  };
  iBuffer.concat = function(){
    var bufs, length, buf, offset, i$, to$, i;
    bufs = slice$.call(arguments);
    length = bufs.reduce(function(a, b){
      return a + b.length;
    }, 0);
    buf = new iBuffer(length);
    offset = 0;
    for (i$ = 0, to$ = bufs.length; i$ < to$; ++i$) {
      i = i$;
      buf.ua.set(bufs[i].ua, offset);
      offset += bufs[i].length;
    }
    return buf;
  };
  import$(iBuffer.prototype, {
    readUInt32BE: function(position){
      var ret, i$, i;
      ret = 0;
      for (i$ = 0; i$ <= 3; ++i$) {
        i = i$;
        ret *= 0x100;
        ret += +this.ua[position + i];
      }
      return ret;
    },
    readUInt8: function(position){
      return this.ua[position];
    },
    writeUIntBE: function(value, position, bytes){
      var i$, i, results$ = [];
      bytes == null && (bytes = 4);
      for (i$ = bytes - 1; i$ >= 0; --i$) {
        i = i$;
        results$.push(this.ua[position + (bytes - 1) - i] = value >> 8 * i & 0xff);
      }
      return results$;
    },
    writeUInt32BE: function(value, position){
      return this.writeUIntBE(value, position, 4);
    },
    writeUInt16BE: function(value, position){
      return this.writeUIntBE(value, position, 2);
    },
    writeUInt8: function(value, position){
      return this.writeUIntBE(value, position, 1);
    },
    write: function(value, position){
      var i$, to$, i, results$ = [];
      value == null && (value = "");
      for (i$ = 0, to$ = value.length; i$ < to$; ++i$) {
        i = i$;
        results$.push(this.ua[position + i] = value.charCodeAt(i) & 0xff);
      }
      return results$;
    },
    slice: function(a, b){
      return new iBuffer(this.ua.slice(a, b));
    },
    copy: function(des, ts, ss, se){
      var i$, to$, i, results$ = [];
      ts == null && (ts = 0);
      ss == null && (ss = 0);
      if (!se) {
        se = this.ua.length;
      }
      for (i$ = 0, to$ = se - ss; i$ < to$; ++i$) {
        i = i$;
        results$.push(des.writeUInt8(this.readUInt8(ss + i), ts + i));
      }
      return results$;
    },
    toString: function(encoding){
      var ret, i$, to$, i;
      ret = "";
      for (i$ = 0, to$ = this.length; i$ < to$; ++i$) {
        i = i$;
        ret += String.fromCharCode(this.ua[i]);
      }
      return ret;
    }
  });
  apngtool = {
    findChunk: function(buf, type){
      var offset, ret, chunkLength, chunkType;
      offset = 8;
      ret = [];
      while (offset < buf.length) {
        chunkLength = buf.readUInt32BE(offset);
        chunkType = buf.slice(offset + 4, offset + 8).toString('ascii');
        if (chunkType === type) {
          ret.push(buf.slice(offset, offset + chunkLength + 12));
        }
        offset += 4 + 4 + chunkLength + 4;
      }
      if (ret.length) {
        return ret;
      }
      throw new Error("chunk " + type + " not found");
    },
    animateFrame: function(buf, idx, delay){
      var ihdr, idats, delayNumerator, delayDenominator, fctl, data, length, fdat;
      ihdr = apngtool.findChunk(buf, 'IHDR')[0];
      idats = apngtool.findChunk(buf, 'IDAT');
      delayNumerator = Math.round(delay * 1000);
      delayDenominator = 1000;
      fctl = new iBuffer(38);
      fctl.writeUInt32BE(26, 0);
      fctl.write('fcTL', 4);
      fctl.writeUInt32BE(idx ? idx * 2 - 1 : 0, 8);
      fctl.writeUInt32BE(ihdr.readUInt32BE(8), 12);
      fctl.writeUInt32BE(ihdr.readUInt32BE(12), 16);
      fctl.writeUInt32BE(0, 20);
      fctl.writeUInt32BE(0, 24);
      fctl.writeUInt16BE(delayNumerator, 28);
      fctl.writeUInt16BE(delayDenominator, 30);
      fctl.writeUInt8(0, 32);
      fctl.writeUInt8(0, 33);
      fctl.writeUInt32BE(CRC32.buf(fctl.slice(4, fctl.length - 4).ua), 34);
      if (!idx) {
        return [idx, ihdr, iBuffer.concat.apply(iBuffer, [fctl].concat(idats))];
      }
      data = iBuffer.concat.apply(iBuffer, idats.map(function(idat){
        return new iBuffer(idat.ua.slice(8, idat.ua.length - 4));
      }));
      length = data.length + 4 + 12;
      fdat = new iBuffer(length);
      fdat.writeUInt32BE(length - 12, 0);
      fdat.write('fdAT', 4);
      fdat.writeUInt32BE(idx * 2, 8);
      data.copy(fdat, 12, 0);
      fdat.writeUInt32BE(CRC32.buf(fdat.slice(4, fdat.length - 4).ua), length - 4);
      return [idx, ihdr, iBuffer.concat(fctl, fdat)];
    }
  };
  smiltool.i8asToApngI8a = i8asToApngI8a = function(i8as, delay, repeat){
    i8as == null && (i8as = []);
    delay == null && (delay = 0.033);
    repeat == null && (repeat = 0);
    return Promise.resolve().then(function(){
      var images, signature, ihdr, iend, actl;
      images = i8as.filter(function(it){
        return it.length;
      }).map(function(d, idx){
        return apngtool.animateFrame(new iBuffer(d), idx, delay);
      });
      signature = new iBuffer([137, 80, 78, 71, 13, 10, 26, 10]);
      ihdr = images[0][1];
      iend = new iBuffer([0, 0, 0, 0, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82]);
      actl = new iBuffer(20);
      actl.writeUInt32BE(8, 0);
      actl.write('acTL', 4);
      actl.writeUInt32BE(images.length, 8);
      actl.writeUInt32BE(repeat, 12);
      actl.writeUInt32BE(CRC32.buf(actl.slice(4, actl.length - 4).ua), 16);
      return iBuffer.concat.apply(null, [signature, ihdr, actl].concat(images.map(function(it){
        return it[2];
      }), [iend]));
    }).then(function(it){
      return it.ua;
    });
  };
  smiltool.imgsToApngI8a = function(data, paramOption){
    paramOption == null && (paramOption = {});
    return Promise.all(data.imgs.map(function(it){
      return smiltool.urlToDataurl(it.src, it.img.width, it.img.height).then(function(it){
        return smiltool.dataurlToI8a(it);
      });
    })).then(function(i8as){
      var option, delay;
      option = import$({
        frames: 30,
        duration: 1
      }, paramOption);
      delay = option.duration / option.frames;
      return smiltool.i8asToApngI8a(i8as, delay, paramOption.repeatCount || 0);
    });
  };
  smiltool.imgsToApngBlob = function(data, paramOption){
    paramOption == null && (paramOption = {});
    return smiltool.imgsToApngI8a(data, paramOption).then(function(i8a){
      return smiltool.i8aToBlob(i8a, "image/apng");
    });
  };
  smiltool.smilToApngI8a = function(node, paramOption, smil2svgopt){
    paramOption == null && (paramOption = {});
    smil2svgopt == null && (smil2svgopt = {});
    return smiltool.smilToImgs(node, paramOption, smil2svgopt).then(function(ret){
      return smiltool.imgsToApngI8a(ret, paramOption);
    });
  };
  return smiltool.smilToApngBlob = function(node, paramOption, smil2svgopt){
    paramOption == null && (paramOption = {});
    smil2svgopt == null && (smil2svgopt = {});
    return smiltool.smilToApngI8a(node, paramOption, smil2svgopt).then(function(i8a){
      return smiltool.i8aToBlob(i8a, "image/apng");
    });
  };
})(typeof module != 'undefined' && module !== null ? module.exports || (module.exports = {}) : window);
/*
<- $ document .ready
option = {width: 200, height: 200, duration: 2}
gifoption = do
  worker: 2,
  quality: 10,
  workerScript: \gif.worker.js,
  transparent: 0x0000ff
smiltool.smil-to-gif( document.getElementById(\svg), option, gifoption )
  .then -> document.body.appendChild it.gif
*/
function import$(obj, src){
  var own = {}.hasOwnProperty;
  for (var key in src) if (own.call(src, key)) obj[key] = src[key];
  return obj;
}
