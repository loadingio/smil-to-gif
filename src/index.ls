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
      if typeof(input.animVal.value) in <[string number]> => return input.animVal.value
      if !input.animVal.numberOfItems => return ""
      return transform-from-list input.animVal
    else if input.numberOfItems and ((input.getItem and input.getItem(0)) or (input.0)).pathSegType? =>
      return path-from-list input
    return ""

  traverse = (node) ->
    style = getComputedStyle(node)
    animatedProperties = {}
    attrs = []
    subtags = []
    for i from 0 til node.childNodes.length =>
      child = node.childNodes[i]
      if /^animate/.exec(child.nodeName) =>
        name = child.getAttribute \attributeName
        value = node[name] or style.getPropertyValue(name)
        if name == \d => value = (node.animatedPathSegList or node.getAttribute(\d))
        animatedProperties[name] = anim-to-string(value)
      else subtags.push traverse(child)
    for v in node.attributes =>
      if animatedProperties[v.name]? =>
        attrs.push [v.name, animatedProperties[v.name]]
        delete animatedProperties[v.name]
      else attrs.push [v.name, v.value]
    for k,v of animatedProperties => attrs.push [k, v]
    if node.nodeName == \svg =>
      attrs.push ["xmlns", "http://www.w3.org/2000/svg"]
      attrs.push ["xmlns:xlink", "http://www.w3.org/1999/xlink"]
    ret = [
      """<#{node.nodeName} #{attrs.map(->"#{it.0}=\"#{it.1}\"").join(" ")}>"""
      subtags.join("\n").trim!
      """</#{node.nodeName}>"""
    ].filter(->it).join("")
    return ret

  smil-to-static = (root, delay) -> new Promise (res, rej) ->
    root.pauseAnimations!
    root.setCurrentTime delay
    <- setTimeout _, 0
    ret = traverse root
    res """<?xml version="1.0" encoding="utf-8"?>#ret"""

  module.{}smiltool.to-static = smil-to-static

  if GIF? =>
    smil-to-gif = (node, param-option = {}, param-gif-option = {}) -> new Promise (res, rej) ->
      imgs = []
      option = {width: 100, height: 100, frame: 30, duration: 1}  <<< param-option
      gif-option = { worker: 2, quality: 1 } <<< param-gif-option <<< option{width, height}
      gif = new GIF gif-option
      gif.on \finished, (blob) ->
        img = new Image!
        img.src = URL.createObjectURL blob
        res {gif: img, frames: imgs}
      _ = (t) ->
        if t >= option.duration => return gif.render!
        (ret) <- smil-to-static node, t .then
        img = new Image!
        img.style
          ..width  = "#{option.width}px"
          ..height = "#{option.height}px"
        img.src = "data:image/svg+xml;base64,#{btoa ret}"
        gif.addFrame img, { delay: option.duration * 1000 / option.frame }
        imgs.push img
        _ t + (option.duration / option.frame)
      _ 0
    module.smiltool.to-gif = smil-to-gif

) (if module? => module.{}exports else window)

# sample usage
/*
<- $ document .ready
option = {width: 200, height: 200}
gifoption = do
  worker: 2,
  quality: 10,
  workerScript: \gif.worker.js,
  transparent: 0x0000ff
smiltool.to-gif( document.getElementById(\svg), option, gifoption )
  .then -> document.body.appendChild it.gif
*/
