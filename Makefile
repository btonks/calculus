#
#
# See comments at the top of gen_graph.rb for notes about
# figures, fonts, lulu, etc.
#
#
#

BOOK = calc
MODE = nonstopmode
TERMINAL_OUTPUT = err

MAKEINDEX = makeindex $(BOOK).idx

DO_PDFLATEX_RAW = pdflatex -interaction=$(MODE) $(BOOK) >$(TERMINAL_OUTPUT)
SHOW_ERRORS = \
        print "========error========\n"; \
        open(F,"$(TERMINAL_OUTPUT)"); \
        while ($$line = <F>) { \
          if ($$line=~m/^\! / || $$line=~m/^l.\d+ /) { \
            print $$line \
          } \
        } \
        close F; \
        exit(1)
DO_PDFLATEX = echo "$(DO_PDFLATEX_RAW)" ; perl -e 'if (system("$(DO_PDFLATEX_RAW)")) {$(SHOW_ERRORS)}'

# Since book1 comes first, it's the default target --- you can just do ``make'' to make it.

book1:
	@$(DO_PDFLATEX)
	@rm -f $(TERMINAL_OUTPUT) # If pdflatex has a nonzero exit code, we don't get here, so the output file is available for inspection.

index:
	$(MAKEINDEX)

book:
	make clean
	@$(DO_PDFLATEX)
	@$(DO_PDFLATEX)
	$(MAKEINDEX)
	@$(DO_PDFLATEX)
	@rm -f $(TERMINAL_OUTPUT) # If pdflatex has a nonzero exit code, we don't get here, so the output file is available for inspection.

test:
	perl -e 'if (system("pdflatex -interaction=$(MODE) $(BOOK) >$(TERMINAL_OUTPUT)")) {print "error\n"} else {print "no error\n"}'

clean:
	# Sometimes we get into a state where LaTeX is unhappy, and erasing these cures it:
	rm -f *aux *idx *ilg *ind *log *toc
	rm -f ch*/*aux
	# Shouldn't exist in subdirectories:
	rm -f */*.log
	# Emacs backup files:
	rm -f *~
	rm -f */*~
	# Misc:
	rm -f ch*/figs/*.eps
	rm -Rf ch*/figs/.xvpics
	rm -f a.a
	rm -f */a.a
	rm -f */*/a.a
	rm -f junk
	rm -f err
	# ... done.

post:
	cp calc.pdf /home/bcrowell/Lightandmatter/calc

prepress:
	# The following makes Lulu not complain about missing fonts:
	pdftk calc.pdf cat 3-end output temp.pdf
	gs -q -dCompatibilityLevel=1.4 -dSubsetFonts=false -dPDFSETTINGS=/printer -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=calc_lulu.pdf temp.pdf -c '.setpdfwrite'


post_source:
	# don't forget to commit first
	git push
