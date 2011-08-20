#!/usr/bin/ruby

# (c) 2006-2009 Benjamin Crowell, GPL licensed

# must be run from the book's directory
# reads stdin, writes stdout; normally invoked by doing "run_eruby.pl w"
# also has various side-effects, like converting figures to screen resolution if necessary, writing index.html, ...
# dependencies:
#    ruby version 1.9 or later (because of lookbehinds in regexes)
#    tex4ht (used in the equation_to_image.pl script to convert the more complicated equations to bitmaps)
#    pdftoppm (comes bundled with xpdf)
# command-line options:
#   --modern
#                            Generate xhtml, meta tag saying application/xhtml+xml, use svg and mathml features. The resulting file
#                            should have file extension .xhtml so that apache will serve it as application/xhtml+xml.
#                            If this option is not supplied, then by default:
#                            Generate html 4.01 that should work in all browsers, meta tag saying text/html, no svg or mathml.
#                            The resulting file should have file extension .html so that apache will serve it with as text/html.
#   --html5
#                            Similar to --modern, but generates html 5 with inline mathml.
#                            As of June 2009, I haven't actually been able to test this, because I don't have a browser that supports it.
#                            Firefox 3.5 beta 4 doesn't seem to support mathml in html 5.
#   --mathjax
#                            Generate html 4.01, with math in mathjax format.
#   --wiki
#                            Generate MediaWiki format. This is very crude at this point. After I used this to move everything into my mediawiki,
#                            I ended up doing a lot of mucking around  with bots to clean stuff up. See notes below.
#   --test
#                            In test mode, two things happen:
#                              - no ads generated
#                              - css link is to a local copy, not the http url
#   --redo_all_equations
#   --redo_all_tables
#   --no_write
#                            Only prevents writing to the toc and writing external files for equations.
#                            To prevent writing to the html file for each chapter, you also need to
#                            add the x parameter on the command line for run_eruby.pl in lm.make.
#===============================================================================================================================
#===============================================================================================================================
#===============================================================================================================================
#                                                TO DO
#===============================================================================================================================
#===============================================================================================================================
#===============================================================================================================================
# wiki
#   stuff I cleaned up using bots:
#     Should emit {{Fig|...}} and {{Fig_caption|...} templates.
#     For homework problems, should emit {{hw|...}} templates.
# has mysterious bug related to regexes
#   showed up ca. spring 2007
#   not always reproducible
#   ../translate_to_html.rb:604:in `block in handle_math': premature end of char-class: /0a7\313\231+\000\0000a7\313\231+\000\000align\*}/ (RegexpError)
#   probably is related to ruby's new regex engine
#   doesn't complain about the error the first time the line of code is executed; uses the regex many times, then finally breaks
#   Ended up coming up with something that seemed to fix this. Preconstruct an array of the regexes, and construct each regex from
#   a string that's cloned. (If you don't clone it, then it seems to get overwritten.)
#   bug report:
#     http://rubyforge.org/tracker/index.php?func=detail&aid=11510&group_id=426&atid=1698

# keep making sure it validates at http://validator.w3.org/
# Default should be:
#   - redo any figures whose original source files are newer than the bitmaps
#   - delete equations that are no longer referred to

# -- more important --
# The code at "FIXME: The following is meant to get the divs *after* the <h2> for a section..." needs to be fixed. This will tend to break
#     at inopportune times (and already has).
# garbled equations in NP10.5
# handle 'description' environment (NP10 summary)
# environments with 2 args don't work, e.g., \begin{reading}
# tabular in margin (VW4) doesn't get parsed, presumably same problem for equations in captions, etc.
# notation section messed up
# minipagefullpagewidth (just make it into a div?)
# in CL1, some tabular* environments don't come out right

# -- less important --

# try to get figures closer to relevant text; ideas:
#    - flush figures at a lower level in the hierarchy, if the number of figures is relatively low, and the amount of text in the queue is relatively high
#    - flush figures at every homework problem
# stuff marked kludge, bug, etc., in comments
# in math parsing, some TEXT stuff gets left as is; maybe move to a token-based parser, or use an external parser (but tth and ttm have licensing issues)
#       I have various kludges to fix this.
# EM2 equation fails, search for variable "doomed" in source code
# do something with \\ in hw
# align environments, etc., aren't quite done right; the basic reason is that my equation_to_image.pl script is written on the
#     assumption that there is only one line in the equation, and therefore there's only one bitmap to scrape out of the output;
#     to do an align environment or something, I run the script several times in a loop; fixing this would require convincing
#     myself that I understand what bitmap files to scrape out of tex4ht's output, rewriting some code that assumes only one
#     bitmap per environment, and rewriting code to incorporate the html code that tex4ht generates to surround the bitmaps;
#     what I've done instead is to split, e.g., an align up into a bunch of one-liner aligns

#===============================================================================================================================
#===============================================================================================================================
#===============================================================================================================================
#                                                command-line arguments
#===============================================================================================================================
#===============================================================================================================================
#===============================================================================================================================

def fatal_error(message)
  $stderr.print "error in translate_to_html.rb: #{message}\n"
  exit(-1)
end

require 'json'

require 'getoptlong' # pickaxe book, p. 452

opts = GetoptLong.new(
  [ "--modern",                GetoptLong::NO_ARGUMENT ],
  [ "--html5",                 GetoptLong::NO_ARGUMENT ],
  [ "--mathjax",               GetoptLong::NO_ARGUMENT ],
  [ "--wiki",                  GetoptLong::NO_ARGUMENT ],
  [ "--test",                  GetoptLong::NO_ARGUMENT ],
  [ "--redo_all_equations",    GetoptLong::NO_ARGUMENT ],
  [ "--redo_all_tables",       GetoptLong::NO_ARGUMENT ],
  [ "--no_write",              GetoptLong::NO_ARGUMENT ]
)

opts_hash = Hash.new
opts.each do |opt,arg|
  opts_hash[opt] = arg # for boolean options, arg is "" if option was set
end

$modern             = opts_hash['--modern']!=nil || opts_hash['--html5']!=nil
$html5              = opts_hash['--html5']!=nil
$mathjax            = opts_hash['--mathjax']!=nil
$wiki               = opts_hash['--wiki']!=nil
$test_mode          = opts_hash['--test']!=nil
$redo_all_equations = opts_hash['--redo_all_equations']!=nil
$redo_all_tables    = opts_hash['--redo_all_tables']!=nil
$no_write           = opts_hash['--no_write']!=nil

$stderr.print "modern=#{$modern} test=#{$test_mode} redo_all_equations=#{$redo_all_equations} redo_all_tables=#{$redo_all_tables} no_write=#{$no_write} mathjax=#{$mathjax} wiki=#{$wiki} html5=#{$html4}\n"

$xhtml = $modern
# xhtml requires, e.g., <meta ... />, but html requires <meta ...>
if $xhtml then
  $self_closing_tag = '/'
  $anchor = 'id'
else
  $self_closing_tag = ''
  $anchor = 'name'
end
$br = "<br#{$self_closing_tag}>"

#===============================================================================================================================
#===============================================================================================================================
#===============================================================================================================================
#                                                globals
#===============================================================================================================================
#===============================================================================================================================
#===============================================================================================================================

require "digest/md5"

config_file = 'html.config'
if ! File.exist?(config_file) then fatal_error("error, file #{config_file} does not exist") end
$config = {
  'book'=>nil, # a label for the book, is typically the same as the name of the directory the book resides in
  'title'=>nil, # human-readable title
  'url'=>nil,
  # The following directories can have ~ in them, which expands to home directory. The directories must exist.
    'base_dir'=>nil,'script_dir'=>nil,'html_dir'=>nil,'sty_dir'=>nil,
  # Sectioning:
     'number_sections_at_depth'=>nil,'spew_figs_at_level'=>nil,'restart_figs_at_level'=>nil,'highest_section_level'=>nil
}
File.open(config_file,'r') { |f|
  c = f.gets(nil) # nil means read whole file
  c.scan(/(\w+),(.*)/) { |var,value|
    if ! $config.has_key?(var) then fatal_error("Error in config file #{config_file}, illegal variable '#{var}'") end
    if {'base_dir'=>nil,'script_dir'=>nil,'html_dir'=>nil,'sty_dir'=>nil}.has_key?(var) then
      value.gsub!(/~/,ENV['HOME'])
      if ! FileTest.directory?(value) then fatal_error("#{var}=#{value}, but #{value} either does not exist or is not a directory") end
    end
    if {'number_sections_at_depth'=>nil,'spew_figs_at_level'=>nil,'restart_figs_at_level'=>nil,'highest_section_level'=>nil}.has_key?(var) then
      value = value.to_i
    end
    $config[var] = value
    $stderr.print "#{var}=#{value} "
  }
  $stderr.print "\n"
}
$config.keys.each { |k|
  if $config[k].nil? then fatal_error("error, variable #{k} not given in #{config_file}") end
}

$chapter_toc = "<div class=\"container\">Contents#{$br}\n"

$section_level_num = {'chapter'=>1,'section'=>2,'subsection'=>3,'subsubsection'=>4,'subsubsubsection'=>5}

$ch = nil
$chapter_title = nil
$count_eg = 0

$text_width_pixels = 500
$ad_width_pixels = 728
$margin_width = 80 # mm

$tex_math_trivial = "lt gt perp times sim ne le perp le nabla alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega Alpha Beta Gamma Delta Epsilon Zeta Eta Theta Iota Kappa Lambda Mu Nu Xi Omicron Pi Rho Sigma Tau Upsilon Phi Chi Psi Omega".split(/ /)
  # ... tex math symbols that have exactly the same names as html entities, e.g., \propto and &propto;
$tex_math_nontrivial = {'infty'=>'infin' , 'ldots'=>'hellip' , 'leq'=>'le' , 'geq'=>'ge' , 'partial'=>'part' , 'cdot'=>'sdot' , 'unitdot'=>'sdot'  ,  'propto'=>'prop',
                        'approx'=>'asymp' , 'rightarrow'=>'rarr'  ,  'flat'=>'#x266D'  ,  'degunit'=>'deg' }
  # ... nontrivial ones; trivial ones will now be appended to this list:
$tex_math_trivial_not_entities = "sin cos tan ln log exp".split(/ /)
$tex_math_not_entities = {'munit'=>'m' , 'sunit'=>'s' , 'kgunit'=>'kg' , 'nunit'=>'N' , 'junit'=>'J' , 'der'=>'d'  ,  'pm'=>'&#177;' ,  'degcunit'=>'&deg;C' , 'parallel'=>'||',
                          'sharp'=>'&#x266F;'}
$tex_math_not_in_mediawiki = {'munit'=>'\text{m}' , 'sunit'=>'\text{s}' , 'kgunit'=>'\text{kg}' , 'gunit'=>'\text{g}' , 'nunit'=>'\text{N}',
                              'junit'=>'\text{J}' , 'der'=>'d'  ,  'degcunit'=>'\ensuremath{\,^{\circ}}C' ,
                              'cancel'=>'', 'zu'=>'text'}

$tex_math_to_html = {}
$tex_math_trivial_not_entities.each {|x|
  $tex_math_to_html[x] = x
}
$tex_math_nontrivial.each {|x,y|
  $tex_math_to_html[x] = "&#{y};"
}
$tex_math_trivial.each {|x|
  $tex_math_to_html[x] = "&#{x};"
}
$tex_math_not_entities.each {|x,y|
  $tex_math_to_html[x] = y
}

$tex_symbol_pat = $tex_math_to_html.keys.join('|')
$tex_symbol_replacement_list = {}
$tex_math_to_html.each {|x,y|
  $tex_symbol_replacement_list[/\\#{x}/] = y
}

if !$wiki then
  # The special-casing is to get adsense to work with xhtml, since document.write() doesn't work in xhtml. This is shown inside an <object> tag in the xhtml.
  if $xhtml then
    # In the following, I don't need to give an IE-compatible alternative to the object tag, since the xhtml version will never be shown to IE anyway.
    $google_ad_html = <<'AD'
	<!-- ============== ad =============== -->
          <div id="ads">
          <object data="http://www.lightandmatter.com/adsense_for_xhtml.html" type="text/html"  width="728" height="90">
          </object>
          </div>
AD
  else
    # If I change the following, I also need to change it in http://www.lightandmatter.com/adsense_for_xhtml.html :
    $google_ad_html = <<'AD'
          <!-- ============== ad =============== -->
          <script type="text/javascript"><!--
          google_ad_client = "pub-2202341256191765";
          google_ad_width = 728;
          google_ad_height = 90;
          google_ad_format = "728x90_as";
          google_ad_type = "text";
          google_ad_channel ="";
          google_color_border = "dddddd";
          google_color_bg = "FFFFFF";
          google_color_link = "444444";
          google_color_text = "000000";
          google_color_url = "000000";
          //--></script>

          <script type="text/javascript"
                    src="http://pagead2.googlesyndication.com/pagead/show_ads.js">
          </script>
AD
  end
else
  $google_ad_html = ''
end

# In the following, the main point of the icon is to allow me to tell, for testing purposes, whether I'm seeing the xhtml version
# or the html version. I'm not displaying any icon for the html version, since that would just clutter up the page.
if $modern and !$html5 then
  valid_icon = '<p><img src="http://www.w3.org/Icons/valid-xhtml11-blue.png" alt="Valid XHTML 1.1 Strict" height="31" width="88"/></p>'
else
  #valid_icon = '<p><img src="http://www.w3.org/Icons/valid-html401-blue" alt="Valid HTML 4.01 Strict" height="31" width="88"/></p>'
  valid_icon = ''
end

if $wiki then
$disclaimer_html = <<DISCLAIMER
    <p>This is the wiki version of #{$config['title']}, by Benjamin Crowell. 
    This version may have some formatting problems.
    For serious reading, you want the printer-friendly <a href="#{$config['url']}">Adobe Acrobat version</a>.</p>
    <p>(c) 1998-2009 Benjamin Crowell, licensed under the <a href="http://creativecommons.org/licenses/by-sa/3.0/">Creative Commons Attribution-ShareAlike license</a>.
     Photo credits are given at the end of the Adobe Acrobat version.</p>
    </div>
DISCLAIMER
else
$disclaimer_html = <<DISCLAIMER
    <div class="topstuff">
    #{valid_icon}
    <p>You are viewing the html version of <b>#{$config['title']}</b>, by Benjamin Crowell. This version is only designed for casual browsing, and may have
    some formatting problems.
    For serious reading, you want the <a href="#{$config['url']}">Adobe Acrobat version</a>.</p>
    <p><a href="..">Table of Contents</a></p>
    <p>(c) 1998-2011 Benjamin Crowell, licensed under the <a href="http://creativecommons.org/licenses/by-sa/3.0/">Creative Commons Attribution-ShareAlike license</a>.
     Photo credits are given at the end of the Adobe Acrobat version.</p>
    </div>
DISCLAIMER
end

$ref = {}
$fig_ctr = 0
$footnote_ctr = 0
$footnote_stack = []

$protect_tex_math_for_mediawiki = {}

#===============================================================================================================================
#===============================================================================================================================
#===============================================================================================================================
#                                                methods
#===============================================================================================================================
#===============================================================================================================================
#===============================================================================================================================

def html_subdir(subdir)
  d = $config['html_dir'] + '/ch' + $ch + '/' + subdir
  make_directory_if_nonexistent(d,'html_subdir')
  return d
end

def is_calculus_book
  return $config['book']=='calc'
end

def make_directory_if_nonexistent(d,context)
  if ! File.exist?(d) then
    if system("mkdir -p #{d}") then
      $stderr.print "translate_to_html.rb successfuly created directory #{d}, context=#{context}\n"
    else
      $stderr.print "error in translate_to_html.rb, #{$?}, creating directory #{d}, context=#{context}\n"
      exit(-1) 
    end
  end
end

def wiki_style_section(n)
  h = ''
  (n-1).times do |i|
    h = h + '='
  end
  return h
end

def parse_itty_bitty_stuff!(tex)
  curly = "(?:(?:{[^{}]*}|[^{}]*)*)" # match anything, as long as any curly braces in it are paired properly, and not nested
  tex.gsub!(/\\verb@([^@]*)@/) {"\\verb{#{$1}}"}  # The \verb{} macro can be given with other delimeters, and I often use \verb@@.
  tex.gsub!(/\\verb\-([^\-]*)\-/) {"\\verb{#{$1}}"}  # ... or \verb--
  tex.gsub!(/\\verb{(#{curly})}/) {"<span class='monospace'>#{$1}</span>"}
  ["a","e","i","o","u"].each { |vowel|
    accents = {"`"=>'grave',"'"=>'acute','"'=>'uml'}
    accents.keys.each { |acc|
      entity = "&"+vowel+accents[acc]+";"
      tex.gsub!(/\\#{acc}\{#{vowel}\}/) {entity}
      tex.gsub!(/\\#{acc}#{vowel}/) {entity}
    }
  }
  tex.gsub!(/\\O{}/,'&Oslash;')
  tex.gsub!(/\\ae{}/,'&aelig;')
  tex.gsub!(/\.~/,'. ')
  tex.gsub!(/\\\-/,'')
  if !$mathjax then tex.gsub!(/\\ /,' ') end
  tex.gsub!(/\\%/,'%')
  tex.gsub!(/\\#/,'#')
  tex.gsub!(/\\(quad|qquad)/,' ')
  tex.gsub!(/\\hfill({#{curly}})?/,' ')
  tex.gsub!(/\\photocredit{(#{curly})}/) {" (#{$1})"}
  tex.gsub!(/\\textbf{(#{curly})}/) {"<b>#{$1}</b>"}
  tex.gsub!(/\\(?:textit|emph){(#{curly})}/) {"<i>#{$1}</i>"}
  if $wiki then
    tex.gsub!(/\\mypart{(#{curly})}/) {"\n\n=#{$1}=\n\n"} # extra newlines prevent confusion with <p></p> tags in NP 2, 6
    tex.gsub!(/\\formatlikesubsection{(#{curly})}/) {"===#{$1}==="}
  else
    tex.gsub!(/\\mypart{(#{curly})}/) {"\n\n<h1>#{$1}</h1>\n\n"} # extra newlines prevent confusion with <p></p> tags in NP 2, 6
    tex.gsub!(/\\formatlikesubsection{(#{curly})}/) {"<h3>#{$1}</h3>"}
  end
  tex.gsub!(/\\begin{indentedblock}/,'<div class="indentedblock"><p>')
  tex.gsub!(/\\end{indentedblock}/,'</p></div>')
  tex.gsub!(/\\begin{quote}/,'<div class="indentedblock"><p>')
  tex.gsub!(/\\end{quote}/,'</p></div>')
  tex.gsub!(/\\begin{offsettopic}/,'<div class="indentedblock"><p>')
  tex.gsub!(/\\end{offsettopic}/,'</p></div>')
  tex.gsub!(/\\epigraphnobyline{(#{curly})}/) {"<div class=\"epigraph\">#{$1}</div>"}
  tex.gsub!(/\\hwremark{(#{curly})}/) {"<div class=\"hwremark\">#{$1}</div>"}
  tex.gsub!(/\\oneofaseriesofpoints{(#{curly})}{(#{curly})}/) {"<b>#{$1}</b> #{$2}"}
  tex.gsub!(/\\linebreak/,$br)
  tex.gsub!(/\\pagebreak/,'')
  tex.gsub!(/\\smspacebetweenfigs/,'')
  tex.gsub!(/\\raggedright/,'')

  # environments that we don't care about:
  tex.gsub!(/\\(begin|end){(preface|longnoteafterequation|flushleft)}/,'')

  tex.gsub!(/\\anonymousinlinefig{(#{curly})}/) {name = $1; file=find_figure(name,'raw'); "<img src=\"figs/#{file}\" alt=\"#{name}\"#{$self_closing_tag}>"}
  tex.gsub!(/\\fullpagewidthfignocaption{(#{curly})}/) {name = $1; file=find_figure(name,'fullpage'); "<img src=\"figs/#{file}\" alt=\"#{name}\"#{$self_closing_tag}>"}
end

def parse_marg_stuff!(m)
  m.gsub!(/[ ]*\\(vfill|spacebetweenfigs)[ ]*/,'')
  m.gsub!(/[ ]*\\(vspace|hspace){[^}]+}[ ]*/,'')
  m.replace(parse_eensy_weensy(handle_tables(m)))
end

def parse_macros_outside_para!(tex)

  # macros that may occur by themselves, not part of any paragraph:
  tex.gsub!(/[ ]*\\(vspace|hspace|enlargethispage){[^}]+}[ ]*/,'')
  tex.gsub!(/[ ]*\\pagebreak\[\d+\][ ]*/,'')
  tex.gsub!(/[ ]*\\(vfill|spacebetweenfigs)[ ]*/,'')
  tex.gsub!(/[ ]*\\addtocontents[^\n]*[ ]*/,'')

  curly = "(?:(?:{[^{}]*}|[^{}]*)*)" # match anything, as long as any curly braces in it are paired properly, and not nested
  if $wiki then
    tex.gsub!(/\\startdq(s?)/) {"''Discussion Question#{$1}''\n\n"}
    tex.gsub!(/\\extitle{(#{curly})}{(#{curly})}/) {"===Exercise #{$1}: #{$2}==="}
  else
    tex.gsub!(/\\startdq(s?)/) {"<h5 class=\"dq\">Discussion Question#{$1}</h5>\n\n"}
    tex.gsub!(/\\extitle{(#{curly})}{(#{curly})}/) {"<h3>Exercise #{$1}: #{$2}</h3>"}
  end
  tex.gsub!(/\\selfcheck{[^}]*}{(#{curly})}/) {"\\begin{selfcheck}#{$1}\\end{selfcheck}"} # kludge for SN, which doesn't have them as environments; fails if nested {} inside $1
end

def parse_section(tex)

  parse_macros_outside_para!(tex)
  curly = "(?:(?:{[^{}]*}|[^{}]*)*)" # match anything, as long as any curly braces in it are paired properly, and not nested

  # <ol>, <ul>, and <pre> can't occur inside paragraphs, so make sure they're separated into their own paragraphs:
  ['itemize','enumerate','listing','tabular','verbatim'].each { |x|
    tex.gsub!(/(\\begin{#{x}})/) {"\n\n#{$1}"}
    tex.gsub!(/(\\end{#{x}})/) {"#{$1}\n\n"}
  }

  # Optional arguments are confusing, so replace them with {} that are always there.
  envs = ['important','lessimportant']
  r = {}
  envs.each { |x|
    r[x] = /\\(?:begin|end){#{x}}/
  }  
  envs.each { |x|
    result = ''
    inside = false # even if the environment starts at the beginning of the string, split() gives us a null string as our first string
    tex.split(r[x]).each { |d|
      if !(d=~/\A\s*\Z/) then
        if inside then
          if d=~/\A\[[^\]]*\]/ then
            d.gsub!(/\A\[([^\]]*)\]/) {"{#{$1}}"}
          else
            d = "{}" + d
          end
          d = "\\begin{#{x}}" + d + "\\end{#{x}}"
        end # if inside
        result = result + d
      end
      inside = !inside
    }
    tex = result
  }

  tex.gsub!(/egwide/,'eg')
  tex.gsub!(/\\begin{description}/,'\\begin{itemize}')
  tex.gsub!(/\\end{description}/,'\\end{itemize}')
  hw = 1
  # hwsection and summary are actually not needed in the following, since we change them to mysection using regexes early on
  envs = ['homework','eg','optionaltopic','selfcheck','dq','summary','vocab','notation','othernotation','summarytext','hwsection',
        'enumerate','itemize','important','lessimportant','dialogline',
        'exploring','reading','egnoheader','listing','verbatim','exsection']
  r = {}
  s = {}
  envs.each { |x|
    pat = x
    s[x] = "\\\\(?:begin|end){#{pat}}"
    z = s[x].clone  # workaround for bug in the ruby interpreter, which causes the first 8 bytes of the regex string to be overwritten with garbage
    r[x] = Regexp.new(z)
  }  
  envs.each { |x|
    nargs = {'eg'=>1,'optionaltopic'=>1,'important'=>1,'lessimportant'=>1,'selfcheck'=>1,'homework'=>3,'dialogline'=>1,'reading'=>2,'listing'=>1}[x]
    use_arg_as_title = {'eg'=>true,'optionaltopic'=>true,'important'=>true,'lessimportant'=>true}[x]
    generate_header = {'summary'=>[2,'Summary'],'vocab'=>[3,'Vocabulary'],'notation'=>[3,'Notation'],'othernotation'=>[3,'Other Notation'],
                       'summarytext'=>[3,'Summary'],'hwsection'=>[2,'Homework Problems'],
                        'exploring'=>[2,'Exploring further']}[x]
    # The following are used for environments that are going to become divs:
    stick_in = {'dq'=>'&loz;' , 'selfcheck'=>'<i>self-check:</i>' , 'exsection'=>'<h2>Exercises</h2>'} # goes right before the text
    stick_at_end = {'selfcheck'=>'(answer in the back of the PDF version of the book)'} # goes right after the text
    stick_in_front_of_header = {'eg'=>'Example NNNEG: ','optionaltopic'=>'Optional topic: '}
    # The following are used for environments that are *not* going to become divs:
    at_top = {'enumerate'=>'<ol>' ,'itemize'=>'<ul>','listing'=>'<pre>','verbatim'=>'<pre>'}
    at_bottom = {'enumerate'=>'</ol>','itemize'=>'</ul>','listing'=>'</pre>','verbatim'=>'</pre>'}
    result = ''
    inside = false # even if the environment starts at the beginning of the string, split() gives us a null string as our first string
    tex.split(r[x]).each { |d|
      if !(d=~/\A\s*\Z/) then
        if inside then
          if generate_header!=nil then
            l,h = generate_header[0],generate_header[1]
            if $wiki then
              equals = wiki_style_section(l)
              d = "#{equals}#{h}#{equals}\n\n" + d
            else
              d = "<h#{l}>#{h}</h#{l}>\n\n" + d
            end
          end
          args=[]
          if nargs then
           1.upto(nargs) { |i|
              d=~/\A{(#{curly})}/
              args[i]=$1
              d.gsub!(/\A{([^}]*)}/,'')
            }
          end
          arg = args[1]
          #if d=~/Kepler/ then $stderr.print "((((#{d}))))" end
          if use_arg_as_title and arg!=nil and arg.length>0 and arg=~/[a-z]/ then # sometimes length is 1, but character is non-printing??
            arg = handle_math(arg)
            front = ''
            if stick_in_front_of_header[x]!=nil then
              front=stick_in_front_of_header[x].clone
              if x=='eg' then $count_eg += 1 ; front.gsub!(/NNNEG/) {$count_eg.to_s} end
            end
            if $wiki then
              d = "=====#{front}#{arg}=====\n#{d}"
            else
              d = "<h5 class=\"#{x}\">#{front}#{arg}</h5>\n#{d}"
            end
          end
          if $wiki then
            top = "\n\n"
            bottom = "\n\n"
          else
            top = "\n\n<div class=\"#{x}\">\n\n"
            bottom = "\n\n</div>\n\n"
          end
          if x=='homework' then 
            d = "<b>#{hw}</b>. " + d
            hw+=1
            if args[1]!='' && !$wiki then top = top + "<a #{$anchor}=\"hw:#{arg}\"></a>" end
            if args[3]=='1' then d = d + " &int;" end
          end
          if x=='reading' then top = top + "<b>#{args[1]}</b>, <i>#{args[2]}</i>. " end
          if stick_in[x]!=nil then top = top + stick_in[x] end
          if x=='dialogline' then top = top + arg + ': ' end 
          if at_top[x]!=nil then top=at_top[x]; top.gsub!(/DQCTR/) {$dq_ctr} end
          if at_bottom[x]!=nil then bottom=at_bottom[x] end
          if stick_at_end[x]!=nil then bottom = stick_at_end[x]+bottom end
          if x=='listing' or x=='verbatim' then
            d.gsub!('<','&lt;')
            d.gsub!('>','&gt;')
            d.gsub!(/\n\s*\n/,"\nKEEP_BLANK_LINE\n")
            d.gsub!(/\n(\s+)/) {"\nKEEP_INDENTATION_#{$1.length}_SPACES"}
          end
          if x=='enumerate' or x=='itemize' then
            d.gsub!(/\\item\[([^\]]*)\]/) {"</li><li><b>#{$1}</b> "}
            d.gsub!(/\\item/,'</li><li>')
            d.sub!('</li>','') # get rid of bogus closing tag at first item
            d = d + '</li>' # add closing tag on last item
          end
          result = result + top + d + bottom
        else # not inside
          result = result + d
        end
      end
      inside = !inside
    } # end loop over d
    tex = result
  } # end loop over x

  # Massage tabular environments:
  # Change tabular* to tabular:
  tex.gsub!(/\\begin{tabular\*}{#{curly}}/,'\\begin{tabular}')
  tex.gsub!(/\\end{tabular\*}/,'\\end{tabular}')
  # Eliminate extra newlines in tabulars:
  tex.gsub!(/(\\begin{tabular})\n*/) {"\n\n"+$1}
  tex.gsub!(/\n*(\\end{tabular})/) {$1+"\n\n"}

  # Break it up into paragraphs, parse each paragraph, surround paras with <p> tags, but make sure not to make <p></p> pairs that surround one half of a <div></div> pair.
  # So far, the low-level parsing of equations and tables hasn't happened, so we don't have any of those divs yet. All we have is higher level ones, like
  # <div class="eg">. The way those were produced above, we made sure each <div> or </div> was on a line by itself, with blank lines above and below it.
  # Also, <p> tags can't contain any of the following: <p>, <h>, <div>
  # Bug: if parse_para returns something with nested divs in it, the code below won't work properly.
  result = ''
  tex.split(/\n{2,}/).each { |para|
    if para=~/^(<div|<\/div)/ then
      p = para
    else
      cooked = parse_para(para)
      #$stderr.print "cooked=============\n#{cooked}\n==============\n" if debug
      if para=~/<h\d/ or para=~/<p[^a-z]/ then # bug, won't work with wiki output
        p = cooked
      else
        # Can't have <div>'s nested inside <p>, so if there are equations, etc...:
        if !(cooked=~/<table/) then
          cooked.gsub!(/(<div)/) {"</p>"+$1}
          cooked.gsub!(/(<\/div>)/) {$1+"<p class=\"noindent\">"}
        end
        p = "\n\n" + '<p>' + cooked + "</p>\n\n"
      end
    end
    result = result + p
  }
  tex = result

  # Eliminate illegal and unnecessary <p> tags inside <ol>, <ul>, or <pre>.
  ['ol','ul','pre'].each { |x|
    result = ''
    inside = false # even if the environment starts at the beginning of the string, split() gives us a null string as our first string
    tex.split(/<\/?#{x}>/).each { |d|
      if !(d=~/\A\s*\Z/) then
        if inside then
          d.gsub!(/<p>/,'')
          d.gsub!(/<\/p>/,'')
          d = "<#{x}>" + d + "</#{x}>"
        end # if inside
        result = result + d
      end
      inside = !inside
    }
    tex = result
  }

  # Also can't enclose <ol>, <ul>, <pre>, or <table> inside <p>.
  ['ol','ul','pre','table'].each { |x|
    tex.gsub!(/<p>\s*<#{x}([^>]*)>/) {"<#{x}#{$1}>"}
    tex.gsub!(/<\/#{x}>\s*<\/p>/) {"</#{x}>"}
  }

  tex.gsub!(/KEEP_BLANK_LINE/,'')
  tex.gsub!(/KEEP_PERCENT/,'%')

  return tex
end

def replicate_string(s,n)
  if n<=0 then return '' end
  return s + replicate_string(s,n-1)  
end

def replace_list(x,r)
  # r = hash with regexes as keys
  k = r.keys.sort {|a,b| b.source.length <=> a.source.length} # do long ones first, so, e.g., \munit doesn't get parsed as \mu
  k.each { |a|
    b=r[a]
    debug = false
    $stderr.print "doing #{a.to_s} to #{b} on #{x}\n" if debug
    x.gsub!(a,b)
  }
  return x
end

def parse_simple_equation(x)
  debug = (x =~  /\(1\/f - 1\/d_i\)/)
  if x =~ /\\\\/ then return nil end
  if debug then $stderr.print "debugging #{x}\n" end
  # A common special case: a single boldfaced letter:
  if x=~/^\\vc{([a-zA-Z])}$/ then
    return "<b>#{$1}</b>" # I think this would already be a TEXTb0001x before we got in here
  end
  # The following is all complicated because < and > look like html.
  x.gsub!(/\\ll/,"\\lt\\lt")
  x.gsub!(/\\gg/,"\\gt\\gt")
  # don't want macros \munit and \nunit to be read as greek letters \mu and \nu
  x.gsub!(/\\munit/,"qqqmunitqqq")
  x.gsub!(/\\nunit/,"qqqnunitqqq")
  y = nil
  # Protect < and >, which would look like html:
  if x=~/(.*)([<>])(.*)/ then
    left,op,right = $1,$2,$3
    if op=='<' then u="\\lt" else u="\\gt" end
    left = parse_simple_equation(left)
    right = parse_simple_equation(right)
    if left!=nil and right!=nil then
      return left+u+right
    else
      return nil
    end
  end
  # nothing but whitespace, variables, digits, decimal points, addition, subtraction, division, equality, commas, parens, ||, symbols,
  # superscripts and subscripts, primes:
  if x=~/^((?:[ \ta-zA-Z\d\.\+\-\/\=\,\(\)\|{}\^\_\']|(?:\\(?:#{$tex_symbol_pat})))+)$/ then
    y = $1
    curly = "(?:(?:{[^{}]*}|[^{}]*)*)" # match anything, as long as any curly braces in it are paired properly, and not nested
    y.gsub!(/\^{(#{curly})}/) {"<sup>#{$1}</sup>"}
    y.gsub!(/\_{(#{curly})}/) {"<sub>#{$1}</sub>"}
    y.gsub!(/\^(\\[a-z]+)/) {"<sup>#{$1}</sup>"} # e.g., e^\pi
    y.gsub!(/\_(\\[a-z]+)/) {"<sub>#{$1}</sub>"} # e.g., E_\perp
    y.gsub!(/\^(.)/) {"<sup>#{$1}</sup>"}
    y.gsub!(/\_(.)/) {"<sub>#{$1}</sub>"}
    y.gsub!(/qqqmunitqqq/,"\\munit")
    y.gsub!(/qqqnunitqqq/,"\\nunit")
  end
  if debug then $stderr.print "debugging final result is #{y}\n" end
  return y
end

def truth_to_s(t)
  if t then return 'true' else return 'false' end
end

# Be careful not to return nested div's, because the code in parse_section can't handle that.
def handle_tables(tex)
  #$stderr.print "calledme\n"
  n= -1
  table = []


  result = ''
  inside = false # even if it starts with the environment, we get a null string for our first chunk
  tex.split(/\\(?:begin|end){tabular}/).each { |m|
    if !(m=~/\A\s*\Z/) then
      if inside then
        n+=1;
        table[n] = m
        # In the following, I'm not sure why I used to surround it in a div.table. I don't define any such div in lm.css.
        # Doing it resulted in ill-formed xhtml.
        # result = result + "<div class=\"table\">TABLE#{n}\.</div>"
        result = result + "TABLE#{n}."
      else
        result = result + m
      end
    end
    inside = !inside # needs to be outside the test for whether m is null, because we get a null for first chunk if string begins with envir
  }
  tex = result

  table.each_index { |n|
    m = handle_table_one(table[n])
    if m==nil then m=table[n] end
    tex.gsub!(/TABLE#{n}\./,m)
  }

  return tex

end

# arg is everything inside the tabular environment, including the parameter of the begin{tabular}.
# When tex4ht converts the table, it will convert the math inside it as well.
# However, it may generate bitmaps for complex math, which I don't want it to do inside a table (script can't handle it).
# Therefore, if a table comes back from tex4ht with bitmaps in it, we replace each bitmap with its alt value, and give a warning.
def handle_table_one(original)
        cache_dir = html_subdir('cache_tables')
        hash = hash_function(original)
        if $xhtml then ext='.xhtml' else ext='.html' end
        cache_file = cache_dir + '/table_' + hash + ext
        if (!$redo_all_tables) && File.exist?(cache_file) then
          File.open(cache_file,'r') { |f|
            return f.gets(nil) # nil means read whole file
          }
        end

        t = original.clone
        t = "\\begin{tabular}" + t + "\\end{tabular}"

        summarize = t.clone
        summarize =~ /^((.|\n){,80})/
        summarize = $1
        summarize.gsub!(/\n/,' ')
        $stderr.print "Producing table from latex code #{summarize}...\n"
        temp = 'temp.tex'
        temp_html = 'temp.html'
        File.open(temp,'w') do |f|
        f.print <<-TEX
  	\\documentclass{book}[12pt]
	\\RequirePackage{lmmath,amssymb,cancel}
        \\RequirePackage[leqno]{amsmath}
        \\begin{document}
        #{t}
        \\end{document}               
        TEX
        end # file
        doomed =  false 
        html = ''
        if doomed then
          $stderr.print "****************************This table is marked as not working -- not doing it ***********************************\n"
          return ''
        else
          if !File.exist?(temp) then $stderr.print "error, temp file #{temp} doesn't exist"; exit(-1) end
          fmt = 'html'
          if $xhtml then fmt='xhtml' end
          unless system("#{$config['script_dir']}/latex_table_to_html.pl #{temp} #{$config['sty_dir']}/lmmath.sty #{fmt} >/dev/null") then $stderr.print "error, #{$?}"; exit(-1) end
          File.open(temp_html,'r') { |f|
            html = f.gets(nil) # nil means read whole file
            html.gsub!(/\n*$/,"\n") # exactly one newline at the end
          }
        end
        failed = false
        html.gsub!(/<img[^<>]*alt=\"([^"]*)\"[^<>]*>/) {failed=true; $1} # replace image with its alt tag
        if failed then $stderr.print "warning, this table has complex math, couldn't do it correctly\n" end
        html.gsub!(/\n{2,}/,"\n")

        if html==nil or html=='' then
          $stderr.print "warning: table generated nil or null string for html"
        else
          html.gsub!(/<div class="tabular">/,'')
          html.gsub!(/<\/div>/,'')

          # The following are obsolete in html 5, validator complains about them:
          html.gsub!(/cellspacing="\d+"/,' ')
          html.gsub!(/cellpadding="\d+"/,' ')

          File.open(cache_file,'w') do |f|
            f.print html
          end
        end


        return html
end

# This was faster, but lost a lot of formatting, and couldn't handle complicated tables.
def handle_table_one_myself(original)
  t = original.clone
  t.gsub!(/\A{[^}]+}/,'') # get rid of, e.g., {|l|l|l|}
  t.gsub!(/\\hline/,'')
  result = ''
  t.split(/\\\\/).each { |line|
    unless line=~/\A\s*\Z/ then
      line = '<tr><td>' + ( line.split(/\&/).join('</td><td>') ) + '</td></tr>'
    end
    result = result + line + "\n"
  }
  return "<table>\n#{result}</table>\n"
end

# Handle all math occurring in a block of text.
# Be careful not to return nested div's, because the code in parse_section can't handle that.
def handle_math(tex,inline_only=false,allow_bitmap=true)

  n= -1
  math = []
  math_type = [] # inline, equation, align, multline, gather

  curly = "(?:(?:{[^{}]*}|[^{}]*)*)" # match anything, as long as any curly braces in it are paired properly, and not nested

  unless inline_only then

  tex.gsub!(/\\mygamma/) {"\\gamma"}

  if false then # I think this is no longer necessary now that I'm using footex, and in fact it causes problems.
  #--------------------- locate displayed math with intertext or multiple lines, and split into smaller pieces ----------------------------
  # This has to come before inline ($...$) math, because sometimes displayed math has \text{...$...$...} inside it.
  envs = ['align','equation','multline','gather','align*','equation*','multline*','gather*']
  r = {}
  s = {}
  envs.each { |x|
    pat = x.clone
    pat.gsub!(/\*/,'\\*')
    s[x] = "\\\\(?:begin|end){#{pat}}"
    z = s[x].clone # workaround for bug in the ruby interpreter, which causes the first 8 bytes of the regex string to be overwritten with garbage
    r[x] = Regexp.new(z)
  }  
  envs.each { |x|
    result = ''
    inside = false # even if it starts with the environment, we get a null string for our first chunk
    tex.split(r[x]).each { |m|
      if !(m=~/\A\s*\Z/) then # not pure whitespace
        if inside then 
          m.gsub!(/\\\\\s*\\intertext{(#{curly})}/) {"\\end{#{x}}\n#{$1}\n\\begin{#{x}}"}
          m.gsub!(/\\\\/,"\\end{#{x}}\n\\begin{#{x}}")
          result = result + "\\begin{#{x}}"
          result = result + m
          result = result + "\\end{#{x}}"
        else
          result = result + m
        end
      end
      inside = !inside # needs to be outside the test for whether m is null, because we get a null for first chunk if string begins with envir
    }
    tex = result
  } # end loop over align, equation, ...
  end

  #--------------------- locate displayed math ----------------------------
  # This has to come before inline ($...$) math, because sometimes displayed math has \text{...$...$...} inside it.
  envs = ['align','equation','multline','gather']
  r = {}
  s = {}
  envs.each { |x|
    s[x] = "\\\\(?:begin|end){#{x}\\*?}"
    z = s[x].clone  # workaround for bug in the ruby interpreter, which causes the first 8 bytes of the regex string to be overwritten with garbage
    r[x] = Regexp.new(z)
  }  
  envs.each { |x|
    result = ''
    inside = false # even if it starts with the environment, we get a null string for our first chunk
    tex.split(r[x]).each { |m|
      if !(m=~/\A\s*\Z/) then # not pure whitespace
        if inside then
          n+=1;
          math[n] = m
          math_type[n] = x
          result = result + "MATH#{n}\."
        else
          result = result + m
        end
      end
      inside = !inside # needs to be outside the test for whether m is null, because we get a null for first chunk if string begins with envir
    }
    tex = result
  }

  end # unless inline_only

  #--------------------- locate inline math ----------------------------
  # figure out what $ corresponds to what $:
  tex.gsub!(/(?<!\\)\$([^$]*[^$\\])\$/) {n+=1; math[n]=$1; math_type[n]='inline'; "MATH#{n}\."}

  #-------------------------------------------------

  math.each_index { |n|
    debug = false # math[n]=~/\{1\}\{2\}/
    m = handle_math_one(math[n],math_type[n],allow_bitmap)
    if m==nil then
      m=math[n]
    else
      if math_type[n]!='inline' and !( m=~/<div/) then
        m = begin_equation() + m + end_equation() # already has divs in it if it's not inline and was parsed into bitmaps
      end
    end
    tex.gsub!(/MATH#{n}\./,m)
  }


  #-------------------------------------------------
  # misc.:

  # certain macros force math environment, so sometimes I use them without $$; make sure those don't slip by:
  tex.gsub!(/\\vc{([a-zA-Z])}/) {"<b>#{$1}</b>"}
  tex.gsub!(/\\degunit/) {"&deg;"}
  tex.gsub!(/\\degcunit/) {"&deg;C"}
  tex.gsub!(/\\degfunit/) {"&deg;F"}
  tex.gsub!(/\\munit/,'m')
  tex.gsub!(/\\sunit/,'s')

  if !$mathjax then tex.gsub!(/\&\=/,'=') end # happens for displayed math that we couldn't handle, or didn't try to handle, from align environment

  return tex

end

# translate one particular equation, if possible; otherwise return nil
# foo = tex code for equation
# math_type = 'inline', 'align', or 'equation', or 'multline', or 'gather'
# allow_bitmap = boolean
def handle_math_one(foo,math_type,allow_bitmap)
  tex = foo.clone

  if tex=='' then
    $stderr.print "warning, null string passed to handle_math_one\n"
    return ''
  end

  debug = false # tex=~/\{1\}\{2\}/

  if $mathjax then
    if math_type=='inline' then
      return '\\('+prep_math_for_mathjax(tex)+'\\)' 
    else
      return "\\[\\begin{#{math_type}*}"+prep_math_for_mathjax(tex)+"\\end{#{math_type}*}\\]"
    end
  end

  tex.gsub!(/\\(begin|end){split}/,'') # we don't handle these (they occur inside other math environments)

  html = handle_math_one_html(tex.clone,math_type)
  return html if html!=nil
  return nil if !allow_bitmap
  html = handle_math_one_bitmap(tex.clone,math_type)
  return html if html!=nil
  return nil
end

def prep_math_for_mathjax(math)
  m = math.clone
  m.gsub!(/\</,'\\lt') # Keep < from being interpreted as html tag by browser.
  m.gsub!(/\\vc{([A-Za-z]+)}/) {"\\mathbf{#{$1}}"}
  m.gsub!(/\\unitdot/) {"\\!\\cdot\\!"}
  m.gsub!(/\\zu{([A-Za-z]+)}/) {"\\text{#{$1}}"}
  m.gsub!(/\\intertext/) {"\\text"}
  $tex_math_not_in_mediawiki.each { |k,v|
    m.gsub!(/\\#{k}/) {v}
  }
  m.gsub!(/\\$/) {"PROTECT_DOUBLE_BACKSLASH_FOR_MATHJAX"}
  return m
end

# translate one particular equation to html or mathml, if possible; return nil on failure
# math_type = 'inline', 'align', or 'equation', or 'multline', or 'gather'
def handle_math_one_html(tex,math_type)
  debug = false
  original = tex.clone
  if original=~/<\/?i>/ then
    $stderr.print "huh? m has <i> in it, getting ready to produce tex code\n#{original}\n"
    return tex
  end

  m = tex.clone
    m.gsub!(/\&\=/,'=') # we don't try to handle alignment
    m.gsub!(/_\\zu{o}/,'_o')
    m.gsub!(/\\(quad|qquad)/,' ') # we don't try to handle spacing
    m.gsub!(/\\[ :,]/,' ')
    m.gsub!(/\\(?:text|zu){([A-Za-z]+)}/) {"TEXTu#{sprintf("%04d",$1.length)}#{$1}"} # parsing gets too complex if not A-Za-z, because can't tell what gets italicized
    m.gsub!(/\\(?:vc|mathbf){([A-Za-z]+)}/) {"TEXTb#{sprintf("%04d",$1.length)}#{$1}"}
    y = parse_simple_equation(m)
    if debug then $stderr.print "--------in handle_math_one_html, y=#{y}\n" end
    if y!=nil then
      if debug then $stderr.print "--------in handle_math_one_html, y not nil\n" end
      # italicize variables
      y.gsub!(/((?:[^<>]+)|(?:<\/?\w+>))/) {
        e=$1;
        if !(e=~/</) then e.gsub!(/([a-zA-Z]+)/) {"<i>#{$1}</i>"} end;
        e
      }
      # stuff like \pi gets the p and the i italicized; fix this:
      y.gsub!(/\\<i>([^<]+)<\/i>/) {"\\#{$1}"}
      $stderr.print "3. #{y}\n" if debug
      y = replace_list(y,$tex_symbol_replacement_list)
      if debug then $stderr.print "~~~~~~~~ 1   "+y+"\n" end
      y.gsub!(/<i>([a-zA-Z]+)TEXT/) {"#{$1}<i>TEXT"} # e.g., <i>qTEXTb</i>0001 becomes q<i>TEXTb</i>0001
      if debug then $stderr.print "~~~~~~~~ 2   "+y+"\n" end
      begin # I don't understand why it's necessary to wrap y.gsub! in this loop, but apparently it is
        did_one = false
        y.gsub!(/<i>TEXT(.)<\/i>(\d\d\d\d)<i>(.*)/) { # guaranteed an <i> marker, because only matched if A-Za-z
          did_one = true
          what,len,stuff = $1,$2.to_i,$3
          crud = stuff[0..len-1]
          if what=='b' then crud = "<b>#{crud}</b>" end
          final = crud + "<i>" + stuff[len..(stuff.length-1)] # may cause <i></i>, which gets eliminated by peepholer below
          if debug then $stderr.print "~~~~~~~~ 3   "+final+"\n" end
          final
        }
      end while did_one
      if debug then $stderr.print "~~~~~~~~ 4   "+y+"\n" end
      y.gsub!(/<i><\/i>/,'')
      #$stderr.print "parsed $#{original}$ to $#{m}$, to #{y}\n"
      y.gsub!(/TEXT.\d\d\d\d/) {''} # shouldn't happen, but does in SN10
      y.gsub!(/<i>TEXT.<\/i>\d\d\d\d/) {''} # shouldn't happen, but does in SN10
    end
    # remove leading and trailing whitespace
    if y!=nil then
      y.gsub!(/^\s+/,'')
      y.gsub!(/\s+$/,'')
      y.gsub!(/{}/,'') # some equations in SN have empty {} for tex
      if y=='' then y=nil end
    end
    if y!=nil then return y end

    if $xhtml then
      # If it's something like an align environment, it may have \\ in it, so we need to surround it with a begin/end block, or else blahtex will get upset.
      surround = (math_type!='inline' && math_type!='equation') 
      t = 'temp_mathml'
      if surround then original = "\\begin{#{math_type}}" + original + "\\end{#{math_type}}" end
      File.open("#{t}.tex",'w') do |f| f.print original end
      unless system("footex --prepend-file #{$config['sty_dir']}/lmmath.sty --mathml #{t}.tex #{t}.html") then return nil end
      y = nil
      File.open("#{t}.html",'r') { |f|
        y = "<!-- #{original} -->"
        y.gsub!(/\n/,' ')
        y = y + "\n" + '<math xmlns="http://www.w3.org/1998/Math/MathML">'+(f.gets(nil))+'</math>' # nil means read whole file
      }
      y.gsub!(/<mtext>([^<]*)<mtext>([^<]*)<\/mtext>([^<]*)<\/mtext>/) {"<mtext>#{$1}#{$2}#{$3}</mtext>"} #qwe
    end

    if $wiki then
      # If it's something like an align environment, it may have \\ in it, so we need to surround it with a begin/end block, or else blahtex will get upset.
      surround = (math_type!='inline' && math_type!='equation') 
      t = 'temp_mathml'
      if surround then original = "\\begin{#{math_type}}" + original + "\\end{#{math_type}}" end # mediawiki's texvc can handle these; see http://en.wikipedia.org/wiki/Help:Displaying_a_formula
      key = hash_function(original)
      $protect_tex_math_for_mediawiki[key] = '<math>'+original+'</math>'
      y = "\nPROTECT_TEX_MATH_FOR_MEDIAWIKI" + key + "ZZZ"
    end

    return y
end



# <b>F</b>=<i>qTEXTb</i>0001<i>v</i>&times;<i>B</i>

# translate one particular equation to a bitmap; return the html code to display the bitmap
# if the type isn't inline, then we put div's around the equation(s)
def handle_math_one_bitmap(tex,math_type)
    m = tex.clone

    if m=~/\\(begin|end){array}/ then return nil end # can't handle these because they contain \\ inside

    curly = "(?:(?:{[^{}]*}|[^{}]*)*)" # match anything, as long as any curly braces in it are paired properly, and not nested
    m.gsub!(/\\indices{(#{curly})}/) {$1} # has to strip curly braces off, not just delete the macro
    # if you really try to do an align environment, it wants to make separate bitmaps for each column
    t = {'inline'=>'equation*', 'equation'=>'equation*' , 'align'=>'equation*', 'multline'=>'multline*' , 'gather'=>'gather*'}[math_type]    
    # stuff that's illegal in equation environment:
    m.gsub!(/\&/,'')
    m.gsub!(/\\intertext{([^}]+)}/) {" \\text{#{$1}} "} 
    result = ''
    m.split(/\\\\/).each { |e|
      original = e.clone
      e.gsub!(/\n/,' ') # empty lines upset tex
      if !(e=~/\A\s*\Z/) then
      eq_dir = html_subdir('math')
      eq_base = 'eq_' + hash_equation(e) + '.png'
      eq_file = eq_dir + '/' + eq_base
      if $redo_all_equations || ! File.exist?(eq_file) then
        temp = 'temp.tex'
        temp_png = 'temp.png'
        if e=~/<\/?i>/ then
          $stderr.print "huh? equation has <i> in it, getting ready to produce tex code\n#{original}\n"
        end
        unless $no_write then $stderr.print "Producing equation file #{eq_file} from latex code #{e}\n" end
        File.open(temp,'w') do |f|
        f.print <<-TEX
  	\\documentclass{book}[12pt]
	\\RequirePackage{lmmath,amssymb,cancel}
        \\RequirePackage[leqno]{amsmath}
        \\begin{document}
        \\begin{#{t}}
        #{e}
	\\end{#{t}}
        \\end{document}               
        TEX
        end # file
        doomed = ( e=~/{212/ )
        if doomed then
          $stderr.print "****************************This equation is marked as not working -- not doing it ***********************************\n"
        else
          if ! $no_write then
            if !File.exist?(temp) then $stderr.print "error, temp file #{temp} doesn't exist"; exit(-1) end
            unless system("#{$config['script_dir']}/equation_to_image.pl #{temp} #{$config['sty_dir']}/lmmath.sty >/dev/null") then $stderr.print "error, #{$?}"; exit(-1) end
            unless system("mv #{temp_png} #{eq_file}") then $stderr.print "WARNING, error #{$?}, probably tex4ht isn't installed\n" end
          end
        end
        end # if not null string
      end # end if file doesn't exist yet
      plain_equation = original
      plain_equation.gsub!(/[\n"]/,'')
      plain_equation.gsub!(/</,'&lt;')
      plain_equation.gsub!(/\\/,'') # If we don't do this, then the latex math inside the alt="" gets translated to html later, and it's not valid html
      curly = "(?:(?:{[^{}]*}|[^{}]*)*)" # match anything, as long as any curly braces in it are paired properly, and not nested
      plain_equation.gsub!(/\\label{#{curly}}/,'')
      # $stderr.print ".......................... #{plain_equation} ............................\n"
      if math_type=='inline' then
        result = result + "<img src=\"math/#{eq_base}\" alt=\"#{plain_equation}\"#{$self_closing_tag}>"
      else
        result = result + "#{begin_equation()}<img src=\"math/#{eq_base}\" alt=\"#{plain_equation}\"#{$self_closing_tag}>#{end_equation()}"
      end
    }
    return result
end

def begin_equation
  return '<div class="equation">'
end

def end_equation
  return '</div>'
end


def hash_equation(foo)
  tex = foo.clone
  # strip any leading or trailing dollar signs or spaces:
  tex.gsub!(/^[$ ]+/,'')
  tex.gsub!(/[$ ]+$/,'')
  return hash_function(tex)
end

def hash_function(x)
  h = Digest::MD5.new
  h << x
  return h.to_s[-8..-1] # to_s method gives the result in hex
end

# Take care of the math and tables, as well as other misc. junk, in an individual paragraph.
# Be careful not to return nested div's, because the code in parse_section can't handle that.
# Guaranteed not to make any <p> or <div> tags, and therefore safe to use for stuff like figure captions,
# provided the argument doesn't have any displayed math or tables inside it.
def parse_para(t)
  tex = t.clone

  # Do tables before handling math, because otherwise, e.g., \alpha becomes &alpha;, which looks like & in table.
  # When latex_table_to_html converts the table, it will convert the math inside it as well.
  # However, it may generate bitmaps for complex math, which I don't want it to do inside a table (script can't handle it).
  # Therefore, if a table comes back from tex4ht with bitmaps in it, handle_tables replaces each bitmap with its alt value.
  tex = handle_tables(tex)
  tex = handle_math(tex)
  tex = parse_eensy_weensy(tex) # has to be done after handling math (see, e.g., comment about ldots, but other reasons, too, I think)
  return tex
end

# Parse very simple low-level stuff. It's safe to call this routine for stuff like figure captions. Guaranteed not to make
# any <p> or <div> tags.
def parse_eensy_weensy(t)
  tex = t.clone

  curly = "(?:(?:{[^{}]*}|[^{}]*)*)" # match anything, as long as any curly braces in it are paired properly, and not nested
  curly_safe = "(?:[^{}]*)" # can't contain any curlies

  # macros we don't care about:
  tex.gsub!(/\\index{#{curly}}/,'') # This actually gets taken care of earlier by duplicated code. Probably not necessary to have it here as well.
  tex.gsub!(/\\noindent/,'') # Should pay attention to this, but it would be really hard.
  tex.gsub!(/\\write18{#{curly}}/,'')
  # kludge, needed in SN 10:
  tex.gsub!(/\\formatlikecaption{/,'') 
  tex.gsub!(/\\normalsize/,'') 
  tex.gsub!(/\\normalfont/,'') 

  # macros that we treat as identity operators:
  tex.gsub!(/\\(?:indices){(#{curly})}/) {$1}

  # macros that are easy to process:
  tex.gsub!(/\\(?:emph|optionalchapternote){(#{curly})}/) {"<i>#{$1}</i>"}
  tex.gsub!(/\\epigraph(?:long|longfitbyline)?{(#{curly})}{(#{curly})}/) {"#{$1} -- <i>#{$2}</i>"}
  tex.gsub!(/\\\//,' ')
  tex.gsub!(/\\\\/,$br)
  tex.gsub!(/PROTECT_DOUBLE_BACKSLASH_FOR_MATHJAX/,"\\\\")
  tex.gsub!(/\\xmark/,'&times;')
  tex.gsub!(/\\hwsoln/,'(solution in the pdf version of the book)')
  tex.gsub!(/\\hwendpart/,$br)
  tex.gsub!(/\\answercheck/,'(answer check available at lightandmatter.com)')
  tex.gsub!(/\\ldots/,'...') # won't mess up math, because this is called after we handle math
  if $mathjax then tex.gsub!(/\\(egquestion|eganswer)/,'\\(\\triangleright\\)') else tex.gsub!(/\\(egquestion|eganswer)/,'&loz;') end
  tex.gsub!(/\\notationitem{(#{curly_safe})}{(#{curly_safe})}/) {"#{$1} &mdash; #{$2}"} # endless loop in NP7 if I don't use curly_safe?? why??
  tex.gsub!(/\\vocabitem{(#{curly})}{(#{curly})}/) {"<i>#{$1}</i> &mdash; #{$2}"}
  tex.gsub!(/\\label{([^}]+)}/) {
    x=$1
    unless x=~/^splits:/ then # kludge to avoid malformed xhtml resulting from \label in a paragraph by itself
      "<a #{$anchor}=\"#{x}\"></a>"
    end
  }

  tex.gsub!(/\\url{(#{curly})}/) {"<a href=\"#{$1}\">#{$1}</a>"}

  # footnotes:
  tex.gsub!(/\\footnote{(#{curly})}/) {
    text=$1
    $footnote_ctr += 1
    n = $footnote_ctr
    label = "footnote" + n.to_s
    $footnote_stack.push([n,label,parse_para(text)])
    "<a href=\"\##{label}\"><sup>#{n}</sup></a>"
  }

  parse_references!(tex)

  # quotes:
  tex.gsub!(/\`\`/,'&ldquo;')
  tex.gsub!(/\'\'/,'&rdquo;')

  parse_itty_bitty_stuff!(tex)

  return tex
end

# Guaranteed not to make any <p> or <div> tags.
# Normally called by parse_eensy_weensy(), not called directly.
def parse_references!(tex)
  curly = "(?:(?:{[^{}]*}|[^{}]*)*)" # match anything, as long as any curly braces in it are paired properly, and not nested

  tex.gsub!(/\\subfigref{([^}]+)}{([^}]+)}/) {"\\ref{fig:#{$1}}/#{$2}"}
  tex.gsub!(/\\figref{([^}]+)}/) {"\\ref{fig:#{$1}}"}
  tex.gsub!(/\\ref{([^}]+)}/)     { # example: <a href="#sec:basicrel">7.1</a>
    this_ch=$ch.to_i # strip any leading zero, and make it an integer
    x=$1 # the TeX label, e.g., "sec:basicrel"
    r=$ref[x]
    if r!=nil then
      number=r[0] # e.g., 7.1 (section) or c (figure)
      # Bug: the following doesn't correctly handle references across chapters to a figure, only to a section, subsection, etc.
      url = "\##{x}"
      if x=~/(ch|sec):/ then # ch:, sec:, subsec:, ...
        if number =~ /\A(\d+)/ then
          that_ch = $1.to_i
        else
          that_ch = this_ch
        end
        if this_ch!=that_ch then # reference acrosss chapters
          # $stderr.print "reference #{x}, #{r}, #{number}\n"
          # $stderr.print "that_ch=#{that_ch}, this_ch=#{this_ch}\n"
          t = that_ch.to_s
          if that_ch<10 then t = '0'+t end
          url = "../ch#{t}/ch#{t}.html" + url
        end
      end
      y="<a href=\"#{url}\">#{number}</a>"
    else
      $stderr.print "warning, undefined reference #{x}\n"
      y=''
    end
    y 
  }
  tex.gsub!(/\\worked{([^}]+)}{(#{curly})}/)     {
    ref,title='hw:'+$1,$2
    r=$ref[ref]
    if r!=nil then
      #y="&loz; Solved problem: #{title} &mdash; <a href=\"\##{ref}\">page #{r[1]}, problem #{r[0]}</a>" ### hw refs aren't actually there
      y="&loz; Solved problem: #{title} &mdash; problem #{r[0]}"
    else
      $stderr.print "warning, undefined reference #{r}\n"
      y=''
    end
    y 
  }
  tex.gsub!(/\\pageref{([^}]+)}/) {
    x=$1
    r=$ref[x]
    if r!=nil then
      y=r[1].to_s
    else
      $stderr.print "warning, undefined reference #{x}\n"
      y=''
    end
    y 
  }
end

$read_topic_map = false
$topic_map = {}
def find_topic(ch,book,own)
  if book=='calc' then return own end

  # Topic maps are also used in scripts/BookData.pm.
  if !$read_topic_map then
    json_file = "../scripts/topic_map.json"
    json_data = ''
    File.open(json_file,'r') { |f| json_data = f.gets(nil) }
    if json_data == '' then $stderr.print "Error reading file #{json_file} in translate_to_html.rb"; exit(-1) end
    $topic_map = JSON.parse(json_data)
    $read_topic_map = true
  end

  ch_string = ch.to_i.to_s # e.g., convert '07' to '7'

  t1 = $topic_map['1']
  x = t1[book]
  if x==nil then return own end
  own.push("../share/#{x[ch_string]}/figs")

  # secondary places to look:
  t2 = $topic_map['2']
  x = t2[book]
  if x!=nil and x[ch_string]!=nil then own.push("../share/#{x[ch_string]}/figs") end
  return own
end


def die(name,message)
  $stderr.print "eruby_util: figure #{name}, #{message}\n"
  exit(-1)
end

# returns, e.g., 'n3/figs' or 'ch09/figs'
def own_figs
  if ENV['OWN_FIGS'].nil? then
    return "ch#{$ch}/figs"
  else
    return ENV['OWN_FIGS']
  end
end

def find_figure(name,width_type)
  # width_type = 'narrow' , 'wide' , 'fullpage' , 'raw'

  # Allow for kludges like fig('../../../lm/vw/figs/doppler',...), which I do in an E&M chapter of LM.
  if name=~/^\.\.\/\.\.\/\.\.\/lm/ then
    return name
  end

  name.gsub!(/(.*\/)/,'') # get rid of anything before the last slash; if it's shared, we'll figure that out ourselves

  if name=='zzzfake' then return nil end

  output_dir = "#{$config['html_dir']}/ch#{$ch}/figs"
  make_directory_if_nonexistent(output_dir,'find_figure')

  search = Dir["#{output_dir}/#{name}.*"]
  unless search.empty? then
    unique = search.shift # better be unique
    unique =~ /([^\/]+)$/
    return $1
  end
  
  debug = false # debug mechanism for finding where the figure is

  possible_dirs = find_topic($ch,$config['book'],[own_figs()])
  allowed_formats = ['jpg','png','pdf']
  found_in_dir = nil
  found_in_fmt = nil
  allowed_formats.each {|fmt|
    possible_dirs.each {|dir|
      if Dir["#{dir}/#{name}\.#{fmt}"].empty? then
        if debug then $stderr.print "debugging: didn't find #{name}.#{fmt} in #{dir}\n" end
      else
        if debug then $stderr.print "debugging: found #{name} in #{dir}\n" end
        found_in_dir = dir
        found_in_fmt = fmt
      end
    }
  }
  fmt = found_in_fmt
  dir = found_in_dir

  base = "#{dir}/#{name}."
  if dir==nil then
    $stderr.print "translate_to_html: error finding figure #{base}*, not found in any of these dirs: ",possible_dirs.join(','),", relative to cwd=#{Dir.getwd()}\n"
    exit(-1)
  else
    result = "#{dir}/#{name}.#{fmt}"
  end
  return '' if result==nil

  output_format = {'jpg'=>'jpg','png'=>'png','pdf'=>'png'}[fmt]
  if output_format==nil then $stderr.print "error in translate_to_html.rb, find_figure, output_format is nil, name=#{name}\n"; exit(-1) end
  if name==nil then $stderr.print "error in translate_to_html.rb, find_figure, name is nil\n"; exit(-1) end
  if $config['html_dir']==nil then $stderr.print "error in translate_to_html.rb, find_figure, $config['html_dir'] is nil\n"; exit(-1) end
  dest = $config['html_dir'] + '/' + "ch#{$ch}/figs/" + name + '.' + output_format
  unless File.exist?(dest) then
    # need to call ImageMagick even if input and output formats are the same, to convert to web resolution
    infile = base+fmt
    options = ''
    #if fmt=='jpg' or fmt=='png' then
    if true then
      `identify #{infile}`.split(/ /)[2]=~/(\d+)x(\d+)/ # ImageMagick
      width,height=$1.to_f,$2.to_f
       target_width = -1
      if width_type=='raw' then target_width = width end
      if width_type=='narrow' then target_width = ($margin_width/25.4)*72 end
      if width_type=='wide' or width_type=='fullpage' then target_width = $text_width_pixels end
      if target_width == -1 then
        target_width = 100
        $stderr.print "Warning, unrecognized width type #{width_type} for figure #{dest}\n"
      end
      scale = target_width/width
      width = (width*scale).to_i
      height = (height*scale).to_i
      options = options + " -resize #{width}x#{height}"
    end
    if fmt=='pdf' then
      # Can convert pdf directly to bitmap of the desired resolution using imagemagick, but it messes up on some files (e.g., huygens-1.pdf), so
      # go through pdftoppm first.
      pdftoppm_command = "pdftoppm -r 440 #{infile} z" # 4x the resolution we actually want
      do_system(pdftoppm_command) 
      ppm_file = 'z-000001.ppm' # only 1 page in pdf
      unless File.exist?(ppm_file) then ppm_file = 'z-1.ppm' end # different versions of pdftoppm use different naming conventions
      if File.exist?(ppm_file) then
        do_system("convert #{options} #{ppm_file} #{dest} && rm #{ppm_file}") # scale it back down
      else
        $stderr.print "Error converting figure #{dest}, no file z-000001.ppm or z-1.ppm created as output by pdftoppm; perhaps pdftoppm isn't installed?"
        $stderr.print "Command line was #{pdftoppm_command}\n"
      end
    else
      do_system("convert #{options} #{infile} #{dest}")
    end
  end
  return name+'.'+output_format
end

def do_system(cmd)
  $stderr.print "#{cmd}\n"
  system(cmd)
end

def alphalph(x)
  if x>26 then return alphalph(((x-1)/26).to_i) + alphalph((x-1)%26+1) end
  # kludge: in the following, 97 is the harcoded ascii code for 'a'
  return (97+x-1).chr
end

# returns an array consisting of text column and margin column blocks, [[t1,m1],[t2,m2],...]
def parse(t,level,current_section)
  tex = t.clone

  # The following is so that text right before or right after an enumerate or itemize will be in its own paragraph:
  tex.gsub!(/(\\end{(enumerate|itemize)})/) {$1+"\n"}
  tex.gsub!(/(\\begin{(enumerate|itemize)})/) {"\n"+$1}
  if level<=$config['restart_figs_at_level']+1 then $fig_ctr = 0 end
  #------------------------------------------------------------------------------------------------------------------------------------
  if level>$config['highest_section_level'] then return [ [parse_section(tex),''] ] end
  #------------------------------------------------------------------------------------------------------------------------------------
  marg_stuff = ''
  if level==$config['spew_figs_at_level'] then
    non_marg_stuff = ''
    tex.gsub!(/END_CAPTION\n*/,"END_CAPTION\n") # the newline is because without it, the code below will eat too much with each regex match
    # The following code assumes that each ZZZWEB thingie is on a separate line; if there aren't newlines between them, it eats too much and goes nuts.
    tex.gsub!(/ZZZWEB\:fig,([^,]+),(\w+),(\d),([^\n]*)END_CAPTION/) {
      name,width,anon,caption = $1,$2,$3.to_i,$4
      #if name=='zzzfake' then $stderr.print "zzzfake------------\n#{name}\n#{width}\n#{anon}\n#{caption}-------\n" end
      if anon==0 then $fig_ctr += 1 ; l=alphalph($fig_ctr).to_s+' / ' else l='' end
      if name=='zzzfake' then $fig_ctr += 1 end # kludge, I don't understand why this is needed, but it is, or else EM1 figures get out of step at the end
      whazzat = find_figure(name,width) # has the side-effect of copying or converting it if necessary
      if caption=~/\A\s*\Z/ then c='' else c="<p class=\"caption\">#{l}#{parse_para(caption)}</p>" end
      x = "<img src=\"figs/#{whazzat}\" alt=\"#{name}\"#{$self_closing_tag}><a #{$anchor}=\"fig:#{name}\"></a>"+c
      if is_calculus_book then x = "<p>"+x+"</p>" end
      if name=='zzzfake' then x=c end
      x
    }
    in_marg = false # even if it starts with a marg, split() gives us a null string for the first chunk()
    tex.split(/ZZZWEB\:(?:end\_)?marg/).each { |marg|
      if in_marg then
        marg_stuff = marg_stuff + marg 
      else
        non_marg_stuff = non_marg_stuff + marg
      end
      in_marg = !in_marg
    }
    tex = non_marg_stuff
    parse_marg_stuff!(marg_stuff)
    #if marg_stuff=~/261/ then $stderr.print "back from parse_marg_stuff!, **#{marg_stuff}**\n" end
  end
  #------------------------------------------------------------------------------------------------------------------------------------
  highest = $section_level_num.invert[level]
  result = []
  secnum = 0
  first_one = true # first one is a preamble or whatever; even if it starts with section, split() gives a null string for the first chunk
  tex.split(/\\(?:my)?#{highest}/).each { |section|
    if !first_one then
      curly = "(?:(?:{[^{}]*}|[^{}]*)*)" # match anything, as long as any curly braces in it are paired properly, and not nested
      section.gsub!(/\A(?:\[\d*\])?{(#{curly})}/) {
        title = $1
        label = current_section.join('.') + '.' + secnum.to_s
        s=label
        if level==1 and $chapter_title==nil then $chapter_title=title; s=$ch.to_i.to_s end
        if level>=$config['number_sections_at_depth'] then s='' end
        special = ''
        if title=~/^([\*\@\?]+)(.*)/ then special,title=$1,$2 end
        if special=~/\*/ then s='' end # * is a marker to say not to produce a section number
        if special=~/\@/ then title=title + ' (optional calculus-based section)' end
        if special=~/\?/ then title=title + ' (optional)' end
        if level==1 then  label=s ; s="Chapter #{s}." end # so people hitting the page realize it's one chapter of a book
        sec_type = ''
        if level==1 then sec_type="Chapter" end
        if level==2 then sec_type="Section" end
        if level==3 then sec_type="Subsection" end
        if level==4 then sec_type="Subsubsection" end
        ll = "#{sec_type}#{label}"
        parse_itty_bitty_stuff!(title)
        if level==2 and !(title=~/^Homework/) then $chapter_toc = $chapter_toc + "<a href=\"\##{ll}\">#{sec_type} #{label} - #{title}</a>#{$br}\n" end
        if $wiki then
          h_start = wiki_style_section(level)
          h_end   = wiki_style_section(level)
          s_name = ''
          s_num = ''
        else
          h_start = "<h#{level}>"
          h_end   = "</h#{level}>"
          s_name = "<a #{$anchor}=\"#{ll}\"></a>"
          s_num = s + ' '
        end
        "#{h_start}#{s_name}#{s_num}#{title}#{h_end}\n"
      }
    end
    first_one = false
    if level==1 then secnum=$ch.to_i end
    current_section.push(secnum)
    section.gsub!(/\\marg{(#{curly})}/) {"<p>#{$1}</p>"} # occurs in EM 5, opener
    if !(section=~/\A\s*\Z/) then
      result.concat(parse(section,level+1,current_section))
    end
    current_section.pop
    secnum += 1
  }
  #------------------------------------------------------------------------------------------------------------------------------------
  curly = "(?:(?:{[^{}]*}|[^{}]*)*)" # match anything, as long as any curly braces in it are paired properly, and not nested
  if level==$config['spew_figs_at_level'] then
    tex = ''
    result.each { |s|
      tex = tex + s[0] # guaranteed to have null for s[1] for level==$config['spew_figs_at_level']
    }
    return [ [tex,marg_stuff] ]
  else
    return result
  end
end

def newlines_to_spaces(s)
  x = s.clone
  x.gsub!(/\n/,' ')
  return x
end

#===============================================================================================================================
#===============================================================================================================================
#===============================================================================================================================
#                                                main
#===============================================================================================================================
#===============================================================================================================================
#===============================================================================================================================




# Code similar to this is duplicated in eruby_util.rb.
refs_file = 'save.ref'
unless File.exist?(refs_file) then
  $stderr.print "File #{refs_file} doesn't exist. Do a 'make book' to create it."
  exit(-1)
end
File.open(refs_file,'r') do |f|
  # lines look like this:
  #    fig:entropygraphb,h,255
  t = f.gets(nil) # nil means read whole file
  t.scan(/(.*),(.*),(.*)/) { |label,number,page|
    $ref[label] = [number,page.to_i]
  }
end




if $test_mode then
  $stderr.print "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< test mode >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n"
end

$ch = ENV['CHAPTER']
$want_chapter_toc = !($config['book']=='1np' and $ch=='00') && !$wiki

tex = $stdin.gets(nil) # nil means read whole file

# Convert summary and hwsection environments into sections, which is what they really are, anyway.
['summary','hwsection'].each { |s|
  a = {'summary'=>'Summary','hwsection'=>'Homework Problems'}[s]
  begin
    tex.gsub!(/\\begin{#{s}}((.|\n)*)\\end{#{s}}/) {"\\mysection{*#{a}}#{$1}"} # The * warns later code not to produce a section number in the header.
  rescue ArgumentError
    $stderr.print "Illegal character in input. This typically happens with things like octal 322 for curly quotes. Can troubleshoot by running it through clean_up_text and then doing a diff.\n"
    raise
  end
}


tex.gsub!(/mysubsectionnotoc/) {"mysubsection"}
tex.gsub!(/(myoptionalsection)(\[\d\])?{/) {"mysection{?"} # ? marks it as optional
tex.gsub!(/(myoptionalcalcsection)(\[\d\])?{/) {"mysection{@"} # @ marks it as calc-based, optional
tex.gsub!(/(mycalcsection)(\[\d\])?{/) {"mysection{@"} # @ marks it as calc-based, optional

curly = "(?:(?:{[^{}]*}|[^{}]*)*)" # match anything, as long as any curly braces in it are paired properly, and not nested

# remove comments and indexing (indexing is evil when it occurs inside sectioning, messes everything up)
# First, preserve percent signs inside listing and verbatim environments:
r = {}
s = {}
envs = ['listing','verbatim']
envs.each { |x|
  pat = x
  s[x] = "\\\\(?:begin|end){#{pat}}"
  z = s[x].clone  # workaround for bug in the ruby interpreter, which causes the first 8 bytes of the regex string to be overwritten with garbage
  r[x] = Regexp.new(z)
}  
envs.each { |x|
  result = ''
  inside = false # even if the environment starts at the beginning of the string, split() gives us a null string as our first string
  tex.split(r[x]).each { |d|
    if !(d=~/\A\s*\Z/) then
      if inside then
        d.gsub!(/%/,'KEEP_PERCENT')
        d = "\\begin{#{x}}" + d + "\\end{#{x}}"
      end
      result = result + d
    end
    inside = !inside
  } # end loop over d
  tex = result
} # end loop over x
# Now, finally, get rid of comments:
tex.gsub!(/\\index{#{curly}}/,'')
tex.gsub!(/(?<!\\)%[^\n]*(\n?[ \t]*)?/,'')

# remove whitespace from lines consisting of nothing but whitespace

tex.gsub!(/^[ \t]+$/,'')

# kludge, fix:
tex.gsub!(/myoptionalsection/,'mysection')

# minipages inside figures aren't necessary in html, and confuse the parser
tex.gsub!(/\\begin{minipage}\[[a-z]\]{\d+[a-z]*}/,'')
tex.gsub!(/\\end{minipage}/,'')
# ... and, e.g., make it do something sensible with non-graphical figures, as in EM 1
tex.gsub!(/\\docaption{(#{curly})}/) {"ZZZWEB:fig,zzzfake,narrow,1,#{newlines_to_spaces($1)}END_CAPTION"} # name,width,anon,caption

# split into sections for easier handling

result = ''
parse(tex,1,[]).each {|s|
  t,m = s[0],s[1]
  m = '<div class="margin">' + parse_para(m) + '</div>'  unless m=~/\A\s*\Z/
  # FIXME: The following is meant to get the divs *after* the <h2> for a section, so that the css "clear" mechanism works properly.
  # This should really be handled by making parse return an array of triplets, (h,t,m), rather than (t,m).
  h = ''
  1.upto(2) { |i|
    if t =~ /^(\s*<h#{i}>(?:<a #{$anchor}=[^>]+><\/a>)?(?:[^<>]+)<\/h#{i}>)((.|\n)*)/ then
      h,t=$1,$2
    end
  }
  result = result + h + m + t # m has to come first, because that causes it to be positioned as close as possible to the top of the section
}
tex = result

tex.gsub!(/ {2,}/,' ') # multiple spaces
tex.gsub!(/<p>\s*<\/p>/,'') # peepholer to get rid of <p></p> pairs
tex.gsub!(/\n{3,}/,"\n\n") # 3 or more newlines in a row
tex.gsub!(/\\&/,"&amp;")
tex.gsub!(/&(?![a-zA-Z0-9#]+;)/,"&amp;")
tex.gsub!(/<\/h1>\n*<\/p>/,"</h1>") # happens in NP, which has part I, II, ...; see above in handling for mypart
tex.gsub!(/<td>([^<>]+)<\/t>/) {"<td>#{$1}<\/td>"}; # bug in htlatex?
tex.gsub!(/KEEP_INDENTATION_(\d+)_SPACES/) {replicate_string(' ',$1.to_i)}

if $wiki then
  tex.gsub!(/PROTECT_TEX_MATH_FOR_MEDIAWIKI(.*)ZZZ/) {$protect_tex_math_for_mediawiki[$1]}
  $tex_math_not_in_mediawiki.each { |k,v|
    tex.gsub!(/\\#{k}/) {v}
  }
end

if $modern && !$html5 && !$wiki then
  print <<STUFF
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1 plus MathML 2.0//EN" "http://www.w3.org/Math/DTD/mathml2/xhtml-math11-f.dtd" >
<html xmlns="http://www.w3.org/1999/xhtml">
STUFF
  mime = 'application/xhtml+xml'
end

if $html5 then
  print <<STUFF
<!doctype html>
<html>
STUFF
  mime = 'text/html'
end

if !$modern && !$wiki then
print <<STUFF
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
STUFF
  mime = 'text/html'
end

if $test_mode then
  stylesheet = 'file:///home/bcrowell/Lightandmatter/lm.css'
else
  stylesheet = 'http://www.lightandmatter.com/lm.css'
end

mathjax_in_head = ''
if $mathjax then
  mathjax_in_head = '<script type="text/javascript" src="http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML"></script>'
end

if !$wiki then
print <<STUFF
  <head>
    <title>#{$chapter_title}</title>
    <link rel="stylesheet" type="text/css" href="http://www.lightandmatter.com/banner.css" media="all"#{$self_closing_tag}>
    <link rel="stylesheet" type="text/css" href="#{stylesheet}" media="all"#{$self_closing_tag}>
    <meta http-equiv="Content-Type" content="#{mime}; charset=utf-8"#{$self_closing_tag}>
    #{mathjax_in_head}
  </head>
  <body>
STUFF

# duplicated in run_eruby.pl, ****************** but with a different number of ../'s before banner.jpg ******************************
print <<BANNER
  <div class="banner">
    <div class="banner_contents">
        <div class="banner_logo" id="logo_div"><img src="http://www.lightandmatter.com/logo.png" alt="Light and Matter logo" id="logo_img"#{$self_closing_tag}></div>
        <div class="banner_text">
          <ul>
            <li> <a href="../../../">home</a> </li>
            <li> <a href="../../../books.html">books</a> </li>
            <li> <a href="../../../software.html">software</a> </li>
            <li> <a href="../../../courses.html">courses</a> </li>
            <li> <a href="../../../area4author.html">contact</a> </li>

          </ul>
        </div>
    </div>
  </div>
BANNER

print "<table style=\"width:#{$ad_width_pixels}px;\"><tr><td>" + $disclaimer_html + "</td></tr></table>\n"
  # ... people are probably more likely to read ad if it looks same width as this block of text, looks like part of page
end

if $wiki then
  print <<HEAD
{{Chapter_header|book_title=#{$config['title']}|ch=#{$ch.to_i}|title=#{$chapter_title}}}
HEAD
end # if wiki

if $test_mode then
  $stderr.print "***************** not putting an ad in #{$config['book']}, ch. #{$ch}, for testing purposes\n"
else
  print $google_ad_html + "\n"
end

if $want_chapter_toc then print $chapter_toc + "</div>" end

tex.gsub!(/\\\$/,'$') # Do this here to avoid confusion with $...$ for math.

if $wiki then
  ['p','a','div'].each { |x|
    tex.gsub!(/<#{x}(\s+[^>]*)?>/,'')
    tex.gsub!(/<\/#{x}>/,'')
  }
  #tex.gsub!(/<img src="(figs|math)\/([^"]*)"([^>]*)>/) {"[http://www.lightandmatter.com/html_books/#{$config['book']}/ch#{$ch}/#{$1}/#{$2} figure #{$2} needs to be imported]"}
  tex.gsub!(/<img src="(figs|math)\/([^"]*)"([^>]*)>/) {"{{Missing_fig|book=#{$config['book']}|ch=#{$ch}|file=#{$2}}} - "}
  tex.gsub!(/(\n+)\s+/) {$1}
  tex.gsub!(/<br>\n?{2,}\s+/,"<br>\n")
end

if !$wiki then print "<div class=\"container\">\n" end
print tex
if !$wiki then print "</div>\n" end

macros_not_handled = {}
# Look for macros that weren't handled.
# We do get raw tex in alt tags and html comments, and that's ok.
chipmunk = tex.clone
chipmunk.gsub!(/alt=\"[^"]*\"/,'')
chipmunk.gsub!(/\<\!\-\-([^\-]|(\-(?!\-)))*\-\-\>/,'') # not really generally correct, but works for the comments I generate that might have html inside
math_macros = $tex_math_trivial.clone
math_macros = math_macros.concat($tex_math_nontrivial.keys)
math_macros = math_macros.concat($tex_math_trivial_not_entities)
math_macros = math_macros.concat(['text','frac','shoveright','sqrt','left','right','mathbf','ensuremath','hat','mathbf','mathrm','triangleright'])
chipmunk.scan(/(\\\w+({[^}]*})?)/) {
  whole = $1 # e.g.,  \frac{ke^2}
  macro = whole
  if whole=~/^\\([a-zA-Z]+)/ then macro=$1 end
  math_ok = false
  if $mathjax then
    math_macros.each { |m| if m==macro then math_ok=true end }
    if macro=='begin' || macro=='end' then
      ['align','equation','multline','gather'].each { |e| if whole=~/^\\(begin|end){#{e}\*?}/ then math_ok=true end}
    end
  end
  if !math_ok then macros_not_handled[whole]=1 end
}
#tex.split(/alt=\"[^"]*\"/).each { |x|
#  curly = "(?:(?:{[^{}]*}|[^{}]*)*)" # match anything, as long as any curly braces in it are paired properly, and not nested
#  x.scan(/(\\\w+({[^}]*})?)/) {macros_not_handled[$1]=1}
#}
unless macros_not_handled.keys.empty? then $stderr.print "Warning: the following macros were not handled in this chapter: "+macros_not_handled.keys.join(' ')+"\n" end

if $footnote_ctr>0 then
  print <<-FOOTNOTES
    <h5>Footnotes</h5>
  FOOTNOTES
  $footnote_stack.each {|f|
    n = f[0]
    label = f[1]
    text = f[2]
    print "<div><a #{$anchor}=\"#{label}\"></a>[#{n}] #{text}</div>\n"
  }
end

if !$wiki then print "</body></html>\n" end

#---------
#   Note:
#     The index is always html, even if we're generating xhtml.
#     Also, translate_to_html.rb generates links to chapter files named .html, not .xhtml,
#     even when we're generating xhtml output. This is because mod_rewrite is intended to
#     redirect users to the .xhtml only if they can handle it.
#   In the following, we don't write the index.html file if we're doing wiki output, for two
#   reasons: (1) it's not necessary, and (2) there's a bug that causes the TOC to get output multiple
#   times if we're doing wiki output.
#---------
if ! $wiki && ! $no_write then
File.open("#{$config['html_dir']}/index.html",'a') do |f|
  kludge = $ch
  and_more_kludge = $chapter_title
  oh_my_god_another_kludge = $ch.to_i.to_s + '.'
  if $ch=='00' && $config['book']=='1np' then
    if tex=~/We Americans/ then
      kludge = '001'
      and_more_kludge = 'Preface'
      oh_my_god_another_kludge = ''
    else
      kludge = '002'
      and_more_kludge = 'Introduction and Review'
      oh_my_god_another_kludge = '0'
    end
  end
  f.print "<p><a href=\"ch#{$ch}/ch#{kludge}.html\">#{oh_my_god_another_kludge} #{and_more_kludge}</a></p>\n"
  # ------->!!!! Link to .html, even if we're generating a file that will be called .xhtml. Mod_rewrite will redirect them if it's appropriate.
end
end
