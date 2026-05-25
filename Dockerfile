# Turbo.lua test image.
#
# Copyright (C) 2026 John Abrahamsen.
# See LICENSE file for license information.
#
# Builds Turbo against LuaJIT on Debian and runs the busted test suite.
# Replaces the (defunct) Travis CI setup with a reproducible Linux environment.
#
# Build:  docker build -t turbo-test .
# Test:   docker run --rm turbo-test                      # default: unit specs
#         docker run --rm turbo-test spec/web_spec.lua    # run a specific spec
#         docker run --rm turbo-test spec/                # attempt every spec
#
# The default CMD runs only the deterministic, self-contained unit specs. The
# HTTP/async/iostream specs are intentionally excluded from the default run:
# they require real outbound network (e.g. async_spec fetches google.com with a
# 60s wait) and a working loopback HTTP path that does not behave reliably in a
# headless container, so they hang or time out regardless of code correctness.
#
# The image runs on whatever architecture the daemon uses; on Apple Silicon
# this is linux/arm64, which also exercises the ARM64 syscall code paths.
FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        luajit libluajit-5.1-dev \
        luarocks \
        build-essential libssl-dev \
        git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# busted installs into the lua 5.1 rock tree (LuaJIT is 5.1-compatible). The
# generated wrapper hardcodes the PUC lua5.1 interpreter, which lacks FFI, so
# we invoke the rock's entry point under luajit instead (see busted-luajit).
RUN luarocks install busted

COPY docker/busted-luajit /usr/local/bin/busted-luajit
RUN chmod +x /usr/local/bin/busted-luajit

WORKDIR /turbo
COPY . /turbo

# Build libtffi_wrap.so (and http-parser). make clean first to drop any host
# build artifacts that may have been copied in.
RUN make clean >/dev/null 2>&1 || true; make

ENV TURBO_LIBTFFI=/turbo/libtffi_wrap.so
ENV TURBO_SSL=1

ENTRYPOINT ["busted-luajit"]
CMD ["spec/security_spec.lua", \
     "spec/mustache_spec.lua", \
     "spec/util_spec.lua", \
     "spec/structs_spec.lua", \
     "spec/hash_spec.lua", \
     "spec/httputil_spec.lua"]
