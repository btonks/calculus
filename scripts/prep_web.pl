#!/usr/bin/perl

use strict;

# Takes the .tex file for each chapter and converts it into the form that
# translate_to_html.rb wants.


local $/; # slurp whole file

foreach my $in(<ch*/ch*.tex>) {
  my $out = $in;
  $out =~ s/\.tex/temp.temp/;
  print "$in -> $out\n";

  open(F,"<$in");
  my $t = <F>;
  close F;

  $t =~ s/\\chapter/\\mychapter/g;
  $t =~ s/\\section/\\mysection/g;
  $t =~ s/\\subsection/\\mysubsection/g;
  $t =~ s/\\subsubsection/\\mysubsubsection/g;
  my $curly = "(?:(?:{[^{}]*}|[^{}]*)*)"; # match anything, as long as any curly braces in it are paired properly, and not nested
  $t =~ s/\\(fig|smallfig|widefig)(\[(\w)\])?{($curly)}{($curly)}/"\n\nZZZWEB:fig,$4,".{"fig"=>"narrow","smallfig"=>"narrow","widefig"=>"wide"}->{$1}.",0,".one_line($5)." END_CAPTION\n\n"/ge;

  # convert from:
  # \begin{hw}[2]\label{hw:holditch}
  # \begin{hwwithsoln}{integrate-sin-cancel}
  # to:
  # \begin{homework}{tossup}{1}{} ... name, dificulty, calc-based

  $t =~ s/\\begin{hwwithsoln}{([^}]+)}/\\begin{homework}{$1}{1}{}/g;
  $t =~ s/\\begin{hw}(\[(\d)\])?(\\label{hw:([^}]+)})?/"\\begin{homework}{$4}{".($2  ? $2 : 1)."}{}"/eg;
  $t =~ s/\\end{hw}/\\end{homework}/g;
  $t =~ s/\\end{hwwithsoln}/\\hwsoln\\end{homework}/g;

  # convert from:
  # \startcodeeg \begin{Code} ... \end{Code}
  $t =~ s/\\(startcodeeg|finishcodeeg|restartLineNumbers)//g;
  if (0) {
  $t =~ s/\\begin{Code}/\\begin{listing}{1}/g;
  $t =~ s/\\end{Code}/\\end{listing}/g;
  $t =~ s/\\ii(.*)/<i>$1<\/i>/g;
  $t =~ s/\\oo(.*)/$1/g;
  }
  $t =~ s/\\begin{Code}/<tt>/g;
  $t =~ s/\\end{Code}/<\/tt>/g;
  $t =~ s/\s*\\cc{(.*)}/ $1<br\/>/g;
  $t =~ s/\s*\\cc(.*)/ $1<br\/>/g;
  $t =~ s/\\ii{(.*)}(.*)/$1 $2<br\/>/g; # $2 if for possible \cc line that got joined on
  $t =~ s/\\ii(.*)/$1<br\/>/g;
  $t =~ s/\\oo{(.*)(.*)}/<i>$1 $2<\/i><br\/>/g;
  $t =~ s/\\oo(.*)/<i>$1<\/i><br\/>/g;

  open(F,">$out");
  print F $t;
  close F;

}

sub one_line {
  my $x = shift;
  $x =~ s/\n/ /g;
  return $x;
}
