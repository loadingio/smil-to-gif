# Smiltool Redesign

 - basic format and type conversion
   - arguments redesign.
     - func(obj, opt):
       - obj: {data, type, format}, for input image. or, a plain string, which indicates an URL.
         - type: mimetype. including: <[image/svg+xml image/png image/jpg image/webp]>
         - format: format used to encode image. including: <[url datauri i8a arraybuffer blob bloburl]>
       - opt: parameters.
         - width: expect image width
         - height: expect image height
         - type: expect output file type
         - quality: output quality, if applicable
         - scale: (tentative) whether to scale image or not when opt.width / opt.height not match the input image size.
         - gif: gif options. should be compatible with GIFJS.
         - animate: animation options
         - smil: smil options
   - architecture redesign.
     - smiltool / ldimg(tentative)
       - url
         to-blob / to-bloburl / to-i8a / to-arraybuffer / to-datauri
       - datauri
         to-blob / to-bloburl / to-i8a / to-arraybuffer
       - arraybuffer
         to-blob / to-bloburl
       - i8a
         to-blob / to-bloburl
     - all functions are promise based, and accept two arguments ( obj, opt )
       - url.xxx function accept also obj as plain url (string)
     - all functions return an updated obj in promise.
     - arraybuffer / i8a not yet support retyping, because they don't support to-datauri yet.

 - Animation generation
   - TBD.

## Options

 - animation-option
   - slow ( tentative ): used to slow down image sample rate.
   - duration
   - progress: function()
   - frames: should we rename it to fps?
   - repeat-count

  - smil-option - how smil should be handled.
   - delay: delay after the initial state of smil
   - force-redraw: ?
   - keep-paused
   - css-animation: set dom tree play-state = paused when converting if set to true
   - with-css: if set to true, always getComputedStyle, regardless of css-animation.
   - no-animation: wipe out animation related stuffs.

 - gif-option - options for GIFJS.
   - worker
   - quality
   - workerScript
   - transparent
   - ( other gif options.. )

 - other?
   - hrefs? ( possibly be used to provide datauri for inlining resouces when rendering in canvas. )


## Note

 - naming: use `datauri` instead of `url`. for referring `datauri` and `url`, use `uri`.
   - datauri better than dataurl
     - https://stackoverflow.com/questions/44209844/confusion-between-datauri-and-dataurl-in-javascript
     - https://stackoverflow.com/questions/176264/what-is-the-difference-between-a-uri-a-url-and-a-urn
 - support image type: image/svg+xml, png, jpg.
   - we use canvas.toDataURL to convert from any to png / jpg. 
   - toDataURL possible type: png, jpg, webp (webp is Chrome Only)
     - https://stackoverflow.com/questions/28544336/what-are-the-possible-data-types-for-canvas-todataurl-function
 - animation formats:
   - gif, apng, svg, imgs, i8as, datauris, blobs, pngs, ...


