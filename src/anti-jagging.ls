# dev start
# this is the test code for manually remove jagged edges,
# by truncate all pixels with < 1 alpha.
# for now we don't see the different between this and 'pixelated' rendering,
# so we probably won't use this.
if false =>
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
        img.onload = ->
          {width,height} = option
          canvas = document.createElement \canvas
          canvas <<< {width, height}
          ctx = canvas.getContext \2d
          ctx.clearRect 0, 0, width, height
          ctx.fillStyle = 'rgba(255,255,255,0)'
          ctx.fillRect 0, 0, width, height
          ctx.drawImage img, 0, 0, width, height
          cid = ctx.getImageData 0, 0, width, height
          for i from 0 til cid.data.length by 4
            if cid.data[i + 3] <= 254 =>
              cid.data[i + 0] = 255
              cid.data[i + 1] = 255
              cid.data[i + 2] = 255
              cid.data[i + 3] = 255
          ctx.putImageData cid, 0, 0
          ret = canvas.toDataURL!
          nimg = new Image
          nimg.onload = ->
            delay = Math.round(option.duration * 1000 / option.frames)
            handler.imgs.push {img: nimg, option: {delay}, src: nimg.src}
            imgs.push nimg
            setTimeout (-> _ t + (option.duration / option.frames)), option.slow
          nimg.src = ret
        img.src = "data:image/svg+xml;,#{encodeURIComponent ret}"
  # dev end
  return # skip by dev

