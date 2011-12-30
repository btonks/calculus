#!/usr/bin/perl

use strict;

# Takes the .tex file for each chapter and converts it into the form that
# translate_to_html.rb wants.
# Reads ch*/ch*.tex, writes ch*/ch*temp.temp

local $/; # slurp whole file

foreach my $in(<ch*/ch*.tex>) {
  my $out = $in;
  $out =~ s/\.tex/temp.temp/;
  print "$in -> $out\n";

  open(F,"<$in");
  my $t = <F>;
  close F;

  my $curly = "(?:(?:{[^{}]*}|[^{}]*)*)"; # match anything, as long as any curly braces in it are paired properly, and not nested

  $t =~ s/\\chapter/\\mychapter/g;
  $t =~ s/\\section/\\mysection/g;
  $t =~ s/\\subsection/\\mysubsection/g;
  $t =~ s/\\subsubsection/\\mysubsubsection/g;
  $t =~ s/\\(fig|smallfig|widefig)(\[(\w)\])?{($curly)}{($curly)}/"\n\nZZZWEB:fig,$4,".{"fig"=>"narrow","smallfig"=>"narrow","widefig"=>"wide"}->{$1}.",0,".one_line($5)." END_CAPTION\n\n"/ge;

  $t =~ s/\\newcommand.*//g;
  foreach my $treat_as_identity_function("quoted") {
    $t =~ s/\\$treat_as_identity_function\{($curly)}/$1/g;
  }

  # convert from:
  # \begin{hw}[2]\label{hw:holditch}
  # \begin{hwwithsoln}{integrate-sin-cancel}
  # \begin{hwwithsoln}[2]{sum-of-iterated-sine}
  # to:
  # \begin{homework}{tossup}{1}{} ... name, dificulty, calc-based

  $t =~ s/\\begin{hwwithsoln}(\[(\d)\])?{([^}]+)}/\\begin{homework}{$3}{$2 ? $2 : 1}{}/g;
  $t =~ s/\\begin{hw}(\[(\d)\])?(\\label{hw:([^}]+)})?/"\\begin{homework}{$4}{".($2  ? $2 : 1)."}{}"/eg;
  $t =~ s/\\end{hw}/\\end{homework}/g;
  $t =~ s/\\end{hwwithsoln}/\\hwsoln\\end{homework}/g;

  $t =~ s/\\begin{eg}/\\begin{eg}{ZZZ_NO_EG_TITLE}/g; # Calc's form has no args, but LM's form has 1 mandatory arg

  # convert from:
  # \startcodeeg \begin{Code} ... \end{Code}
  $t =~ s/\\(startcodeeg|finishcodeeg|restartLineNumbers)//g;
  $t =~ s/\\begin{Code}/\\begin{listing}/g;
  $t =~ s/\\end{Code}/\\end{listing}/g;
  $t =~ s/\s*\\cc{(.*)}/" ".no_less_thans($1)."<br\/>"/ge;
  $t =~ s/\s*\\cc(.*)/" ".no_less_thans($1)."<br\/>"/ge;
  $t =~ s/\\ii{(.*)}(.*)/"".no_less_thans($1)." ".no_less_thans($2)."<br\/>"/ge; # $2 if for possible \cc line that got joined on
  $t =~ s/\\ii(.*)/"".no_less_thans($1)."<br\/>"/ge;
  $t =~ s/\\oo{(.*)(.*)}/"<i>".no_less_thans($1)." ".no_less_thans($2)."<\/i><br\/>"/ge;
  $t =~ s/\\oo(.*)/"<i>".no_less_thans($1)."<\/i><br\/>"/ge;

  open(F,">$out");
  print F $t;
  close F;

}

sub one_line {
  my $x = shift;
  $x =~ s/\n/ /g;
  return $x;
}

sub no_less_thans {
  my $x = shift;
  $x =~ s/</&lt;/g;
  return $x;
}
