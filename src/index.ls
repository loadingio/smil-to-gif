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

  #TODO - all <img xlink:href=""/>, render after fetched
  fetch-image = (url, width, height) -> new Promise (res, rej) ->
    if /^data:/.exec(url) => return res url
    img = new Image!
    img <<< width: "#{width}px", height: "#{height}px"
    img.onload = ->
      canvas = document.createElement \canvas
      canvas <<< {width, height}
      ctx = canvas.getContext \2d
      ctx.fillStyle = \#ffff00
      ctx.fillRect 0, 0, width, height
      ctx.drawImage img, 0, 0, width, height
      res canvas.toDataURL!
    img.src = url

  _fetch-images = (node, hash = {}) ->
    promises = []
    if /^#/.exec(node.nodeName) => return []
    href = node.getAttribute \xlink:href
    if href and !/^#/.exec(href) =>
      width = node.getAttribute \width
      height = node.getAttribute \height
      promises.push( fetch-image(href, width, height).then -> hash[href] = it )
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
    node.style["animation-play-state"] = "paused";
    node.style["animation-delay"] = "#{(node._delay + -delay * node._dur)}s";
    for i from 0 til node.childNodes.length =>
      child = node.childNodes[i]
      freeze-traverse child, option, delay

  prepare = (node, option = {}, delay) ->
    # reset animation so we can get precisely the value with delay
    [p,n] = [node.parentNode, node.nextSibling]
    p.removeChild node
    if n => p.insertBefore(node, n) else p.appendChild node
    freeze-traverse node, option, delay
    traverse node, option

  dummy = document.createElementNS("http://www.w3.org/2000/svg", "circle")
  document.body.append(dummy)
  dummy-style = window.getComputedStyle(dummy)

  traverse = (node, option = {}) ->
    if /^#text/.exec(node.nodeName) => return node.textContent
    else if /^#/.exec(node.nodeName) => return ""
    [attrs,styles,subtags,animatedProperties] = [[],[],[],{}]
    style = getComputedStyle(node)

    # track styles
    if option.css-animation or option.with-css =>
      for k,v of style =>
        if !(/^\d+$|^cssText$/.exec(k) or dummy-style[k] == v) =>
          styles.push [k.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase!, v]

    if node.nodeName == \svg =>
      animatedProperties["xmlns"] = "http://www.w3.org/2000/svg"
      animatedProperties["xmlns:xlink"] = "http://www.w3.org/1999/xlink"
    for i from 0 til node.childNodes.length =>
      child = node.childNodes[i]
      if /^animateMotion/.exec(child.nodeName) =>
        dur = child.getSimpleDuration!
        begin = +child.getAttribute("begin").replace("s","")
        path = document.querySelector(
          child.querySelector("mpath").getAttributeNS("http://www.w3.org/1999/xlink", "href")
        )
        length = path.getTotalLength!
        ptr = path.getPointAtLength(length * ((child.getCurrentTime() - begin) % dur) / dur)
        animatedProperties["transform"] = "translate(#{ptr.x} #{ptr.y})"
      else if /^animate/.exec(child.nodeName) =>
        name = child.getAttribute \attributeName
        value = node[name] or style.getPropertyValue(name)
        if name == \d => value = (node.animatedPathSegList or node.getAttribute(\d))
        animatedProperties[name] = anim-to-string(value)
      else subtags.push traverse(child, option)
    for v in node.attributes =>
      if v.name == \style => continue
      if animatedProperties[v.name]? =>
        attrs.push [v.name, animatedProperties[v.name]]
        delete animatedProperties[v.name]
      else if v.name == \xlink:href and option.hrefs and option.hrefs[v.value] =>
        attrs.push [v.name , option.hrefs[v.value]]
      else attrs.push [v.name, v.value]
    for k,v of animatedProperties => attrs.push [k, v]
    styles.sort (a,b) -> if b.0 > a.0 => 1 else if b.0 < a.0 => -1 else 0
    ret = [
      "<#{node.nodeName}"
      """ #{attrs.map(->"#{it.0}=\"#{it.1}\"").join(" ")}""" if attrs.length
      """ style="#{styles.map(->"#{it.0}:#{it.1}").join(";")}" """ if styles.length
      ">"
      subtags.join("\n").trim!
      "</#{node.nodeName}>"
    ].filter(->it).join("")
    return ret

  ###### interface ######

  smiltool = module.smiltool = {}

  smiltool.smil-to-svg = smil-to-svg = (root, delay, option = {}) ->
    new Promise (res, rej) ->
      hash = {}
      root.pauseAnimations!
      if delay? => root.setCurrentTime delay
      # redraw needs a break and takes time, and setTimeout takes 0.3s in firefox.
      # here we use an option to turn it on, and use requestAnimationFrame for optimization
      _ = ->
        <- fetch-images(root, hash).then
        if option.css-animation => prepare root, option, delay
        ret = traverse root, {hrefs: hash} <<< option
        root.unpauseAnimations!
        res """<?xml version="1.0" encoding="utf-8"?>#ret"""
      if option.force-redraw => requestAnimationFrame(-> _ it) else _!

  smiltool.svg-to-dataurl = svg-to-dataurl = (svg) -> new Promise (res, rej) ->
    res "data:image/svg+xml;base64,#{btoa svg}"

  smiltool.smil-to-dataurl = smil-to-dataurl = (root, delay, option) ->
    smil-to-svg root, delay, option .then (svg) -> svg-to-dataurl svg

  smiltool.dataurl-to-img = dataurl-to-img = (url, width = 100, height = 100, type = "image/png", quality = 0.92) ->
    new Promise (res, rej) ->
      img = new Image!
      img.onload = ->
        canvas = document.createElement \canvas
        canvas.width = width
        canvas.height = height
        ctx = canvas.getContext \2d
        ctx.drawImage img, 0, 0, width, height
        res canvas.toDataURL(type, quality)
      img.src = url

  smiltool.smil-to-img = smil-to-img = (root, width=100, height=100, delay, type="image/png", quality=0.92, option) ->
    smil-to-dataurl root, delay, option .then (dataurl) -> dataurl-to-img dataurl, width, height, type, quality

  smiltool.smil-to-png = smil-to-png = (root, width = 100, height = 100, delay, quality = 0.92, option) ->
    smil-to-img root, width, height, delay, "image/png", quality, option

  smiltool.dataurl-to-i8a = dataurl-to-i8a = (url) -> new Promise (res, rej) ->
    bin = atob uri.split \, .1
    len = bin.length
    len32 = len .>>. 2
    a8 = new Unit8Array len
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
    res i8a

  smiltool.i8a-to-blob = i8a-to-blob = (i8a, type = \image/png) -> new Promise (res, rej) ->
    res new Blob([i8a], {type})

  smiltool.dataurl-to-blob = dataurl-to-blob = (url, type = \image/png) ->
    dataurl-to-i8a url .then (i8a) -> i8a-to-blob i8a, type

  smiltool.svg-to-blob = svg-to-blob = (svg, type = \image/png) ->
    svg-to-dataurl svg
      .then (url) -> dataurl-to-i8a url
      .then (i8a) -> i8a-to-blob i8a, type

  smiltool.smil-to-blob = svg-to-blob = (svg, delay, type = \image/png, option) ->
    smil-to-svg root, delay, option .then (svg) ->
      svg-to-dataurl svg .then (url) ->
      dataurl-to-i8a url .then (i8a) ->
      i8a-to-blob i8a, type

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
        ctx.fillStyle = \#ffffff
        ctx.fillRect 0, 0, w, h
        ctx.drawImage(
          img,
          0, 0, img.width, img.height,
          (w - img.width)/2,
          (h - img.height)/2,
          img.width, img.height
        )
        dataurl = canvas.toDataURL(type, quality)
        dataurl-to-arraybuffer dataurl .then (ab) -> res ab
      img.src = url

  if GIF? =>
    smiltool.smil-to-gif = (node, param-option={}, param-gif-option={}, smil2svgopt={}) -> new Promise (res, rej) ->
      imgs = []
      option = {slow: 0, width: 100, height: 100, frames: 30, duration: 1, progress: (->)}  <<< param-option
      gif-option = { worker: 2, quality: 1 } <<< param-gif-option <<< option{width, height}
      if option.duration / option.frames < 0.034 => option.frames = Math.floor(option.duration / 0.034)
      if option.duration / option.frames > 0.1 => option.frames = Math.ceil(option.duration / 0.1)
      gif = new GIF gif-option
      gif.on \finished, (blob) ->
        img = new Image!
        img.src = URL.createObjectURL blob
        res {gif: img, frames: imgs, blob: blob}
      _ = (t) ->
        p = 100 * t / option.duration <? 100
        option.progress p
        if t > option.duration => return gif.render!
        if param-option.step => param-option.step t
        (ret) <- smil-to-svg node, t, smil2svgopt .then
        img = new Image!
        img.style
          ..width  = "#{option.width}px"
          ..height = "#{option.height}px"
        img.src = "data:image/svg+xml;base64,#{btoa ret}"
        delay = Math.round(option.duration * 1000 / option.frames)
        gif.addFrame img, { delay }
        imgs.push img
        setTimeout (-> _ t + (option.duration / option.frames)), option.slow
      setTimeout (-> _ 0), option.slow

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
