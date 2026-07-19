CFLAGS = -fPIC -Isrc -std=c99 -pedantic -Wall -Wextra -Wno-unused-parameter -DACCEPT_USE_OF_DEPRECATED_PROJ_API_H
CC ?= gcc

NIF_LDFLAGS = -shared

ERLANG_PATH := $(shell erl -eval 'io:format("~s~n", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
ERLANG_CFLAGS = -I$(ERLANG_PATH)

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
# macOS: PROJ 4 comes from Homebrew (Intel: /usr/local, Apple Silicon: /opt/homebrew).
# enif_* symbols are provided by the beam executable at NIF load time; -undefined
# dynamic_lookup lets them stay undefined while keeping a two-level namespace, so
# -lproj actually links and libproj is recorded as a dependency (by absolute
# install name, so no rpath is needed). The original -flat_namespace -undefined
# suppress swallowed -lproj, leaving pj_ctx_alloc unresolved at dlopen.
BREW_PREFIX := $(shell brew --prefix 2>/dev/null)
PROJ_LIBS = $(if $(BREW_PREFIX),-L$(BREW_PREFIX)/lib) -lproj
NIF_LDFLAGS += -undefined dynamic_lookup
else
# Linux: PROJ 4 is built from source into /usr/local. ldconfig handles runtime
# resolution; -L handles link time. Undefined enif_* symbols are resolved from
# the beam executable at load, which is the default for -shared.
PROJ_LIBS = -L/usr/local/lib -lproj
endif

all: proj_nif.so geodesic_nif.so

proj_nif.so: priv/proj_nif.so
geodesic_nif.so: priv/geodesic_nif.so

priv/proj_nif.so: src/proj_nif.o src/utils.o
	$(CC) $(CFLAGS) $^ -o $@ $(PROJ_LIBS) $(NIF_LDFLAGS)

priv/geodesic_nif.so: src/geodesic_nif.o src/utils.o
	$(CC) $(CFLAGS) $^ -o $@ $(PROJ_LIBS) $(NIF_LDFLAGS)

src/%.o: src/%.c
	$(CC) $(CFLAGS) -c $< -o $@ $(ERLANG_CFLAGS)

src/proj_nif.o: src/utils.h
src/geodesic_nif.o: src/utils.h

clean:
	rm -rf src/*.o priv/*.so

.PHONY: all clean proj_nif.so geodesic_nif.so
