#!/usr/bin/perl

use strict;
use XML::Parser;
use JSON;

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

my $config = from_json(get_input("temp.config")); # hash ref
my $forbid_mathml = ();

print "make_web.pl, no_write=$no_write, wiki=$wiki, xhtml=$xhtml\n";

my $html_dir = $config->{'html_dir'};
my $standalone = $config->{'standalone'}; # For handheld versions, there are no server rewrites, so filenames should all be .html.

# print STDERR "in make_web.pl, standalone=$standalone=\n";

# duplicated in translate_to_html.rb, but different number of ../'s
my $banner_html = '';
if ($standalone==0) {
$banner_html = <<BANNER;
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
}
else {
$banner_html = <<BANNER;
<p><b>Calculus</b></p>
<p><b>Benjamin Crowell</b></p>
<p>This book's web page is <a href="http://www.lightandmatter.com/calc/">lightandmatter.com/calc</a>. This is my attempt to make a version of the
book for handheld e-book readers, despite what is, as of 2011, their poor support for math.</p>
BANNER
}
#---------
#   Note:
#     The index is normally html, even if we're generating xhtml. (Index is xhtml for handheld formats.)
#     Also, translate_to_html.rb generates links to chapter files named .html, not .xhtml,
#     even when we're generating xhtml output. This is because mod_rewrite is intended to
#     redirect users to the .xhtml only if they can handle it.
#---------
my $index = $html_dir . '/index.html';
if (!$no_write && !$wiki) {
  open(FILE,">$index") or die "error opening $index for output; perhaps you need to create the book's main directory?";
  if ($standalone==0) {
    print FILE "<html><head><title>html version of $config->{'title'}</title>    <link rel=\"stylesheet\" type=\"text/css\" href=\"http://www.lightandmatter.com/banner.css\" media=\"all\"></head><body>\n";
  }
  else {
    print FILE <<STUFF;
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>$config->{'title'}</title>
    <link rel="stylesheet" type="text/css" href="standalone.css" media="all"/>
    <meta http-equiv="Content-Type" content="application/xhtml+xml; charset=utf-8"/>
  </head>
  <body>
STUFF
  }
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
    if ($standalone==1) {$ext = '.html'}
    if (($config->{'html_file_extension'})=~/\w/) { $ext=$config->{'html_file_extension'} }
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
if ($standalone==1) {
  print FILE `scripts/translate_to_html.rb --util="ebook_title_footer"`;
}
print FILE "</body></html>\n";
close FILE;

sub get_input {
  my $file = shift;
  local $/;
  die "make_web.pl: file $file doesn't exist" unless -e $file;
  open(FILE,"<$file") or die "error $! opening $file for input";
  my $input = <FILE>;
  close FILE;
  return $input;
}
