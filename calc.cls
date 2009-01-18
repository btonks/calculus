\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{calc}

\LoadClass[9pt]{book}

\RequirePackage{mytocloft,titlesec,titletoc,multicol,makeidx,wrapfig,fancyhdr,calc,amssymb,fancyvrb,ifthen,lmmath,framed,alphalph,cancel,url}
\RequirePackage[pdftex]{color}%see pdftex mailing list, 2004 May 22-23
\renewcommand{\sfdefault}{phv}
\RequirePackage[EULERGREEK]{sansmath}
\RequirePackage[leqno]{amsmath}

\newcommand{\lmserifmath}{\mathversion{normal}\everymath{}\everydisplay{}}

\newcommand{\st}{\text{st}}

% ========================== low-level stuff =========================================
\newcommand{\zerosizebox}[3]{
  \makebox[0mm][l]{%
    \hspace{#1}%
    \raisebox{0mm}[0mm][0mm]{% used to have #2 as 1st arg, but it went the wrong direction!
      \makebox[0mm][l]{%
		\begin{minipage}{8.5in}
			\vspace{#2}#3
		\end{minipage}%
      }%
    }%
  }%
}%
\newcommand{\anonymousinlinefig}[1]{\includegraphics{\chapdir/figs/#1}}
% ========================== lengths =========================================

%----------- page layout ----------------
\setlength{\marginparwidth}{0mm}
\setlength{\textwidth}{4.3in}
\setlength{\textheight}{7.0in}
\setlength{\pdfpagewidth}{6in}
\setlength{\pdfpageheight}{9in}
\setlength{\hoffset}{-.25in}
\setlength{\voffset}{-.3in}
\setlength{\topmargin}{0in}
\setlength{\oddsidemargin}{.25in}
\setlength{\evensidemargin}{0mm}

%---------- my custom stuff for figures ------------
\newlength{\figwidth}
\setlength{\figwidth}{53mm}
\newlength{\smallfigwidth}
\setlength{\smallfigwidth}{35mm}

%---------- floats --------------------
\newlength{\defaultfloatsep}
\setlength{\defaultfloatsep}{10 pt plus 1 pt}
\setlength{\floatsep}{\defaultfloatsep}
\setlength{\textfloatsep}{\defaultfloatsep}
\setlength{\intextsep}{\defaultfloatsep}

%------------ equation spacing ---------------------
\newcommand{\myeqnspacing}{
        \setlength{\abovedisplayskip}{4mm plus 1mm minus 3mm}
        \setlength{\belowdisplayskip}{4mm plus 1mm minus 3mm}
        \setlength{\abovedisplayshortskip}{0mm plus 1mm}
        \setlength{\belowdisplayshortskip}{2mm plus 1mm minus 1mm}
}
\myeqnspacing

%------------ misc---------------------
\setlength{\parindent}{0mm}
\setlength{\parskip}{2mm plus 1mm}
\newlength{\myfooterspace}
\setlength{\myfooterspace}{5mm}

%============================= homework ==================================================
\newcommand{\thompson}{\hwaddtrailingstuff{\footnotesize{[Thompson, 1919]}}}
\newcommand{\granville}{\hwaddtrailingstuff{\footnotesize{[Granville, 1911]}}}
\newcounter{hwctr}[chapter]
\newenvironment{hwsection}{
    \setcounter{secnumdepth}{0}          % Don't number this section.
    \renewcommand{\printthesection}{}    % Footers should read ``Problems,'' not ``Section X.Y Problems''
    \hwcaptions                          % figures in hw section don't have a, b, c, labels
    \setcounter{figure}{0}               %
    \hfill\clearpage                     %
    \section{Problems}                   %
    \setcounter{secnumdepth}{2}          % Start numbering sections again.
                                         % The \setcounter{secnumdepth} stuff is the way the author of titlesec suggests doing
                                         % this. Using section* messes up footers & toc. 
    %\hwtopboilerplate\par
}%
{%
  \vfill\normalcaptions
}
\newcommand{\hwdifficulty}{0}
% ... This needs to be a global variable because I only display the symbol in  \end{hw},
%     which doesn't have access to #1.
\newsavebox{\hwtrailingstuff}
\newcommand{\currenthwlabel}{}
\newenvironment{hw}[1][1]
	{\refstepcounter{hwctr}\noindent\textbf{\thehwctr}%
	\renewcommand{\hwdifficulty}{#1}%
	\quad}
	{%
             \hwaddtrailingstuff{%
                                \displayhwdifficulty{\hwdifficulty}
                            }%
             \hwflushtrailingstuff
        }
\newenvironment{hwwithsoln}[2][1]
	{\refstepcounter{hwctr}\noindent\textbf{\thehwctr}\label{hw:#2}%
	\renewcommand{\hwdifficulty}{#1}%
	\quad
        \hwsoln{soln:#2}
        }
	{%
             \hwaddtrailingstuff{%
                                \displayhwdifficulty{\hwdifficulty}
                            }%
             \hwflushtrailingstuff
        }
\newcommand{\hwhint}[1]{\hwaddtrailingstuff{\hwtriangle\ Hint, p. \pageref{#1}}}
\newcommand{\hwans}[1]{\hwaddtrailingstuff{\hwtriangle\ Answer, p. \pageref{#1}}}
\newcommand{\hwsoln}[1]{\hwaddtrailingstuff{\hwtriangle\ \footnotesize{Solution, p. \pageref{#1}}}}
\newcommand{\answercheck}{\hwaddtrailingstuff{\hwcheckmark}}
%
\newcommand{\hwtriangle}{$\triangleright$}
\newcommand{\hwcheckmark}{\scriptsize\raisebox{1mm}{$\surd$}\normalsize}
%
\newcommand{\hwflushtrailingstuff}[1][3]{\ifthenelse{\boolean{hwhavetrailing}}{\hwfill{#1}\usebox{\hwtrailingstuff}\hwcleartrailingstuff}{}}
%
\newcommand{\hwcleartrailingstuff}{\sbox{\hwtrailingstuff}{}\setboolean{hwhavetrailing}{false}}
%
\newcommand{\hwaddtrailingstuff}[1]{\sbox{\hwtrailingstuff}{\usebox{\hwtrailingstuff}\quad{}#1}%
                                             \setboolean{hwhavetrailing}{true}}
%
\newcommand{\hwfill}[1]{\hspace*{\fill}\nolinebreak[#1]\nopagebreak[1]\hspace*{\fill}}
\newcommand{\displayhwdifficulty}[1]{\ifthenelse{\equal{#1}{2}}{$\star$}{}}
%============================= indented blocks ==================================================
\definecolor{shadecolor}{gray}{.9} % for framed.sty
\newlength{\saveleftskip}
\newenvironment{indentedblock}%
	{%
          \setlength{\saveleftskip}{\leftskip}%
          \addtolength{\leftskip}{7mm}%
          \noindent\hspace{-1.5mm}% kludge !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        }{%
          \par  \setlength{\leftskip}{\saveleftskip} \par%
	}
\newenvironment{important}[1][]%
	{\begin{shaded}\ifthenelse{\equal{#1}{}}{}{\textit{#1}\\*}}%
	{\end{shaded}}
\newenvironment{lessimportant}[1][]%
	{%
          \setlength{\saveleftskip}{\leftskip}%
          \addtolength{\leftskip}{10mm}%
          \noindent\ifthenelse{\equal{#1}{}}{}{\textbf{#1}\\*}%
        }{%
          \par  \setlength{\leftskip}{\saveleftskip} \par%
	}
%============================= examples ==================================================
\newcounter{egctr}
\definecolor{egrulegray}{gray}{.6}
\newlength{\egrulehspace}
\setlength{\egrulehspace}{.5mm}
\newlength{\egrulelen}
\setlength{\egrulelen}{53mm}
\newcommand{\egrule}[1]{\makebox[0mm][l]{\color{egrulegray}\rule{#1}{0.5pt}}}
\newcommand{\egvrule}{\makebox[0mm][l]{\color{egrulegray}\rule{0.5pt}{2mm}}}
\newcommand{\egbothrules}[1]{\makebox[0mm][l]{\hspace{-0.5mm}\raisebox{1.5mm}{\egvrule}\raisebox{3.5mm}{\egrule{#1}}}}
\newcommand{\egtit}[2]{\egbothrules{#1}\textit{\hspace{\egrulehspace}#2\hfill{}Example \theegctr}}
\newcommand{\baretit}[1]{\egbothrules{\egrulelen}\textit{\hspace{\egrulehspace}#1}}
\newenvironment{eg}[1][]
	{%
	  	\refstepcounter{egctr}%
  		\small\sffamily
		\noindent\egtit{\egrulelen}{#1}\\*\noindent%
                \protect\sansmath%
	}
	{%
		\lmserifmath
	}
\newcommand{\egquestion}{\noindent\ensuremath{\triangleright}\ }
\newcommand{\eganswer}{\noindent\ensuremath{\triangleright}\ }
%============================= self-checks and hw answers ==================================================
\newcounter{scctr}[chapter]
\newcommand{\whichsc}{}
\newcommand{\hwanssection}[1]{\vspace{4mm}\noindent\formatlikesection{#1}}
\newcommand{\beginsolutions}[1]{\pagebreak[3]\vspace{2mm}\noindent\formatlikesubsection{Solutions for chapter #1}\\*}
\newcommand{\beginscanswers}[1]{\pagebreak[3]\vspace{2mm}\noindent\formatlikesubsection{Answers to self-checks for chapter #1}\\*}
\newcommand{\hwsolnhdr}[1]{\noindent\textbf{page \pageref{hw:#1}, problem \ref{hw:#1}:}\ \label{soln:#1}}
\newcommand{\scanshdr}[1]{\noindent\textbf{page \pageref{sc:#1}, self-check \ref{sc:#1}:}\ \label{scans:#1}}
\newcommand{\scansref}[1]{$\triangleright$\ Answer, p. \pageref{scans:#1}}
\newenvironment{selfcheck}[1]
	{%
	  	\refstepcounter{scctr}\label{sc:#1}\renewcommand{\whichsc}{#1}%
  		\small\sffamily
                \noindent\egbothrules{\egrulelen}\textit{\hspace{\egrulehspace}Self-Check\hfill{}}\\*\noindent%
                \protect\sansmath%
	}
	{%
		 \hfill\scansref{\whichsc}\lmserifmath%
	}
%============================= code listings ==================================================
\newcounter{listingline}
\setcounter{listingline}{1}
\newcommand{\formatline}[1]{{\footnotesize #1\ }}
% ii = input line
% nn = numbered input line
% cc = continuation of an input line
% oo = output line
\newcommand{\ii}{\ }
\newcommand{\nn}{\formatline{\arabic{listingline}}\addtocounter{listingline}{1}}
\newcommand{\cc}{\formatline{\ \ \ \ \ \ }}
\newcommand{\oo}[1]{\formatline{\ \ \ \ }\textit{#1}}
\DefineVerbatimEnvironment{Code}{Verbatim}{commandchars=\\\{\},gobble=2}
\newcommand{\restartLineNumbers}{\setcounter{listingline}{1}}
\newcommand{\startcodeeg}{\nolinebreak[4]\vspace{-7mm}\nolinebreak[4]}
\newcommand{\finishcodeeg}{\vspace{-2mm}}
%============================= figures ==================================================
\newcounter{figctr}[chapter] % for my roll-your-own captions
\newcommand{\formatlikecaption}[1]{%
	\small{\protect\sansmath\sf{#1}\lmserifmath} %
}
\newcommand{\docaptionnorefstep}[3][l]{%
	\break%
        \ifthenelse{\equal{#1}{r}}{\hspace*{\fill}}{}
        \parbox{#3}{\formatlikecaption{\figurelabel#2}}
}
\newcommand{\docaption}[3]{% alignment, filename, width
        \refstepcounter{figctr}%
        \docaptionnorefstep[#1]{#2}{#3}%
}
\newcommand{\dofig}[4]{ % placement, filename, caption, width
	\noindent{}%
        \begin{figure}[#1]%
        \hfill\includegraphics[width=#4]{\chapdir/figs/#2}\\
	\docaption{r}{#3}{#4} %
	\label{fig:#2} %
        \end{figure}%
}
\newcommand{\dofigwide}[4]{ % placement, filename, caption, width
	\noindent{}%
        \begin{figure*}[#1]%
        \hfill\includegraphics[width=\textwidth]{\chapdir/figs/#2}\\
	\docaption{r}{#3}{\textwidth} %
	\label{fig:#2} %
        \end{figure*}%
}
\newcommand{\fig}[3][h]{\dofig{#1}{#2}{#3}{\figwidth}}
\newcommand{\widefig}[3][h]{\dofigwide{#1}{#2}{#3}{\figwidth}}
\newcommand{\smallfig}[3][h]{\dofig{#1}{#2}{#3}{\smallfigwidth}}
% Letters for figure number, and no "Figure .." in caption:
  \newcommand{\hwcaptions}{\def\figurelabel{}}
  \newcommand{\normalcaptions}{\def\figurelabel{\thefigctr\hspace{1mm}{\scriptsize{/}}\hspace{1mm}}}
  \normalcaptions
\renewcommand{\thefigctr}{\alphalph{\value{figctr}}}
\newcommand{\figref}[1]{\formatfigref{\ref{fig:#1}}}
\newcommand{\subfigref}[2]{\figref{#1}/#2}
% In DP, we use italics for figref, but in LM that would look too much like an algebra
% symbol, so no italics.
\newcommand{\formatfigref}[1]{#1}
%============================= titlesec stuff ===================================
\definecolor{secnumgray}{gray}{.55}
\newcommand{\showsecnum}[1]{\color{secnumgray}#1}
\titleformat{\chapter}
    {\normalfont\Huge\bfseries\sffamily\raggedright}{\thechapter}{5mm}
    {\Huge}
\titlespacing{\chapter}{0mm}{0mm}{5mm} % left margin, space before, space after
\titleformat{\section}
    {\normalfont\Large\bfseries\sffamily\raggedright}{\showsecnum{\thesection}}{0.6em}{}
\titlespacing{\section}{0mm}{0mm}{0mm} % left margin, space before, space after
\titleformat{\subsection}
  {\normalfont\normalsize\bfseries\sffamily\raggedright\protect\sansmath}{\lmserifmath}{0em}{}
\titleformat{\subsubsection}
  {\normalfont\normalsize\slshape\raggedright}{\thesubsubsection}{1em}{}
\newcommand{\formatlikesection}[1]{{\Large\bfseries\sffamily\raggedright{}#1}\normalsize}
\newcommand{\formatlikesubsection}[1]{{\bfseries\sffamily\raggedright{}#1}\normalsize}
\newcommand{\printthesection}{Section\ \thesection} % for titlesec, hw environment
%==============================toc==================================
%For the following, see the documentation for tocloft.sty:
%titletoc stuff:
\newcommand{\formatchtoc}[3]{%
  \titlecontents{chapter}[0mm]{\addvspace{#3}\sffamily}%
	{\contentsmargin{0mm}#1\thecontentslabel\enspace#1}%
	{\contentsmargin{0mm}#1}{#2}[]%
}
\contentsmargin{6mm}
\titlecontents{section}[0mm]{\sffamily}
	{\contentsmargin{0mm}\thecontentslabel\enspace}
	{}{\titlerule*[4mm]{.}\contentspage}
% In the following, titlecontents* is titletoc's way of saying I want subsections listed in a single paragraph.
\titlecontents*{subsection}[1.5em]{\small}{}%
		{}{, \thecontentspage}[.---][.]
\titlecontents{subsubsection}[]{}{}{}{}[]
% Brief contents:
\titlecontents{briefchapter}[0mm]{\Large\sffamily{}}
        {}{}
        {}
%========================= graphicx package=========================
\newif\ifpdf
\ifx\pdfoutput\undefined
\pdffalse % we are not running PDFLaTeX
\else
\pdfoutput=1 % we are running PDFLaTeX
\pdftrue
\fi

\ifpdf
\usepackage[pdftex]{graphicx}
\else
\usepackage{graphicx}
\fi
%========================= AtBeginDocument stuff=========================
\AtBeginDocument{
  \newboolean{hwhavetrailing}
  %------------------------------- pdf stuff
	\ifpdf
	\DeclareGraphicsExtensions{.pdf,.jpg,.png}
	\else
	\DeclareGraphicsExtensions{.eps,.jpg,.png}
	\fi
  \newcommand{\chapdir}{glub}
}
