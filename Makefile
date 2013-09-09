TESTS         = $(shell find tests -type f -name test-*)

JS_FILE      := $(shell find ./ -type f -name *.coffee)

-BIN_COFFEE  := ./node_modules/coffee-script/bin/coffee
-MOCHA       := ./node_modules/.bin/mocha

-PUB_bae_TEMP = ../../publish_bae

-PUB_git_TEMP = ../../helpYou

MESSAGE       = commit form shell

PUBTYPE       = git

VERSION       = 0

default: dev

dev: npm-install test-pre env-pre

test-pre: test

env-pre:
	@if [ ! -x $(-PUB_bae_TEMP) ]; then \
		mkdir $(-PUB_bae_TEMP) ;\
		mkdir $(-PUB_bae_TEMP)/$(VERSION) ;\
	fi
	@if [ ! -x $(-PUB_git_TEMP) ]; then \
		mkdir $(-PUB_git_TEMP) ;\
		mkdir $(-PUB_git_TEMP)/$(VERSION) ;\
	fi

test:
	@echo "\033[31m begin unit test!\033[39;49;0m\n"
	@$(-MOCHA) \
		--colors \
		--reporter spec \
		$(TESTS)

npm-install:
	@echo "\033[31m checking node modules... \033[39;49;0m\n"
	@npm install
	@echo "\033[32m node modules are all clear! \033[39;49;0m\n"

compile-coffee:
	@echo "\033[31m compiling coffee scripts... \033[39;49;0m\n"
	@echo $(JS_FILE)
	@for f in $(JS_FILE); do\
		coffee -c $$f;\
		rm -rf $$f;\
	done

publish_bae: env-pre
	@cp -a . $(-PUB_bae_TEMP)/$(VERSION)
	@cd $(-PUB_bae_TEMP)/$(VERSION) ;\
	make compile-coffee ;\
	$(doPublish) ;\

publish_git:
	@cp -rf ./* $(-PUB_git_TEMP)
	@cd $(-PUB_git_TEMP) ;\
	$(doPublish)

define doPublish
pwd ;\
git add . ;\
git commit -a -m "$(MESSAGE)" ;\
git push origin master
endef

	