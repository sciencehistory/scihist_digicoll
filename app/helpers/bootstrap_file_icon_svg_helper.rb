# We want just a few Boostrap Icon SVGs, included inline, so we can style them
# with CSS.
#
# pasting them into helper methods is just the simplest way that could possibly
# work, and good enough for now -- if we wanted more than a few of these, we'd
# have to do something more sophisticated.
#
# These are taken from bootstrap icons v1.11.0 https://icons.getbootstrap.com/
# , which is permissively MIT licensed.
#
# BUT then also edited to remove right/left padding, cause work better for us
# like that.
#
# OPTIMIZATION IDEAS at https://github.com/sciencehistory/scihist_digicoll/issues/2482
module BootstrapFileIconSvgHelper
  def file_earmark_pdf_fill_svg
    <<-EOS.strip_heredoc.html_safe
      <svg width="12" height="16" fill="currentColor" class="bi bi-file-earmark-pdf-fill" viewBox="0 0 9 16" xmlns="http://www.w3.org/2000/svg">
        <path d="m 2.023,12.424 c 0.14,-0.082 0.293,-0.162 0.459,-0.238 a 7.878,7.878 0 0 1 -0.45,0.606 c -0.28,0.337 -0.498,0.516 -0.635,0.572 A 0.266,0.266 0 0 1 1.362,13.376 0.282,0.282 0 0 1 1.336,13.332 c -0.056,-0.11 -0.054,-0.216 0.04,-0.36 0.106,-0.165 0.319,-0.354 0.647,-0.548 z m 2.455,-1.647 c -0.119,0.025 -0.237,0.05 -0.356,0.078 a 21.148,21.148 0 0 0 0.5,-1.05 12.045,12.045 0 0 0 0.51,0.858 c -0.217,0.032 -0.436,0.07 -0.654,0.114 z m 2.525,0.939 a 3.881,3.881 0 0 1 -0.435,-0.41 c 0.228,0.005 0.434,0.022 0.612,0.054 0.317,0.057 0.466,0.147 0.518,0.209 a 0.095,0.095 0 0 1 0.026,0.064 0.436,0.436 0 0 1 -0.06,0.2 0.307,0.307 0 0 1 -0.094,0.124 0.107,0.107 0 0 1 -0.069,0.015 C 7.411,11.969 7.243,11.906 7.003,11.716 Z M 4.778,6.97 C 4.738,7.214 4.67,7.494 4.578,7.799 A 4.86,4.86 0 0 1 4.489,7.453 C 4.413,7.1 4.402,6.823 4.443,6.631 4.481,6.454 4.553,6.383 4.639,6.348 A 0.517,0.517 0 0 1 4.784,6.308 C 4.797,6.338 4.812,6.4 4.816,6.506 4.821,6.628 4.809,6.783 4.778,6.971 Z" id="path2" />
        <path fill-rule="evenodd" d="M 0.5,0 H 5.793 A 1,1 0 0 1 6.5,0.293 L 10.207,4 A 1,1 0 0 1 10.5,4.707 V 14 a 2,2 0 0 1 -2,2 h -8 a 2,2 0 0 1 -2,-2 V 2 a 2,2 0 0 1 2,-2 z M 6,1.5 v 2 a 1,1 0 0 0 1,1 H 9 Z M 0.665,13.668 c 0.09,0.18 0.23,0.343 0.438,0.419 0.207,0.075 0.412,0.04 0.58,-0.03 0.318,-0.13 0.635,-0.436 0.926,-0.786 0.333,-0.401 0.683,-0.927 1.021,-1.51 a 11.651,11.651 0 0 1 1.997,-0.406 c 0.3,0.383 0.61,0.713 0.91,0.95 0.28,0.22 0.603,0.403 0.934,0.417 a 0.856,0.856 0 0 0 0.51,-0.138 c 0.155,-0.101 0.27,-0.247 0.354,-0.416 0.09,-0.181 0.145,-0.37 0.138,-0.563 a 0.844,0.844 0 0 0 -0.2,-0.518 c -0.226,-0.27 -0.596,-0.4 -0.96,-0.465 A 5.76,5.76 0 0 0 5.978,10.572 10.954,10.954 0 0 1 4.998,8.886 C 5.248,8.226 5.435,7.602 5.518,7.092 5.554,6.874 5.573,6.666 5.566,6.478 A 1.238,1.238 0 0 0 5.439,5.94 0.7,0.7 0 0 0 4.962,5.575 C 4.76,5.532 4.552,5.575 4.361,5.652 3.984,5.802 3.785,6.122 3.71,6.475 3.637,6.815 3.67,7.211 3.756,7.611 3.844,8.017 3.994,8.459 4.186,8.906 a 19.697,19.697 0 0 1 -1.062,2.227 7.662,7.662 0 0 0 -1.482,0.645 c -0.37,0.22 -0.699,0.48 -0.897,0.787 -0.21,0.326 -0.275,0.714 -0.08,1.103 z" id="path4" />
      </svg>
    EOS
  end

  def file_earmark_zip_fill_svg
    <<-EOS.strip_heredoc.html_safe
      <svg width="12" height="16" fill="currentColor" class="bi bi-file-earmark-zip-fill" viewBox="0 0 12 16" xmlns="http://www.w3.org/2000/svg">
        <path d="M 3.5,9.438 V 8.5 h 1 V 9.438 A 1,1 0 0 0 4.53,9.681 L 4.93,11.279 4,11.899 3.07,11.279 3.47,9.681 A 1,1 0 0 0 3.5,9.438 Z" id="path116" />
        <path d="M 7.293,0 H 2 A 2,2 0 0 0 0,2 v 12 a 2,2 0 0 0 2,2 h 8 a 2,2 0 0 0 2,-2 V 4.707 A 1,1 0 0 0 11.707,4 L 8,0.293 A 1,1 0 0 0 7.293,0 Z M 7.5,3.5 v -2 l 3,3 h -2 a 1,1 0 0 1 -1,-1 z M 3.5,3 V 2 h -1 V 1 H 4 V 2 H 5 V 3 H 4 V 4 H 5 V 5 H 4 V 6 H 5 V 7 H 3.5 V 6 h -1 V 5 h 1 V 4 h -1 V 3 Z m 0,4.5 h 1 a 1,1 0 0 1 1,1 v 0.938 l 0.4,1.599 a 1,1 0 0 1 -0.416,1.074 l -0.93,0.62 a 1,1 0 0 1 -1.109,0 l -0.93,-0.62 A 1,1 0 0 1 2.1,11.037 L 2.5,9.438 V 8.5 a 1,1 0 0 1 1,-1 z" id="path118" />
      </svg>
    EOS
  end

  def file_earmark_fill_svg
    <<-EOS.strip_heredoc.html_safe
      <svg xmlns="http://www.w3.org/2000/svg" width="12" height="16" fill="currentColor" class="bi bi-file-earmark-fill" viewBox="0 0 12 16">
        <path d="M 2,0 H 7.293 A 1,1 0 0 1 8,0.293 L 11.707,4 A 1,1 0 0 1 12,4.707 V 14 a 2,2 0 0 1 -2,2 H 2 A 2,2 0 0 1 0,14 V 2 A 2,2 0 0 1 2,0 m 5.5,1.5 v 2 a 1,1 0 0 0 1,1 h 2 z" id="path2" />
      </svg>
    EOS
  end

  def bi_check_circle_fill_svg
    <<-EOS.strip_heredoc.html_safe
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-check-circle-fill" viewBox="0 0 16 16">
        <path d="M16 8A8 8 0 1 1 0 8a8 8 0 0 1 16 0m-3.97-3.03a.75.75 0 0 0-1.08.022L7.477 9.417 5.384 7.323a.75.75 0 0 0-1.06 1.06L6.97 11.03a.75.75 0 0 0 1.079-.02l3.992-4.99a.75.75 0 0 0-.01-1.05z"/>
      </svg>
    EOS
  end


  # okay, actually from fontawesome.
  # https://fontawesome.com/icons/file-audio?f=classic&s=solid
  #
  # We don't LOVE this icon, but bootstrap doesn't have a file-audio icon! Only file-music
  # with a music note, not what we want.
  #
  # 4 Jan 2023.  Free font awesome svg are licensed  CC-BY, with attribution
  # in the svg sufficient. https://fontawesome.com/license/free
  #
  # Removed height and width, and removed fill from internal path, replaced with fill="currentColor"
  # Added class fa-custom-svg for testing identification etc.
  #
  # Experimented with referencing a symbol from an external svg, so it can be cached and not included
  # multiple times on a page. we DO need to repeat the viewBox here to
  def fa_file_audio_class_solid
    <<-EOS.strip_heredoc.html_safe
      <svg xmlns="http://www.w3.org/2000/svg" class="fa-custom-svg" fill="currentColor" viewBox="0 0 384 512">
        <!--!Font Awesome Free 6.5.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free Copyright 2024 Fonticons, Inc.-->
        <path opacity="1" d="M64 0C28.7 0 0 28.7 0 64V448c0 35.3 28.7 64 64 64H320c35.3 0 64-28.7 64-64V160H256c-17.7 0-32-14.3-32-32V0H64zM256 0V128H384L256 0zm2 226.3c37.1 22.4 62 63.1 62 109.7s-24.9 87.3-62 109.7c-7.6 4.6-17.4 2.1-22-5.4s-2.1-17.4 5.4-22C269.4 401.5 288 370.9 288 336s-18.6-65.5-46.5-82.3c-7.6-4.6-10-14.4-5.4-22s14.4-10 22-5.4zm-91.9 30.9c6 2.5 9.9 8.3 9.9 14.8V400c0 6.5-3.9 12.3-9.9 14.8s-12.9 1.1-17.4-3.5L113.4 376H80c-8.8 0-16-7.2-16-16V312c0-8.8 7.2-16 16-16h33.4l35.3-35.3c4.6-4.6 11.5-5.9 17.4-3.5zm51 34.9c6.6-5.9 16.7-5.3 22.6 1.3C249.8 304.6 256 319.6 256 336s-6.2 31.4-16.3 42.7c-5.9 6.6-16 7.1-22.6 1.3s-7.1-16-1.3-22.6c5.1-5.7 8.1-13.1 8.1-21.3s-3.1-15.7-8.1-21.3c-5.9-6.6-5.3-16.7 1.3-22.6z"/>
      </svg>
    EOS

    # notes toward another approach involving external file
    # "<svg viewBox='0 0 384 512'><use xlink:href='#{asset_path("svg_symbols/fa-file-audio-solid-def.svg#fa-file-audio-solid")}'></svg>".html_safe
  end
end
