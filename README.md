
# smiltool

SMIL+CSS+SVG -> static SVG -> IMGS -> APNG / PNG Sequence / GIF


# options

 * general option
   * used in
     - smil-to-gif
     - smil-to-imgs
     - smil-to-pngs
     - imgs-to-gif
     - imgs-to-apng-i8a
     - imgs-to-apng-blob
   * members:
     - slow: 0 ( sampling delay between frames )
     - width: 100
     - height: 100
     - frames: 30
     - duration: 1 ( in seconds )
     - repeat-count
     - progress: (->)
     - step ( deprecated? replaced by progress? )
     - transparent ( e.g., 0x00ff00 or null ) # only used in gif earlier but it should be a global option

 * smil to svg option
   * used in
     - smil-to-svg ( passed to and used here by belows )
     - smil-to-gif
     - smil-to-pngs
     - smil-to-imgs
     - smil-to-apng-i8a
     - smil-to-apng-blob
   * members
     - css-animation
     - force-redraw
     - keep-paused - dont resume animation after rendered
       - for you are going to call smil-to-img multiple times ( like smil-to-imgs )
         set this will prevent image from back to animation. this could resolve timing issue in Safari.

 * gif option - passed to gif.js
   * used in:
     - smil-to-gif ( passed to imgs-to-gif )
     - imgs-to-gif ( passed to gif.js )
   * members:
     - transparent ( e.g., 0x00ff00 or null ) # this is an defined option in gif but we set it from geneal option
     - background ( e.g., #fff )
     - dither
     - debug
     - repeat ( 0 = infinite )
     - workers: 2
     - quality: 1
     - width: ( overwritten by general option )
     - height: ( overwritten by general option )


## Note

 * miscellaneous
   * always use integer in width and height

 * about image quality
   * One can control how image is resized / rendered with following approach:
     * ctx.imageSmoothingEnabled = false  ( default true )
     * image-rendering: crisp-edges / pixelated  ( default auto )
       - for indicating the resampling algorithm when image is resized
       - this works both for img and svg > image tags, but only if img are in raster format.
     * shape-rendering: crispEdges ( default auto )
       - hint browser about how to tradeoff when rendering shapes.
       - this works for shapes under svg tag. won't affect SVG file linked via image tag.


## Todo

 * Optimize CSS based animation generation
 * Support GIF format natively
 * GIF generation optimization


## LICENSE

MIT License.
