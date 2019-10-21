(->
  # guess format for unspecified input
  guess = (obj) ->
    format = if !obj => null
    else if obj.format => that
    else if typeof(obj) == \string =>
      if /^blob:/.exec(obj) => \bloburl
      else if /^data:/.exec(obj) => \datauri
      else \url
    else if (obj instanceof Blob) => \blob
    else if (obj instanceof ArrayBuffer) => \arraybuffer
    else if (obj instanceof Uint8Array) => \i8a
    type = if !obj => null
    else if obj.type => that
    else if typeof(obj) == \string =>
      if /^blob:/.exec(obj) => null
      else if /^data:(.+?)(;base64)?,/.exec(obj) => that.1
      else null
    else if (obj instanceof Blob) => obj.type
    else if (obj instanceof ArrayBuffer) => null # this still can be guessed. TODO
    else if (obj instanceof Uint8Array) => null  # this still can be guessed. TODO

  uri-retype = (obj, opt) -> new Promise (res, rej) ->
    if obj.type == opt.type => return res obj
    img = new Image!
    img.onerror = -> return rej new Error("uri-retype failed")
    img.onload = ->
      try
        [w,h] = [opt.width or img.width, opt.height or img.height]
        canvas = document.createElement("canvas")
        canvas.width = w
        canvas.height = h
        ctx = canvas.getContext \2d
        ctx.clearRect 0, 0, w, h
        ctx.fillStyle = 'rgba(255,255,255,0)'
        ctx.fillRect 0, 0, w, h
        # TODO check opt.scale
        ctx.drawImage(
          img,
          0, 0, img.width, img.height,
          (w - img.width)/2,
          (h - img.height)/2,
          img.width, img.height
        )

        if opt and opt.transparent =>
          r = (opt.transparent .>>. 16)
          g = (opt.transparent .>>. 8) % 256
          b = (opt.transparent  % 256)
          # make image transparent according to the transparency color
          img-data = ctx.getImageData(0,0,w,h)
          d = img-data.data
          for i from 0 til d.length by 4 =>
            if d[i] == r and d[i + 1] == g and d[i + 2] == b => d[i + 3] = 0
          ctx.putImageData img-data,0, 0

        res {data: canvas.toDataURL(opt.type, opt.quality), type: opt.type, format: \datauri}
      catch e
        rej e
    img.src = obj.data or obj

  # deprecated
  png-iend-fix = (a8) ->
    a8[a8.length - 4] = 0xae
    a8[a8.length - 3] = 0x42
    a8[a8.length - 2] = 0x60
    a8[a8.length - 1] = 0x82
    return a8

  i8a = arraybuffer = do
    to-bloburl: (obj, opt = {}) ->
      i8a.to-blob obj, opt .then (r) -> {data: URL.createObjectURL(r.data), type: obj.type, format: \bloburl}
    to-blob: (obj, opt = {}) -> new Promise (res, rej) ->
      ret = { type: obj.type or opt.type, format: \blob }
      ret.data = if obj.type == \image/svg+xml =>
        buf = if obj.format == \arraybuffer => new Uint8Array(obj.data) else obj.data
        new Blob [String.fromCharCode.apply(null, buf)], {type: obj.type}
      else new Blob([obj.data], {type: opt.type})
      res ret
    to-datauri: ->

  datauri = do
    retype: (obj, opt = {}) -> Promise.resolve!then ->
      return if opt.type and obj.type != opt.type => uri-retype(obj, opt)
      else obj
    split: (data) ->
      [head,body] = data.split(\,)
      ret = /data:(.+?)(;base64)?$/.exec(head)
      type = if ret => ret.1 else null
      return if /base64/.exec(head) => {type, body: atob(body)}
      else {type, body: decodeURIComponent(body)}
    to-bloburl: (obj, opt = {}) -> datauri.retype obj, opt .then (obj) ->
      datauri.to-blob(obj, opt).then (r) -> {data: URL.createObjectURL(r.data), type: obj.type, format: \bloburl}
    to-blob: (obj, opt = {}) -> datauri.retype obj, opt .then (obj) ->
      if obj.type == \image/svg+xml =>
        {data: new Blob([datauri.split(obj.data).body], obj{type}), type: obj.type, format: \blob}
      else datauri.to-i8a(obj, opt).then (r) -> i8a.to-blob r, opt
    to-arraybuffer: (obj, opt) -> datauri.retype obj, opt .then (obj) ->
      {type, body} = datauri.split obj.data
      byte-string = body
      ab = new ArrayBuffer(byte-string.length)
      ia = new Uint8Array(ab)
      for i from 0 til byte-string.length => ia[i] = byte-string.charCodeAt i
      return {data: ab, type: obj.type or type, format: \arraybuffer}
    to-i8a: (obj, opt) -> datauri.retype obj, opt .then (obj) ->
      bin = datauri.split(obj.data).body
      len = bin.length
      len32 = len .>>. 2
      a8 = new Uint8Array len
      a32 = new Uint32Array a8.buffer, 0, len32
      [i,j] = [0,0]
      for i from 0 til len32
        a32[i] = (
          (bin.charCodeAt j++) .|. (bin.charCodeAt(j++) .<<. 8)
          .|. (bin.charCodeAt(j++) .<<. 16 ) .|.  (bin.charCodeAt(j++) .<<. 24 )
        )
      tail-len = len .&. 3
      for i from tail-len til 0 by -1
        a8[j] = bin.charCodeAt j
        j++
      # - png-iend-fix might actually be caused by the bug in the above loop which omitted the 'by -1'. 
      #   we will do some additional test to check if this is really fixed, then remove it.
      # res {data: (if obj.type == \png => png-iend-fix(a8) else a8), type: obj.type, format: \i8a}
      return {data: a8, type: obj.type, format: \i8a}

  # To make retype work, URL must go through datauri to any other format.
  url = do
    to-bloburl: (src, opt = {}) -> url.to-blob(src, opt).then (r) ->
      {data: URL.createObjectURL(r.data), type: r.type, format: \bloburl}
    to-blob: (src, opt = {}) ->
      url.to-datauri src, opt .then (r) -> datauri.to-blob r, opt
    to-arraybuffer: (src, opt = {}) ->
      url.to-datauri src, opt .then (r) -> datauri.to-arraybuffer r, opt
    to-i8a: (src, opt = {}) ->
      url.to-datauri src, opt .then (r) -> datauri.to-i8a r, opt
    to-datauri: (src, opt = {}) -> new Promise (res, rej) ->
      r = new XMLHttpRequest!
      r.open \GET, src, true
      r.responseType = \blob
      r.onload = ->
        fr = new FileReader!
        fr.onerror = -> rej new Error(it)
        fr.onload = ->
          ret = {data: fr.result, type: r.response.type, format: \datauri}
          if r.response.type != opt.type => datauri.retype ret, opt .then -> res it
          else res ret
        fr.readAsDataURL r.response
      r.send!

  ldimg = do
    url: url
    datauri: datauri
    i8a: i8a
    arraybuffer: arraybuffer

  if window? => window.ldimg = ldimg
)!

show = (obj, root, name) -> new Promise (res, rej) ->
  div = ld$.create name: \div, className: <[p-2 d-inline-block m-2 text-center shadow-sm]>
  name-span = ld$.create name: \div, text: "#name(#{obj.type})"
  size-span = ld$.create name: \div, text: "#{Math.round(10 * (obj.data.length or obj.data.byteLength) / 1024)/10}KB"
  img = new Image!
  img.onerror = -> rej new Error("show img fail")
  img.onload = -> res!
  div.appendChild name-span
  div.appendChild size-span
  div.appendChild img
  root.appendChild div
  if obj.format == \i8a => ldimg.i8a.to-bloburl obj, {} .then (r) -> img.src = r.data
  else if obj.format == \arraybuffer => ldimg.arraybuffer.to-bloburl(obj, {}).then (r) -> img.src = r.data
  else img.src = obj.data

<[svg png jpg gif]>.map (postfix) ->
  name = "/assets/img/sample.#postfix"
  container = document.querySelector "\#block-#postfix"
  ldimg.url.to-i8a name, {}
    .then -> show it, container, "i8a"
    .then -> ldimg.url.to-arraybuffer name
    .then -> show it, container, "arraybuffer"
    .then -> ldimg.url.to-datauri name, {}
    .then -> show it, container, "datauri"
    .then -> ldimg.url.to-bloburl name, {}
    .then -> show it, container, "bloburl"

<[png jpg webp]>.map (postfix) ->
  name = "/assets/img/sample.svg"
  type = "image/#postfix"
  container = document.querySelector "\#block-svg-#postfix"
  ldimg.url.to-i8a name, {type}
    .then -> show it, container, "i8a"
    .then -> ldimg.url.to-arraybuffer name, {type}
    .then -> show it, container, "arraybuffer"
    .then -> ldimg.url.to-datauri name, {type}
    .then -> show it, container, "datauri"
    .then -> ldimg.url.to-bloburl name, {type}
    .then -> show it, container, "bloburl"

