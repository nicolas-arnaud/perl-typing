NAME = typerl

all: install

init:
	cpanm --installdeps .

install: $(NAME).pl
	mkdir -p ~/.local/etc/$(NAME)
	cp -r ./* ~/.local/etc/$(NAME)/
	mv ~/.local/etc/$(NAME)/$(NAME).pl ~/.local/etc/$(NAME)/$(NAME)
	chmod +x ~/.local/etc/$(NAME)/$(NAME)
	ln -f -s ~/.local/etc/$(NAME)/$(NAME) ~/.local/bin/$(NAME) || true

uninstall:
	rm -rf ~/.local/etc/$(NAME)
	rm -f ~/.local/bin/$(NAME)

reinstall: uninstall install
