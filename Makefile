.PHONY: dotfiles
dotfiles:
	for file in $(shell find $(CURDIR) -name ".*" -not -name ".git"); do \
		echo $$(basename $$file); \
		ln -sfn $$file $(HOME)/$$(basename $$file); \
	done;		
