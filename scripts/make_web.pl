#!/usr/bin/perl

use strict;
use XML::Parser;

my $wopt = '';
if (exists $ENV{WOPT}) {$wopt = $ENV{WOPT}}
my $no_write = 0;
if ($wopt=~/\-\-no_write/) {$no_write=1}
my $mathjax = 0;
if ($wopt=~/\-\-mathjax/) {$mathjax=1}
my $wiki = 0;
if ($wopt=~/\-\-wiki/) {$wiki=1}
my $xhtml = 0;
if ($wopt=~/\-\-modern/) {$xhtml=1}
my $html5 = 0;
if ($wopt=~/\-\-html5/) {$html5=1}

print "make_web.pl, no_write=$no_write, wiki=$wiki, xhtml=$xhtml\n";

my $html_dir = "/home/bcrowell/Generated/html_books/calc";
if (exists $ENV{HTML_DIR}) {$html_dir = $ENV{HTML_DIR}}

# For handheld versions, there are no server rewrites, so filenames should all be .html.
my $handheld = 0;
if (exists $ENV{HANDHELD}) {$handheld = $ENV{HANDHELD}}

# duplicated in translate_to_html.rb, but different number of ../'s
my $banner_html = <<BANNER;
  <div class="banner">
    <div class="banner_contents">
        <div class="banner_logo" id="logo_div"><img src="http://www.lightandmatter.com/logo.png" alt="Light and Matter logo" id="logo_img"></div>
        <div class="banner_text">
          <ul>
            <li> <a href="../../">home</a> </li>
            <li> <a href="../../books.html">books</a> </li>
            <li> <a href="../../software.html">software</a> </li>
            <li> <a href="../../courses.html">courses</a> </li>
            <li> <a href="../../area4author.html">contact</a> </li>

          </ul>
        </div>
    </div>
  </div>
BANNER
#---------
#   Note:
#     The index is always html, even if we're generating xhtml.
#     Also, translate_to_html.rb generates links to chapter files named .html, not .xhtml,
#     even when we're generating xhtml output. This is because mod_rewrite is intended to
#     redirect users to the .xhtml only if they can handle it.
#---------
my $index = $html_dir . '/index.html';
if (!$no_write && !$wiki) {
  open(FILE,">$index") or die "error opening $index for output; perhaps you need to create the book's main directory?";
  print FILE "<html><head><title>html version of book</title>    <link rel=\"stylesheet\" type=\"text/css\" href=\"http://www.lightandmatter.com/banner.css\" media=\"all\"></head><body>\n";
  print FILE $banner_html;
  close FILE;
}


foreach my $tex(<ch*/ch*temp.temp>) {
  if ($tex =~ /^ch(\d\d)/) {
    my $ch = $1;
    my $dir = "$html_dir/ch$ch";
    if (!-d $dir) {
      my $cmd = "mkdir -p $dir"; 
      print STDERR "make_web.pl is creating directory $dir\n";
      system($cmd);
    }
    my $html = "$dir/ch$ch";
    my $ext;
    if ($xhtml) {
      $ext = '.xhtml';
    }
    else {  
      if ($wiki) {
        $ext = '.wiki';
      }
      else {
        if ($html5) {
          $ext = '.html5';
        }
        else {
          $ext = '.html';
        }  
      }
    }
    if ($handheld) {$ext = '.html'}
    $html = $html . $ext;
    my $c = "CHAPTER='$ch' OWN_FIGS='ch$ch/figs' scripts/translate_to_html.rb $wopt <$tex >$html";
    print "$c\n";
    system($c);
    if ($xhtml) {
      local $/; open(F,"<$html"); my $x=<F>; close F;
      eval {XML::Parser->new->parse($x)};  
      if ($@) {   
        print "fatal error ===============> file $html output by /translate_to_html.rb is not well formed xml\n";
        XML::Parser->new->parse($x); # will print error message
        die;
      }
      else {
        if ($no_write) {unlink($html)} # delete temporary file
      }
    }

  }
  else {
    die "make_web.pl is upset, why doesn't $tex have chapter number?";
  }
}

open(FILE,">>$index") or die "error opening $index";
print FILE "</body></html>\n";
close FILE;
