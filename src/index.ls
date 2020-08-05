((module)->
  path-from-list = (list) ->
    ret = []
    for i from 0 til list.numberOfItems =>
      item = list.getItem i
      ret.push (
      item.pathSegTypeAsLetter +
      <[r1 r2 angle largeArcFlag sweepFlag x1 y1 x2 y2 x y]>
        .filter -> item[it]?
        .map -> if it in <[largeArcFlag sweepFlag]> => (if item[it] => 1 else 0) else item[it]
        .join(" ")
      )
    return ret.join("")

  transform-from-list = (list) ->
    ret = []
    for i from 0 til list.numberOfItems =>
      item = list.getItem i
      mat = item.matrix
      ret.push "matrix(#{mat.a},#{mat.b},#{mat.c},#{mat.d},#{mat.e},#{mat.f})"
    return ret.join(" ")

  anim-to-string = (input) ->
    if typeof(input) in <[string number]> => return input
    if input.animVal =>
      if typeof(input.animVal) in <[string number]> => return input.animVal
      if typeof(input.animVal.value) in <[string number]> => return input.animVal.value
      if !input.animVal.numberOfItems => return ""
      return transform-from-list input.animVal
    else if input.numberOfItems and ((input.getItem and input.getItem(0)) or (input.0)).pathSegType? =>
      return path-from-list input
    return ""

  image-cache = {}
  #TODO - all <img xlink:href=""/>, render after fetched
  fetch-image = (url, width, height) -> new Promise (res, rej) ->
    if /^data:/.exec(url) => return res url
    if image-cache[url] => return res image-cache[url]
    img = new Image!
    img.style <<<
      width: "#{width}px" if width
      height: "#{height}px" if height
    img.onload = ->
      [width,height] = [img.width, img.height]
      canvas = document.createElement \canvas
      canvas <<< {width, height}
      ctx = canvas.getContext \2d
      ctx.clearRect 0, 0, width, height
      ctx.fillStyle = 'rgba(255,255,255,0)'
      ctx.fillRect 0, 0, width, height
      ctx.drawImage img, 0, 0, width, height
      ret = canvas.toDataURL!
      image-cache[url] = ret
      res res
    img.src = url

  _fetch-images = (node, hash = {}) ->
    promises = []
    if /^#/.exec(node.nodeName) => return []
    href = node.getAttributeNS(\http://www.w3.org/1999/xlink, \href) or node.getAttribute(\href)

    if href and !/^#/.exec(href) =>
      width = node.getAttribute \width
      height = node.getAttribute \height
      promises.push( fetch-image(href, width, height, hash).then -> hash[href] = it )
    for i from 0 til node.childNodes.length =>
      child = node.childNodes[i]
      promises = promises.concat _fetch-images(child, hash)
    return promises

  fetch-images = (node, hash = {}) -> Promise.all _fetch-images(node, hash)

  freeze-traverse = (node, option = {}, delay = 0) ->
    if /^#text/.exec(node.nodeName) => return node.textContent
    else if /^#/.exec(node.nodeName) => return ""
    style = window.getComputedStyle(node)
    if !(node._delay?) => node._delay = parseFloat(style["animation-delay"] or 0)
    if !(node._dur?) => node._dur = parseFloat(style["animation-duration"] or 0)
    node.style["animation-play-state"] = "paused"
    node.style["animation-delay"] = "#{(node._delay - delay)}s"
    for i from 0 til node.childNodes.length =>
      child = node.childNodes[i]
      freeze-traverse child, option, delay

  restore-animation = (node) ->
    if /^#text/.exec(node.nodeName) => return node.textContent
    else if /^#/.exec(node.nodeName) => return ""
    node.style["animation-play-state"] = "running"
    node.style["animation-delay"] = "#{node._delay or 0}s"
    delete node._delay
    delete node._dur
    for i from 0 til node.childNodes.length => restore-animation node.childNodes[i]

  prepare = (node, delay, option = {}) ->
    # reset animation so we can get precisely the value with delay
    [p,n] = [node.parentNode, node.nextSibling]
    if p =>
      p.removeChild node
      if n => p.insertBefore(node, n) else p.appendChild node
    if node.pauseAnimations? =>
      node.pauseAnimations!
      if delay? => node.setCurrentTime delay
    freeze-traverse node, option, delay
    # seems redundant TBD
    #traverse node, delay, option

  dummy = document.createElementNS("http://www.w3.org/2000/svg", "circle")
  get-dummy-style = ->
    if !dummy.def-style =>
      if !dummy.parentNode => document.body.appendChild(dummy)
      dummy.def-style = window.getComputedStyle(dummy)
    return dummy.def-style

  traverse = (node, delay = 1, option = {}) ->
    if node.nodeName.0 == \# => return if node.nodeName == \#text => node.textContent else ''
    [attrs,styles,subtags,animatedProperties,style] = [[],[],[],{},null]
    dummy-style = get-dummy-style!
    style = getComputedStyle(node)

    # track styles
    if option.css-animation or option.with-css =>
      is-svg = node.nodeName.toLowerCase! == \svg
      list = [node.style[i] for i from 0 til node.style.length] ++ <[transform opacity]>
      stylehash = {}
      for k in list =>
        # if safari, transform-origin are broken into x, y, z.
        # but there is only "transform-origin" in computedStyle.
        # thus, we don't use computedStyle here, instead use node.style directly.
        v = style[k] or node.style[k]
        # we don't need position for svg node which cause problems
        if (is-svg and (k in <[left right top bottom position]>)) or !(v?) or v == '' => continue

        if ( k.indexOf(\webkit) == 0 or
          k == \cssText or
          !isNaN(k) or
          dummy-style[k] == v or
          (option.no-animation and k.indexOf(\animation) == 0)
        ) => continue
        if stylehash[k] => continue
        stylehash[k] = v
        styles.push [k.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase!, v]

    if node.nodeName == \svg =>
      animatedProperties["xmlns"] = "http://www.w3.org/2000/svg"
      animatedProperties["xmlns:xlink"] = "http://www.w3.org/1999/xlink"
    for i from 0 til node.childNodes.length =>
      child = node.childNodes[i]
      if option.no-animation and child.nodeName.indexOf(\animate) == 0 => continue
      if child.nodeName.indexOf(\animateMotion) == 0 =>
        dur = child.getSimpleDuration!
        begin = +child.getAttribute("begin").replace("s","")
        path = document.querySelector(
          child.querySelector("mpath").getAttributeNS("http://www.w3.org/1999/xlink", "href")
        )
        length = path.getTotalLength!
        ptr = path.getPointAtLength(length * ((child.getCurrentTime() - begin) % dur) / dur)
        animatedProperties["transform"] = "translate(#{ptr.x} #{ptr.y})"
      else if child.nodeName.indexOf(\animate) == 0 =>
        name = child.getAttribute \attributeName
        value = node[name] or style.getPropertyValue(name)
        if name == \d =>
          value = node.animatedPathSegList
          if !value =>
            style = getComputedStyle(node)
            ret = /path\("([^"]+)"\)/.exec(style.d)
            if ret => value = ret.1
          if !value => value = node.getAttribute(\d)
        animatedProperties[name] = anim-to-string(value)
      else subtags.push traverse(child, delay, option)
    for v in node.attributes =>
      if v.name == \style => continue
      if animatedProperties[v.name]? =>
        attrs.push [v.name, animatedProperties[v.name]]
        delete animatedProperties[v.name]
      else if (v.name == \xlink:href or v.name == \href) and option.hrefs and option.hrefs[v.value] =>
        attrs.push [v.name , option.hrefs[v.value]]
      else attrs.push [v.name, v.value]
    for k,v of animatedProperties => attrs.push [k, v]
    if option.no-animation => attrs.map(->
      if it.0 == \class => it.1 = it.1.split(' ').filter(->!/^ld-/.exec(it)).join(' ')
    )
    styles.sort (a,b) -> if b.0 > a.0 => 1 else if b.0 < a.0 => -1 else 0
    styles.map -> if it.1 and typeof(it.1) == \string => it.1 = it.1.replace /"/g, "'"
    attrs.map -> if it.1 and typeof(it.1) == \string => it.1 = it.1.replace /"/g, "'"
    ret = [
      "<#{node.nodeName}"
      """ #{attrs.map(->"#{it.0}=\"#{it.1}\"").join(" ")}""" if attrs.length
      """ style="#{styles.filter(->it.1?).map(->"#{it.0}:#{it.1}").join(";")}" """ if styles.length
      ">"
      subtags.join("\n").trim!
      "</#{node.nodeName}>"
    ].filter(->it).join("")
    return ret

  ###### interface ######

  smiltool = module.smiltool = {}

  smiltool.svg-statify = (root) ->
    _ = (n) ->
      if n.nodeType != 1 => return
      nodeName = n.nodeName.toLowerCase!
      if /^animate/.exec(nodeName) and n.parentNode => return n.parentNode.removeChild n
      style = window.getComputedStyle(n)
      if style["animation"] => style.animation = "none"
      for c in n.childNodes => _ c
    _ root
    return root

  smiltool.smil-to-svg = smil-to-svg = (root, delay, option = {}) ->
    new Promise (res, rej) ->
      hash = {}
      root.pauseAnimations!
      if delay? => root.setCurrentTime delay
      # redraw needs a break and takes time, and setTimeout takes 0.3s in firefox.
      # here we use an option to turn it on, and use requestAnimationFrame for optimization
      _ = ->
        fetch-images(root, hash).then ->
          if option.css-animation => prepare root, delay, option
          ret = traverse root, delay, {hrefs: hash} <<< option
          if option.css-animation and !option.keep-paused => restore-animation root
          root.unpauseAnimations!
          res """<?xml version="1.0" encoding="utf-8"?>#ret"""
        .catch rej
      if option.force-redraw => requestAnimationFrame(-> _ it) else _!

  smiltool.svg-to-dataurl = svg-to-dataurl = (svg) -> new Promise (res, rej) ->
    #res "data:image/svg+xml;base64,#{btoa svg}"
    res "data:image/svg+xml,#{encodeURIComponent svg}"

  smiltool.smil-to-dataurl = smil-to-dataurl = (root, delay, option) ->
    smil-to-svg root, delay, option .then (svg) -> svg-to-dataurl svg

  smiltool.url-to-dataurl = url-to-dataurl = (url, width = 100, height = 100, type = "image/png", quality = 0.92, opt) ->
    new Promise (res, rej) ->
      img = new Image!
      img.onload = ->
        canvas = document.createElement \canvas
        canvas.width = width
        canvas.height = height
        ctx = canvas.getContext \2d
        ctx.drawImage img, 0, 0, width, height
        if opt and opt.transparent =>
          r = (opt.transparent .>>. 16)
          g = (opt.transparent .>>. 8) % 256
          b = (opt.transparent  % 256)
          img-data = ctx.getImageData(0,0,width,height)
          d = img-data.data
          for i from 0 til d.length by 4 =>
            if d[i] == r and d[i + 1] == g and d[i + 2] == b => d[i + 3] = 0
          ctx.putImageData img-data,0, 0

        res canvas.toDataURL(type, quality)
      img.src = url
  #deprecated. use url-to-dataurl instead
  smiltool.dataurl-to-img = url-to-dataurl

  smiltool.smil-to-img = smil-to-img = (root, width=100, height=100, delay, type="image/png", quality=0.92, option) ->
    smil-to-dataurl root, delay, option .then (dataurl) -> url-to-dataurl dataurl, width, height, type, quality, option

  smiltool.smil-to-png = smil-to-png = (root, width = 100, height = 100, delay, quality = 0.92, option) ->
    smil-to-img root, width, height, delay, "image/png", quality, option

  smiltool.png-iend-fix = (a8) ->
    a8[a8.length - 4] = 0xae
    a8[a8.length - 3] = 0x42
    a8[a8.length - 2] = 0x60
    a8[a8.length - 1] = 0x82
    return a8

  smiltool.dataurl-to-i8a = dataurl-to-i8a = (url) -> new Promise (res, rej) ->
    content = url.split(\,).1
    if /base64/.exec(url) => bin = atob content
    else bin = decodeURIComponent content
    len = bin.length
    len32 = len .>>. 2
    a8 = new Uint8Array len
    a32 = new Uint32Array a8.buffer, 0, len32
    [i,j] = [0,0]
    for i from 0 til len32
      a32[i] = (
        (bin.charCodeAt j++) .|. (bin.charCodeAt(j++) .<<. 8) .|.  (bin.charCodeAt(j++) .<<. 16 ) .|.  (bin.charCodeAt(j++) .<<. 24 )
      )
    tail-len = len .&. 3
    for i from tail-len til 0
      a8[j] = bin.charCodeAt j
      j++
    res smiltool.png-iend-fix(a8)

  smiltool.i8a-to-blob = i8a-to-blob = (i8a, type = \image/png) -> new Promise (res, rej) ->
    res new Blob([i8a], {type})

  smiltool.dataurl-to-blob = dataurl-to-blob = (url, type = \image/png) ->
    dataurl-to-i8a url .then (i8a) -> i8a-to-blob i8a, type

  smiltool.svg-to-blob = svg-to-blob = (svg, type = \image/png) ->
    svg-to-dataurl svg
      .then (url) -> dataurl-to-i8a url
      .then (i8a) -> i8a-to-blob i8a, type

  smiltool.smil-to-blob = svg-to-blob = (svg, delay, type = \image/png, option) ->
    smil-to-svg root, delay, option
      .then (svg) -> svg-to-dataurl svg
      .then (url) -> dataurl-to-i8a url
      .then (i8a) -> i8a-to-blob i8a, type

  smiltool.dataurl-to-arraybuffer = dataurl-to-arraybuffer = (dataurl) -> new Promise (res, rej) ->
    splitted = dataurl.split \,
    byte-string = atob(splitted.1)
    mime-string = splitted.0.split(\:).1.split(\;).0
    ab = new ArrayBuffer(byte-string.length)
    ia = new Uint8Array(ab)
    for i from 0 til byte-string.length => ia[i] = byte-string.charCodeAt i
    res ab

  # optional width and height force a sized image with content centered.
  smiltool.imgurl-to-arraybuffer = imgurl-to-arraybuffer = (url, width, height, type = \image/png, quality = 0.92) ->
    new Promise (res, rej) ->
      img = new Image!
      img.onload = ->
        w = if width? => width else img.width
        h = if height? => height else img.height
        canvas = document.createElement("canvas")
        canvas.width = w
        canvas.height = h
        ctx = canvas.getContext \2d
        ctx.clearRect 0, 0, w, h
        ctx.fillStyle = \#ffffff
        ctx.fillStyle = 'rgba(255,255,255,0)'
        ctx.fillRect 0, 0, w, h
        ctx.drawImage(
          img,
          0, 0, img.width, img.height,
          (w - img.width)/2,
          (h - img.height)/2,
          img.width, img.height
        )
        dataurl = canvas.toDataURL(type, quality)
        dataurl-to-arraybuffer dataurl
          .then (ab) -> res ab
          .catch rej
      img.src = url

  if GIF? =>
    smiltool.imgs-to-gif = (data, param-option, param-gif-option) -> new Promise (res, rej) ->
      option = {slow: 0, width: 100, height: 100, frames: 30, duration: 1, progress: (->)}  <<< param-option
      gif-option = { worker: 2, quality: 1 } <<< param-gif-option <<< option{width, height}
      gif = new GIF gif-option
      gif.on \finished, (blob) ->
        img = new Image!
        img.src = URL.createObjectURL blob
        res {gif: img, frames: data.imgs, blob: blob}
      for item in data.imgs => gif.addFrame item.img, item.option
      gif.on \progress, (v) -> if option.progress => option.progress 100 * ( v * 0.5 + 0.5 )
      gif.render!

    smiltool.smil-to-gif = (node, param-option={}, param-gif-option={}, smil2svgopt={}) ->
      smiltool.smil-to-imgs node, param-option, smil2svgopt
        .then (ret) -> smiltool.imgs-to-gif ret, param-option, param-gif-option

  smiltool.imgs-to-pngs = (data, param-option={}) ->
    option = {width: 100, height: 100} <<< param-option
    zip = new JSZip!
    promises = data.imgs.map (d,i) ->
      url-to-dataurl data.imgs[i].src, option.width, option.height, \image/png, 0.92, param-option
        .then -> dataurl-to-blob it
        .then (blob) -> zip.file "frame-#i.png", blob
    Promise.all promises
      .then -> zip.generate-async type: \blob
      .then -> return {blob: it, frames: data.imgs}


  smiltool.smil-to-pngs = (node, param-option={}, smil2svgopt={}) ->
    smiltool.smil-to-imgs node, param-option, smil2svgopt
      .then (ret) -> smiltool.imgs-to-pngs ret, param-option

  smiltool.smil-to-imgs = (node, param-option={}, smil2svgopt={}) -> new Promise (res, rej) ->
    imgs = []
    option = {slow: 0, width: 100, height: 100, frames: 30, duration: 1, progress: (->)}  <<< param-option
    #if option.duration / option.frames < 0.034 => option.frames = Math.floor(option.duration / 0.034)
    #if option.duration / option.frames > 0.1 => option.frames = Math.ceil(option.duration / 0.1)

    # kee animation paused in the generation loop so Safari works well without timing issue.
    smil2svgopt-local = {} <<< smil2svgopt <<< {keep-paused: true}

    handler = {imgs: [], option}
    render = -> res handler
    skip = 0 # skip the very first frame and repeat it again. can solve some glitch in browsers like Safari
    _ = (t) ->
      p = 100 * t / option.duration <? 100
      option.progress p * 0.5
      if t > option.duration =>
        # call smil-to-svg one more time without keep-paused to resume animation
        smil-to-svg node, t, smil2svgopt
          .then -> return render! #return gif.render!
          .catch rej
        return
      if param-option.step => param-option.step t

      # anti-jagging code goes here, if necessary.
      # - check anti-jagging-code.ls for more detail

      smil-to-svg node, t, smil2svgopt-local
        .then (ret) ->
          img = new Image!
          img.style
            ..width  = "#{option.width}px"
            ..height = "#{option.height}px"
          if !skip =>
            skip := 1
            setTimeout (-> _ t ), option.slow
          else
            img.src = "data:image/svg+xml;,#{encodeURIComponent ret}"
            delay = Math.round(option.duration * 1000 / option.frames)
            handler.imgs.push {img, option: {delay}, src: img.src}
            imgs.push img
            setTimeout (-> _ t + (option.duration / option.frames)), option.slow
        .catch rej
    setTimeout (-> _ 0), option.slow

  iBuffer = (input) ->
    if typeof(input) == \number =>
      @ua = new Uint8Array input
      @length = input
    else
      @ua = input
      @length = input.length
    return @

  iBuffer.concat = (...bufs) ->
    length = bufs.reduce(((a,b) -> a + b.length), 0)
    buf = new iBuffer length
    offset = 0
    for i from 0 til bufs.length =>
      buf.ua.set bufs[i].ua, offset
      offset += bufs[i].length
    return buf

  iBuffer.prototype <<< do
    readUInt32BE: (position) ->
      ret = 0
      for i from 0 to 3 =>
        ret *= 0x100
        ret += +@ua[position + i]
      ret
    readUInt8: (position) -> return @ua[position]
    writeUIntBE: (value, position, bytes = 4) ->
      for i from (bytes - 1) to 0 by -1 =>
        @ua[position + (bytes - 1) - i] = (value .>>. (8 * i)) .&. 0xff
    writeUInt32BE: (value, position) ->
      @writeUIntBE value, position, 4
    writeUInt16BE: (value, position) -> @writeUIntBE value, position, 2
    writeUInt8:    (value, position) -> @writeUIntBE value, position, 1
    write: (value="", position) ->
      for i from 0 til value.length => @ua[position + i] = (value.charCodeAt(i) .&. 0xff)
    slice: (a,b) ->
      new iBuffer(@ua.slice a,b)
    copy: (des, ts = 0, ss = 0, se) ->
      if !se => se = @ua.length
      for i from 0 til se - ss => des.writeUInt8 @readUInt8(ss + i), ts + i
    toString: (encoding)->
      ret = ""
      for i from 0 til @length => ret += String.fromCharCode(@ua[i])
      ret

  apngtool = do
    find-chunk: (buf, type) ->
      offset = 8
      ret = []
      while offset < buf.length
        chunk-length = buf.readUInt32BE offset
        chunk-type = buf.slice(offset + 4, offset + 8).toString(\ascii)
        if chunk-type == type =>
          #return buf.slice(offset, offset + chunk-length + 12)
          ret.push buf.slice(offset, offset + chunk-length + 12)
        offset += (4 + 4 + chunk-length + 4)
      if ret.length => return ret
      throw new Error("chunk #type not found")

    animate-frame: (buf, idx, delay) ->
      ihdr = apngtool.find-chunk(buf, \IHDR).0
      idats = apngtool.find-chunk buf, \IDAT
      delay-numerator = Math.round(delay * 1000)
      delay-denominator = 1000
      fctl = new iBuffer 38
      fctl.writeUInt32BE 26, 0                                 # length of chunk
      fctl.write \fcTL, 4                                      # type of chunk
      fctl.writeUInt32BE (if idx => idx * 2 - 1 else 0), 8     # sequence number
      fctl.writeUInt32BE ihdr.readUInt32BE(8), 12              # width
      fctl.writeUInt32BE ihdr.readUInt32BE(12), 16             # height
      fctl.writeUInt32BE 0, 20                                 # x offset
      fctl.writeUInt32BE 0, 24                                 # y offset
      fctl.writeUInt16BE delay-numerator, 28                   # frame delay - fraction numerator
      fctl.writeUInt16BE delay-denominator, 30                 # frame delay - fraction denominator
      fctl.writeUInt8 0, 32                                    # dispose mode
      fctl.writeUInt8 0, 33                                    # blend mode
      fctl.writeUInt32BE CRC32.buf(fctl.slice(4, fctl.length - 4).ua), 34
      if !idx => return [idx, ihdr, iBuffer.concat.apply(iBuffer, [fctl] ++ idats)]
      # there might be multiple idat but it seems we could only have one fdat.
      # anyway, merge the idats data directly.
      data = iBuffer.concat.apply iBuffer, idats.map((idat) -> new iBuffer( idat.ua.slice(8, idat.ua.length - 4) ))
      length = data.length + 4 + 12
      fdat = new iBuffer length
      fdat.writeUInt32BE length - 12, 0                       # length of chunk
      fdat.write \fdAT, 4                                     # type of chunk
      fdat.writeUInt32BE idx * 2, 8                           # sequence number
      data.copy fdat, 12, 0
      fdat.writeUInt32BE CRC32.buf(fdat.slice(4, fdat.length - 4).ua), length - 4
      return [idx, ihdr, iBuffer.concat(fctl, fdat)]


  smiltool.i8as-to-apng-i8a = i8as-to-apng-i8a = (i8as = [], delay = 0.033, repeat = 0) ->
    Promise.resolve!
      .then ->
        #[images, i8as] = [[], i8as.filter(->it.length)]
        #for idx from 0 til i8as =>
        #  ret = apngtool.animate-frame(new iBuffer(i8as[idx]), idx, delay)
        images = i8as.filter(->it.length).map (d,idx) ->
          apngtool.animate-frame(new iBuffer(d), idx, delay)
        signature = new iBuffer [137, 80, 78, 71, 13, 10, 26, 10]
        ihdr = images.0.1
        iend = new iBuffer [0, 0, 0, 0, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82]
        actl = new iBuffer 20
        actl.writeUInt32BE 8, 0                           # chunk length
        actl.write \acTL, 4                               # chunk type
        actl.writeUInt32BE images.length, 8               # frame count
        actl.writeUInt32BE repeat, 12                     # loop time ( 0 = inf )
        actl.writeUInt32BE CRC32.buf(actl.slice(4, actl.length - 4).ua), 16
        return iBuffer.concat.apply null, ([signature, ihdr, actl] ++ images.map(->it.2) ++ [iend])
      .then -> it.ua

  smiltool.imgs-to-apng-i8a = (data, param-option={}) ->
    Promise.all(
      data.imgs.map ->
        smiltool.url-to-dataurl it.src, it.img.width, it.img.height, \image/png, 0.92, param-option
          .then -> smiltool.dataurl-to-i8a it
    )
      .then (i8as) ->
        option = {frames: 30, duration: 1}  <<< param-option
        # if we want to change frame counts, we should also adjust frames in i8as, which is kinda hard.
        # so we temporarily disable this.
        #if option.duration / option.frames < 0.034 => option.frames = Math.floor(option.duration / 0.034)
        #if option.duration / option.frames > 0.1 => option.frames = Math.ceil(option.duration / 0.1)
        delay = option.duration / option.frames
        smiltool.i8as-to-apng-i8a i8as, delay, (param-option.repeat-count or 0)

  smiltool.imgs-to-apng-blob = (data, param-option={}) ->
    smiltool.imgs-to-apng-i8a data, param-option
      .then (i8a) -> smiltool.i8a-to-blob i8a, "image/apng"

  smiltool.smil-to-apng-i8a = (node, param-option={}, smil2svgopt={}) ->
    smiltool.smil-to-imgs node, param-option, smil2svgopt
      .then (ret) -> smiltool.imgs-to-apng-i8a ret, param-option

  smiltool.smil-to-apng-blob = (node, param-option={}, smil2svgopt={}) ->
    smiltool.smil-to-apng-i8a node, param-option, smil2svgopt
      .then (i8a) -> smiltool.i8a-to-blob i8a, "image/apng"


) (if module? => module.{}exports else window)

# sample usage
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
