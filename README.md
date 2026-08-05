# jekyll-is-images

Jekyll plugin for working with images and galleries.

## Concept

The main idea of the plugin: extended image processing *based on standard Markdown syntax*. Moreover, parsing
is performed by standard means as well, i.e. it does not require additional resources compared to the normal pipeline, and then
the plugin reinterprets the extended set of attributes by hooking into the Kramdown process.

There is a downside: *the plugin works strictly on top of Kramdown*, if you use another markdown converter,
most of the features will be unavailable.

### Functionality

1. Resizing, conversion and other image optimization.

2. Wrapping images in `figure` with extended styling capabilities, including "smart" floating positions, adding
   captions, text wrapping around the image (based on transparent areas).

3. Forming image galleries.

4. Generating Open Graph images for preview in social networks.

### Caching

Converted images are cached in a separate directory that can be preserved, for example, between sessions in GitHub Actions
and other build systems. Thus, when changing one page, it will not be necessary to regenerate images for the entire site.

## Setup

### System Requirements

+ The plugin is designed and tested **only under Linux**. Most likely, it will also work under other unix-like systems.

+ There is one external dependency, i.e. not installed automatically via `bundle install` — **ImageMagick** version 7.

### Direct Setup

The plugin is connected to Jekyll in standard ways: through the `:jekyll_plugins` group in `Gemfile` and/or through the `plugins`
section in `_config.yml`. In principle, this is enough, but there are nuances.

For more correct loading of CSS and JS, it is better to explicitly specify their loading in templates, if there is such an opportunity. Since
script and CSS names include versions and some other data, it is better to use liquid tags:

    {% is_images_css %}
    {% is_images_js %}

or all together in one line:

    {% is_images_stuff %}

And disable automatic loading by setting a parameter in `_config.yml`:

    is_images:
      disable_auto_stuff: true

### Markdown Features

For the main features tied to intercepting markdown markup to work, you also need to enable a custom markdown parser in the config.

    markdown: kramdown
    kramdown:
      input: ISKram

It is inherited from the standard `Kramdown` used in Jekyll by default, and its behavior is otherwise unmodified.

## Usage

### Markdown Markup

#### Images

Standard syntax `![Alt text](source){: attributes }` is used. However, the set of attributes is not simply passed to HTML,
but is interpreted for transformations. At the same time, familiar `#id`, `.class_name`, `style="border:none;"` work the same as
in basic Kramdown.

An important point regarding `source`, i.e. what is placed in parentheses in the markup and gets into the `src` attribute of the `<img ...>` tag:
if the image source starts with `/`, processing is *not performed*, i.e. the `<img ...>` tag is formed exclusively by *standard*
means. If an external link is specified there, i.e. starts with `http://` or `https://`, the image is *downloaded to cache*
if possible and processed.

There is a special attribute:

+ `is-image="‹value›"`

  `true` (as well as `1`, `yes`, `+`) or `false` (`0`, `no`, `-`). When set to `false`, the image is not processed and tags are generated
  by standard means. Setting to `true` for images starting with `/` does not enable processing, but allows the image to get into a gallery.
  In general, the attribute is not recommended for use, since the logic may be non-obvious.

Extended attributes:

+ `format="webp|avif|png|jpeg|tiff|..."`

  Target format. As a rule, it does not require specification, instead it is configured for the entire site. See below.

+ `href="‹url›|none|view"`

  Link. I.e. a construction like `<a href="..."><img ...></a>` is formed. At the same time, if the parameter is not specified, by default
  it is interpreted as `view` — that is, a local link to a larger version of the image.

+ `title="‹string›"`

  Forms the `title` attribute of the `<a>` tag (or `<span>`, if `href="none"`). By default, the text is taken from `alt`, i.e. what
  is written in square brackets.

+ `width="‹int›"`

  Image width, determines both the width of the `<img>` tag and (together with `height`, `fit` and `scale` parameters) the size
  of the transformed image.

+ `height="‹int›"`

  Image height.

+ `fit="contain|cover|fill|scale-down|none"`

  Fill mode. Corresponds to CSS `object-fit` values, affects image resizing. Default is `contain`.

+ `scale="‹float›"`

  Coefficient by which `width` and `height` are multiplied for resizing. Does not affect the size of the `<img>` tag. Can be,
  for example, used to enlarge the image on `:hover` (passed to CSS variable `--is-images-scale`).

+ `crop="‹int›x‹int›+‹int›+‹int›"`

  Allows selecting an area of the original image. Format: "`WxH+X+Y`".

+ `salt="‹string›"`

  Hash salt. Allows regenerating the resulting image without changing significant parameters.

+ `lazy`

  Flag (without value). Adds `loading="lazy"` to the `<img>` tag.

+ Additional format attributes.

  You can set additional parameters for conversion to the target format, like `webp-progressive="true"`. These parameters depend
  on the specific format and their set can be found in ImageMagick documentation. However, it is recommended to set such parameters
  not in the text, but in a special section of `_config.yml`.

+ View image attributes:

  + `view-format`,
  + `view-width`,
  + `view-height`,
  + `view-fit`,
  + `view-crop`.

  Affect the image for viewing on click.

+ `data-*` attributes

  Passed to the `<img>` tag "as is".

#### Illustrations

If an image is on a line separated by empty lines above and below, in standard Kramdown a construction like
`<p><img ...></p>` is formed. The plugin replaces it with a construction like `<figure><img ...></figure>` and additionally interprets the following
attributes and flags:

+ `caption="‹string›"` or `caption` flag

  Adds a `<figcaption>` tag, in the form of a flag the content of this tag is taken from `alt`.

+ `caption-position="top|bottom"`

  Determines the placement of the `<figcaption>` tag — above or below the image.

+ `right` or `left`

  Sets a "smart" floating position. In general, corresponds to CSS `float:right;` and `float:left;`, but wrapped with some additions —
  it is recommended to use these flags rather than simply specifying the property in `style="..."`.

+ `shape`

  Forms text wrapping around the image. Will work on formats with transparency: PNG, WebP and SVG. Works only for floating illustrations.

+ `up="‹int›"` and `shift=‹int›`

  Allows shifting the image relative to the normal position. `up` shifts up, and `shift` — right or left, depending
  on position — always outward, as if into the margins. Works only for floating illustrations.

Important point: attributes and flags can be specified both in the block IAL and in the inline element IAL, i.e. the image.

<pre>
{: ‹block attributes› }
![Alt text](source){: ‹image attributes› }

</pre>

The plugin will automatically transfer image attributes related to the block to the block attributes. Moreover, *all* classes and all flags, except `lazy`,
will also be transferred to `<figure>`. `style` values will be applied separately. This should be kept in mind when developing your own CSS working
with the plugin. This logic is introduced so that simple illustrations can be described in one line (i.e. without separately writing block attributes).

#### Galleries

If several images are gathered into one block, a gallery will be formed. A gallery can be represented in different modes, currently
two are available: `grid` and `slides`. Modes can be applied to the same gallery, then a toggle will be shown.

In addition to the aforementioned `caption` and `caption-position`, the gallery mode property is applicable:

+ `modes="‹list›"`

  Determines the set and *order* of modes applied to the gallery.

Also, the gallery overrides some properties of the images included in it. This is done via corresponding properties with a prefix,
depending on the mode.

|                    | `grid`                  | `slides`                 |
|--------------------|-------------------------|--------------------------|
| `format`           | `cell-format`           | `slide-format`           |
| `width`            | `cell-width`            | `slide-width`            |
| `height`           | `cell-height`           | `slide-height`           |
| `scale`            | `cell-scale`            | `slide-scale`            |
| `fit`              | `cell-fit`              | `slide-fit`              |
| `crop`             | `cell-crop`             | `slide-crop`             |
| `lazy`             | `cell-lazy`             | `slide-lazy`             |
| `caption-position` | `cell-caption-position` | `slide-caption-position` |

Yes, gallery elements are also wrapped in `<figure>` and `caption` properties are applicable to them — a separate value for each element, and `caption-position` —
the value is set at the gallery level. As can be seen from the prefixes, properties of its elements for different gallery modes are set independently.

#### Liquid Tags

If for some reason you do not want or cannot use a custom markdown parser (for example, you already use a different one instead of
the standard `Kramdown`), the functionality described above is also available via liquid tags.

    {% image src="‹source›" alt="‹alt text›" ‹attributes› %}

Important point: liquid markup knows nothing about the tag's surroundings. Accordingly, to determine that an image requires wrapping in `<figure>`,
we need to indicate this explicitly — with a `figure` flag in the attributes. Also, `src` and `alt` attributes must be specified in the standard way. Otherwise
the functionality is identical to that described above.

Galleries are formed using a liquid block:

    {% gallery ‹attributes› %}
      {% image src="image1.jpg" alt="First image" %}
      {% image src="image2.jpg" alt="Second image" %}
         . . . . .
      {% image src="imageN.jpg" alt="Nth image" %}
    {% endgallery %}

Inside the `{% gallery %}` environment, content formation via `{% if %}`, `{% for %}`, `{% include %}` and so on is allowed,
while all resulting content, except for `{% image %}` tags, is ignored.

#### Social Network Preview

This plugin hooks into the standard image definition for preview, which in Jekyll is determined by the `image` property
in the page's front matter. Our plugin takes the `image` property, transforms the image according to format and size, then overlays
plates with the page title, date and site name.

All this is configurable — see below.

### Configuration

#### General Principles

Settings are obtained cascadingly (in order of increasing priority):

+ Default values.

+ Values from `_config.yml` (from the `is_images` section).

+ Values from the current page's front matter (from the `is_images` section).

+ Values directly specified in attributes.

#### Example Config

    is_images:

      abort_on_error: true
      target_prefix: img
      cache_path: .is-images-cache
      cache_digits: 8

      disable_auto_stuff: true

      default_link: view
      caption_position: bottom

      view:
        width: 1800
        height: 1200

      gallery:
        caption_position: top
        modes: slides,grid

      grid:
        width: 200
        height: 200
        lazy: true

      slides:
        width: 800
        height: 600
        lazy: true

      formats:
        svg: svg
        jpeg: avif
        avif: avif
        default: webp

      options:
        jpeg:
          quality: 90
        webp:
          quality: 80
          method: 6
          progressive: true
          alpha_compression: 1
        avif:
          quality: 70
          speed: 1
          chroma_subsampling: '4:2:0'

      seo_image:
        format: webp
        width: 1200
        height: 630
        overlay:
          width: 1150
          bottom: 150
          top: 50
          padding: 25
          background: '#6669'
          foreground: '#EEEE'
        font:
          caption: PT-Sans-Caption
          date: PT-Mono
          date_size: 24
          site: PT-Sans-Narrow
        date_format: '%Y/%m/%d'
        site: My Blog

      min_text_width: 200
      max_text_width: 1920

For the most part, the values in this example are defaults, so there is no need to copy it entirely to `_config.yml`. The example is given for understanding the general structure of the configuration.

#### Global Settings

+ `target_prefix`

  Prefix of the image path on the site, default is `img`. That is, the default path looks like `/img/‹hash-path›.‹format›`.

+ `cache_digits`

  Number of characters in the last part of the hash path. In general, the SHA256 hashing algorithm is used, which gives a rather long sequence.
  On most sites it can be safely truncated without much risk of collisions. Default is `8`, i.e. paths look something like:
  `/img/01/23/456789ab.webp` — there are always two directories and both consist of two characters, but the last part — the "file name" — can be increased or shortened
  thanks to this setting.

+ `cache_path`

  Directory with image cache. Located inside the project directory, default is `.is-images-cache`. It is recommended to exclude this directory from the repository
  via `.gitignore`, but configure its intermediate saving between builds in GitHub Actions. There is little point in changing the default value.

+ `abort_on_error`

  `true` or `false`. Should the build be interrupted when an error occurs. Default is `true`.

+ `disable_auto_stuff`

  `true` or `false`. Allows disabling automatic insertion of CSS and JS loading, so that it can be neatly placed in page templates. By default empty,
  i.e. interpreted as `false`.

+ `disabled`

  `true` completely disables the plugin.

#### Default Behavior

+ `default_link`

  Determines behavior when the `href` attribute is not specified for an image. Variants `0`, `false`, `no`, `none` mean that no link
  will be generated; variants `1`, `true`, `yes`, `auto` and `view` mean that a link to a larger version of the image will be generated.

+ `view` subsection

  Contains `format`, `width`, `height`, `fit` and `crop` parameters, setting defaults for the corresponding `view-*` attributes. And this is the recommended
  use — set these parameters for the entire site at once, rather than writing them in attributes, except for `crop`, which is unlikely to be common for all images,
  and `format` — when not set, the same format is taken as the small image on the page, which is determined automatically, see below.

+ `caption_position`

  `top` or `bottom`. Default is `bottom`. Determines the position of captions *for single images*.

##### Galleries

+ `gallery` subsection:

  + `caption_position` — determines the position of gallery captions.

  + `modes`

    List of modes, determines the composition and order of gallery modes. Default is `grid,slides`. In most cases, modes will still be specified
    for each gallery separately, but if nothing is specified, this value will be used.

+ Mode subsections (currently `grid` and `slides`).

  + `format`, `width`, `height`, `scale`, `fit`, `crop` and `lazy` parameters, setting defaults for the prefixed values (`cell-*` and `slide-*` respectively).

  + `label` parameter — determines the mode name in the toggle.

#### Conversion Parameters

+ `formats` subsection

  Format mapping: from which source to which we convert. The default scheme is:

      formats:
        svg: svg
        jpeg: avif
        avif: avif
        default: webp

  It is assumed that we recompress photographs to avif, which gives them maximum compactness, and, for example, screenshots or images with transparency
  in PNG format (as well as all other formats not covered by an explicit rule) are converted to WebP preserving sharp edges and transparency.
  Vector images are not converted to other formats.

+ `options` subsection

  Additional conversion parameters passed to ImageMagick. These parameters depend on the target format, accordingly divided into subsections.
  By default:

      options:
        jpeg:
          quality: 90
        webp:
          quality: 80
          method: 6
          progressive: true
          alpha_compression: 1
        avif:
          quality: 70
          speed: 1
          chroma_subsampling: '4:2:0'

  Here it should be noted that `quality` is passed to ImageMagick as a general `-quality` parameter, the rest are passed via `-defines` by converting
  and joining, for example `webp:alpha-compression=1`, i.e. brought to the correct format. It should be noted separately that for the `avif` format the `heic:` prefix is automatically substituted instead of `avif:`... In general, most users will not need to change these parameters.

#### Social Network Preview

Settings are in the `seo_image` subsection.

+ `format`

  Default is `webp`, since more compact formats, even if supported by browsers, are not supported by social networks.

+ `crop`

  In the familiar format understood by ImageMagick — "`WxH+X+Y`". Allows selecting a fragment of the original image.

+ `width` and `height`

  Image resolution, default `1200` and `630`. At the same time, the image is fitted to these sizes always, even if the original image is smaller, since
  social networks simply will not accept too small an image.

+ `overlay` subsection

  Determines the main parameters of the text and overlay applied to the image. The overlay consists of two rectangles: the lower one for the title, the upper one —
  for the date and site name.

  + `width` — determines the common width for both parts of the overlay.

  + `bottom` — determines the height of the lower part of the overlay.

  + `top` — determines the height of the upper part of the overlay.

  + `padding` — offset value used in several places:

    + Offset from the top edge of the image to the top edge of the upper overlay part.
    + Offset from the bottom edge of the image to the bottom edge of the lower overlay part.
    + Right and left offsets inside the upper overlay part to the text.
    + Offsets on all sides inside the lower overlay part to the title text. Here it should be noted that the offset here determines the *available* for
      placing the title space, while its *actual* placement is determined by internal ImageMagick algorithms.

  + `background` — determines the overlay color, preferably with transparency. Default is `#6669` (specific to IM RGBA format). Any string can be used
    that ImageMagick will understand.

  + `foreground` — determines the text color. Default is `#EEEE`.

+ `font` subsection

  Determines the fonts used.

  + `caption` — title font.

  + `date` — date font.

  + `date_size` — date font size.

  + `site` — site name font. If not specified, the font from `date` is used.

  + `site_size` — site name font size. If not specified, the size from `date_size` is used.

+ `date_format`

  Date format. Default is "`%Y/%m/%d`".

+ `caption`

  Allows using an arbitrary string instead of the page title.

+ `date`

  Allows using an *arbitrary string* instead of the date.

+ `site`

  Allows using an arbitrary string instead of the site name.

#### Special Parameters

Floating illustrations are designed so that "floating" is disabled when the text becomes too narrow. Two special parameters are used to control this
behavior.

+ `min_text_width`

  The size of the text that *must remain* to the right or left of the image. That is, if (`min_text_width` + image width) exceeds
  the container width, the image stops being floating. Default is `200`.

+ `max_text_width`

  The mechanism of enabling/disabling "floating" generates rather bulky CSS constructs, to limit their generation only to needed ones,
  specify in this parameter the maximum container width possible on your site. Default is `1920`, can be made larger
  or smaller.

## License

The project is licensed under [GNU Lesser General Public License v3](https://www.gnu.org/licenses/lgpl-3.0.html).

This means that there are no restrictions on *using*
the plugin. If you want to fork it, or put the code *inside* your project, you will have to publish it
under the same LGPL or GPL.

## Roadmap

Current version is **0.8.0**.

Plans for next versions:

+ **0.8.2** — implement "page card" — a liquid tag for inserting a link to a page with an image and title.

+ **0.9.x**

  + Implement extensibility of gallery modes by extracting functionality into separate registrable classes.

  + Implement formatting in LaTeX.

+ **1.0**

  Stabilization of all declared functionality, detailed tests and documentation.
