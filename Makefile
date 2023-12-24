NAME=cycle_express
BACKEND_MAIN_SRC=src/backend/Main.mo
BACKEND_SRC=$(wildcard src/backend/*.mo)
FRONTEND_SRC=$(wildcard src/frontend/*)
ASSETS_SRC=$(wildcard src/assets/*)
FRONTEND_DIST=$(wildcard dist/*)
DOCS=src/assets/about.html src/assets/privacy.html src/assets/terms.html
MOC_VERSION=$(shell grep compiler vessel.dhall|cut -d\" -f2)
MOC=.vessel/.bin/$(MOC_VERSION)/moc

default_: backend frontend

frontend: dist/index.html dist/js/bundle.js
dist/index.html dist/js/bundle.js &: $(FRONTEND_SRC) $(DOCS) $(ASSETS_SRC) node_modules/
	npm run build

backend: build/$(NAME).wasm
build/$(NAME).wasm build/$(NAME).did &: ${BACKEND_SRC} .vessel/ build/ $(MOC)
	$(MOC) --public-metadata candid:service --public-metadata candid:args --public-metadata motoko:compiler \
	   	--idl -c -o $@ $$(vessel sources) $(BACKEND_MAIN_SRC)

$(MOC): .vessel/
	vessel bin

.vessel/: vessel.dhall package-set.dhall
	vessel install && sed -i 's/base-0.7.3/base/g' $$(find .vessel -type f)

src/assets/%.html: doc/%.md
	pandoc -f markdown -t html --shift-heading-level-by=2 $< > $@

build/:
	mkdir -p $@

node_modules/:
	npm i

clean:
	rm $(DOCS)
	rm -rf build/ dist/

distclean: clean
	rm -rf node_modules/ .vessel/

release.tar.gz: backend frontend
	tar zcvf $@ dist/ build/

.PHONY: build frontend backend clean distclean release
