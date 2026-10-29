#!/bin/bash

# Copyright 2023 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

export NGINX_VERSION=1.31.8

# Check for recent changes: https://github.com/openresty/ngx_devel_kit/compare/v0.3.6...master
export NDK_VERSION=v0.3.6

# Check for recent changes: https://github.com/openresty/set-misc-nginx-module/compare/v0.34...master
export SETMISC_VERSION=v0.34

# Check for recent changes: https://github.com/openresty/headers-more-nginx-module/compare/v0.40...master
export MORE_HEADERS_VERSION=v0.40

# Check for recent changes: https://github.com/atomx/nginx-http-auth-digest/compare/v1.0.0...master
export NGINX_DIGEST_AUTH=v1.0.0

# Check for recent changes: https://github.com/owasp-modsecurity/ModSecurity-nginx/compare/v1.0.4...master
export MODSECURITY_VERSION=v1.0.4

# Check for recent changes: https://github.com/owasp-modsecurity/ModSecurity/compare/v3.0.14...v3/master
export MODSECURITY_LIB_VERSION=v3.0.14

# Check for recent changes: https://github.com/coreruleset/coreruleset/compare/v4.22.0...main
export OWASP_MODSECURITY_CRS_VERSION=v4.22.0

# Check for recent changes: https://github.com/openresty/lua-nginx-module/compare/v0.10.32rc7...master
export LUA_NGX_VERSION=v0.10.32rc7

# Check for recent changes: https://github.com/openresty/stream-lua-nginx-module/compare/v0.0.20rc3...master
export LUA_STREAM_NGX_VERSION=v0.0.20rc3

# Check for recent changes: https://github.com/openresty/lua-upstream-nginx-module/compare/v0.08...master
export LUA_UPSTREAM_VERSION=v0.08

# Check for recent changes: https://github.com/openresty/lua-cjson/compare/2.1.0.20...master
export LUA_CJSON_VERSION=2.1.0.20

# Check for recent changes: https://github.com/leev/ngx_http_geoip2_module/compare/445df24ef3781e488cee3dfe8a1e111997fc1dfe...master
export GEOIP2_VERSION=445df24ef3781e488cee3dfe8a1e111997fc1dfe

# Check for recent changes: https://github.com/openresty/luajit2/compare/v2.1-20261023...v2.1-agentzh
export LUAJIT_VERSION=v2.1-20261023

# Check for recent changes: https://github.com/openresty/lua-resty-balancer/compare/v0.05...master
export LUA_RESTY_BALANCER=v0.05

# Check for recent changes: https://github.com/openresty/lua-resty-lrucache/compare/v0.15...master
export LUA_RESTY_CACHE=v0.15

# Check for recent changes: https://github.com/openresty/lua-resty-core/compare/v0.1.35rc2...master
export LUA_RESTY_CORE=v0.1.35rc2

# Check for recent changes: https://github.com/cloudflare/lua-resty-cookie/compare/f418d77082eaef48331302e84330488fdc810ef4...master
export LUA_RESTY_COOKIE_VERSION=f418d77082eaef48331302e84330488fdc810ef4

# Check for recent changes: https://github.com/openresty/lua-resty-dns/compare/v0.24...master
export LUA_RESTY_DNS=v0.24

# Check for recent changes: https://github.com/ledgetech/lua-resty-http/compare/v0.17.2...master
export LUA_RESTY_HTTP=v0.17.2

# Check for recent changes: https://github.com/openresty/lua-resty-lock/compare/v0.09...master
export LUA_RESTY_LOCK=v0.09

# Check for recent changes: https://github.com/openresty/lua-resty-upload/compare/v0.11...master
export LUA_RESTY_UPLOAD_VERSION=v0.11

# Check for recent changes: https://github.com/openresty/lua-resty-string/compare/v0.19...master
export LUA_RESTY_STRING_VERSION=v0.19

# Check for recent changes: https://github.com/openresty/lua-resty-memcached/compare/v0.18...master
export LUA_RESTY_MEMCACHED_VERSION=v0.18

# Check for recent changes: https://github.com/openresty/lua-resty-redis/compare/v0.34...master
export LUA_RESTY_REDIS_VERSION=v0.34

# Check for recent changes: https://github.com/api7/lua-resty-ipmatcher/compare/3e93c53eb8c9884efe939ef070486a0e507cc5be...master
export LUA_RESTY_IPMATCHER_VERSION=3e93c53eb8c9884efe939ef070486a0e507cc5be

# Check for recent changes: https://github.com/microsoft/mimalloc/compare/v2.2.4...main
export MIMALOC_VERSION=v2.2.4

# Check for recent changes: https://github.com/open-telemetry/opentelemetry-cpp/compare/v1.19.0...main
export OPENTELEMETRY_CPP_VERSION=v1.19.0

# Check for recent changes: https://github.com/open-telemetry/opentelemetry-proto/compare/v1.5.0...main
export OPENTELEMETRY_PROTO_VERSION=v1.5.0

# Check for recent changes: https://github.com/nginx/njs/compare/1.0.2...master
export NJS_VERSION=1.0.2

export BUILD_PATH=/tmp/build

ARCH=$(uname -m)

get_src()
{
  hash="$1"
  url="$2"
  dest="${3-}"
  ARGS=""
  f=$(basename "$url")

  echo "Downloading $url"

  curl -sSL "$url" -o "$f"
  # TODO: Reenable checksum verification but make it smarter
  # echo "$hash  $f" | sha256sum -c - || exit 10
  if [ ! -z "$dest" ]; then
        mkdir ${BUILD_PATH}/${dest}
        ARGS="-C ${BUILD_PATH}/${dest} --strip-components=1"
  fi
  tar xvzf "$f" $ARGS
  rm -rf "$f"
}

# install required packages to build
# Dependencies from "ninja" and below are OTEL dependencies
apk add \
  bash \
  gcc \
  clang \
  libc-dev \
  make \
  automake \
  openssl-dev \
  pcre-dev \
  zlib-dev \
  linux-headers \
  libxslt-dev \
  gd-dev \
  perl-dev \
  libedit-dev \
  mercurial \
  alpine-sdk \
  findutils \
  curl \
  ca-certificates \
  patch \
  libaio-dev \
  openssl \
  cmake \
  util-linux \
  lmdb-tools \
  wget \
  curl-dev \
  libprotobuf \
  git g++ pkgconf flex bison doxygen yajl-dev lmdb-dev libtool autoconf libxml2 libxml2-dev \
  python3 \
  libmaxminddb-dev \
  bc \
  unzip \
  dos2unix \
  yaml-cpp \
  coreutils \
  ninja \
  gtest-dev \
  git \
  build-base \
  pkgconfig \
  c-ares-dev \
  re2-dev \
  grpc-dev \
  protobuf-dev

# apk add -X http://dl-cdn.alpinelinux.org/alpine/edge/testing opentelemetry-cpp-dev

mkdir -p /etc/nginx

mkdir --verbose -p "$BUILD_PATH"
cd "$BUILD_PATH"

# download, verify and extract the source files
get_src 0652b760b3b772d2ec17b47c2fc15d9a95e6fe35cd5b877eadc1a62d9bc75af1 \
        "https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz"

get_src e3438a71130b63760ac4accec9f77ac8f91ad8f778e1940b061e9ea83dd62fe7 \
        "https://github.com/openresty/ngx_devel_kit/archive/$NDK_VERSION.tar.gz" "ngx_devel_kit"

get_src abc123 \
        "https://github.com/open-telemetry/opentelemetry-cpp/archive/$OPENTELEMETRY_CPP_VERSION.tar.gz" "opentelemetry-cpp"

get_src abc123 \
        "https://github.com/open-telemetry/opentelemetry-proto/archive/$OPENTELEMETRY_PROTO_VERSION.tar.gz" "opentelemetry-proto"

get_src f083e6a68520a9dfa09f0afbeb88ab7539f479cc5af91d8607ae2ab1874f9898 \
        "https://github.com/openresty/set-misc-nginx-module/archive/$SETMISC_VERSION.tar.gz" "set-misc-nginx-module"

get_src c14cb5e6c998590c209efbf77bd7637ce2cab02332e4192756a8af5b26ba4284 \
        "https://github.com/openresty/headers-more-nginx-module/archive/$MORE_HEADERS_VERSION.tar.gz" "headers-more-nginx-module"

get_src f09851e6309560a8ff3e901548405066c83f1f6ff88aa7171e0763bd9514762b \
        "https://github.com/atomx/nginx-http-auth-digest/archive/$NGINX_DIGEST_AUTH.tar.gz" "nginx-http-auth-digest"

get_src 32a42256616cc674dca24c8654397390adff15b888b77eb74e0687f023c8751b \
        "https://github.com/owasp-modsecurity/ModSecurity-nginx/archive/$MODSECURITY_VERSION.tar.gz" "ModSecurity-nginx"

get_src 70e005d3883224a808638154396c65b5e756876e9957c90b244a2f51ca07a843 \
        "https://github.com/openresty/lua-nginx-module/archive/$LUA_NGX_VERSION.tar.gz" "lua-nginx-module"

get_src cbd42d84575be2ca34d58091a519db58b734d9f8ddb9ebb681e0f77e5d9b78f6 \
        "https://github.com/openresty/stream-lua-nginx-module/archive/$LUA_STREAM_NGX_VERSION.tar.gz" "stream-lua-nginx-module"

get_src 722620a74a8f75ac154691933d2ae4969b2173061476a3d3bf0de2b9891a0e45 \
        "https://github.com/openresty/lua-upstream-nginx-module/archive/$LUA_UPSTREAM_VERSION.tar.gz" "lua-upstream-nginx-module"

get_src 46ec00b6ba6261890a7d185c48f848e5e6b7a2909fc39ac80f407d1dcbfc74b2 \
        "https://github.com/openresty/luajit2/archive/$LUAJIT_VERSION.tar.gz" "luajit2"

get_src b6c9c09fd43eb34a71e706ad780b2ead26549a9a9f59280fe558f5b7b980b7c6 \
        "https://github.com/leev/ngx_http_geoip2_module/archive/$GEOIP2_VERSION.tar.gz" "ngx_http_geoip2_module"

get_src deb4ab1ffb9f3d962c4b4a2c4bdff692b86a209e3835ae71ebdf3b97189e40a9 \
        "https://github.com/openresty/lua-resty-upload/archive/$LUA_RESTY_UPLOAD_VERSION.tar.gz" "lua-resty-upload"

get_src 8b3e17e8796f083228b89ddd013bcc688c7d15afcc721c70059fd4a8bf2355dc \
        "https://github.com/openresty/lua-resty-string/archive/$LUA_RESTY_STRING_VERSION.tar.gz" "lua-resty-string"

get_src 16d72ed133f0c6df376a327386c3ef4e9406cf51003a700737c3805770ade7c5 \
        "https://github.com/openresty/lua-resty-balancer/archive/$LUA_RESTY_BALANCER.tar.gz" "lua-resty-balancer"

get_src fcd84dd01c8d589b0c1f68b11dd54c50d70d9b15d3f6e1a5760e970c4f99b7aa \
        "https://github.com/openresty/lua-resty-core/archive/$LUA_RESTY_CORE.tar.gz" "lua-resty-core"

get_src a99fb872aa731274ac70453cd4e6b2e0e8fb978893063d512ca67c7c332510e1 \
        "https://github.com/openresty/lua-cjson/archive/$LUA_CJSON_VERSION.tar.gz" "lua-cjson"

get_src 5ed48c36231e2622b001308622d46a0077525ac2f751e8cc0c9905914254baa4 \
        "https://github.com/cloudflare/lua-resty-cookie/archive/$LUA_RESTY_COOKIE_VERSION.tar.gz" "lua-resty-cookie"

get_src 573184006b98ccee2594b0d134fa4d05e5d2afd5141cbad315051ccf7e9b6403 \
        "https://github.com/openresty/lua-resty-lrucache/archive/$LUA_RESTY_CACHE.tar.gz" "lua-resty-lrucache"

get_src b4ddcd47db347e9adf5c1e1491a6279a6ae2a3aff3155ef77ea0a65c998a69c1 \
        "https://github.com/openresty/lua-resty-lock/archive/$LUA_RESTY_LOCK.tar.gz" "lua-resty-lock"

get_src 06e08aec4290ee83b505a0b9fa66fa4e9fbe729ce505bc88f3dc2093789223f7 \
        "https://github.com/openresty/lua-resty-dns/archive/$LUA_RESTY_DNS.tar.gz" "lua-resty-dns"

get_src 9fcb6db95bc37b6fce77d3b3dc740d593f9d90dce0369b405eb04844d56ac43f \
        "https://github.com/ledgetech/lua-resty-http/archive/$LUA_RESTY_HTTP.tar.gz" "lua-resty-http"

get_src 3567144cfa26e63453960ec347137f47403b264af071385d2f16b8434eb3736e \
        "https://github.com/openresty/lua-resty-memcached/archive/$LUA_RESTY_MEMCACHED_VERSION.tar.gz" "lua-resty-memcached"

get_src 427fde15a4ad2237c947368bee2c443bf8f402e339f64bf3716de324c6afb613 \
        "https://github.com/openresty/lua-resty-redis/archive/$LUA_RESTY_REDIS_VERSION.tar.gz" "lua-resty-redis"

get_src efb767487ea3f6031577b9b224467ddbda2ad51a41c5867a47582d4ad85d609e \
        "https://github.com/api7/lua-resty-ipmatcher/archive/$LUA_RESTY_IPMATCHER_VERSION.tar.gz" "lua-resty-ipmatcher"

get_src d74f86ada2329016068bc5a243268f1f555edd620b6a7d6ce89295e7d6cf18da \
        "https://github.com/microsoft/mimalloc/archive/${MIMALOC_VERSION}.tar.gz" "mimalloc"

get_src 84a114499fa6878d3ec52b99c1cf2874a91eb0d915408f418a2b1279519f09ae \
        "https://github.com/nginx/njs/archive/${NJS_VERSION}.tar.gz" "njs"

# improve compilation times
CORES=$(($(grep -c ^processor /proc/cpuinfo) - 1))

export MAKEFLAGS=-j${CORES}
export CTEST_BUILD_FLAGS=${MAKEFLAGS}

# Install luajit from openresty fork
export LUAJIT_LIB=/usr/local/lib
export LUA_LIB_DIR="$LUAJIT_LIB/lua"
export LUAJIT_INC=/usr/local/include/luajit-2.1

cd "$BUILD_PATH/luajit2"
make CCDEBUG=-g
make install

ln -s /usr/local/bin/luajit /usr/local/bin/lua
ln -s "$LUAJIT_INC" /usr/local/include/lua

cd "$BUILD_PATH/opentelemetry-cpp"
export CXXFLAGS="-DBENCHMARK_HAS_NO_INLINE_ASSEMBLY"
cmake -B build -G Ninja -Wno-dev \
        -DOTELCPP_PROTO_PATH="${BUILD_PATH}/opentelemetry-proto/" \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DBUILD_SHARED_LIBS=ON \
        -DBUILD_TESTING="OFF" \
        -DBUILD_W3CTRACECONTEXT_TEST="OFF" \
        -DCMAKE_BUILD_TYPE=None \
        -DWITH_ABSEIL=ON \
        -DWITH_STL=ON \
        -DWITH_EXAMPLES=OFF \
        -DWITH_ZPAGES=OFF \
        -DWITH_OTLP_GRPC=ON \
        -DWITH_OTLP_HTTP=ON \
        -DWITH_ZIPKIN=ON \
        -DWITH_PROMETHEUS=OFF \
        -DWITH_ASYNC_EXPORT_PREVIEW=OFF \
        -DWITH_METRICS_EXEMPLAR_PREVIEW=OFF
      cmake --build build
      cmake --install build

# Git tuning
git config --global --add core.compression -1

# Get Brotli source and deps
cd "$BUILD_PATH"
git clone --depth=100 https://github.com/google/ngx_brotli.git
cd ngx_brotli
git reset --hard a71f9312c2deb28875acc7bacfdd5695a111aa53
git submodule init
git submodule update

cd "$BUILD_PATH"
git clone --depth=1 https://github.com/ssdeep-project/ssdeep
cd ssdeep/

./bootstrap
./configure

make
make install

# build modsecurity library
cd "$BUILD_PATH"
git clone -n https://github.com/owasp-modsecurity/ModSecurity
cd ModSecurity/
git checkout $MODSECURITY_LIB_VERSION
git submodule init
git submodule update

sh build.sh

# https://github.com/owasp-modsecurity/ModSecurity/issues/1909#issuecomment-465926762
sed -i '115i LUA_CFLAGS="${LUA_CFLAGS} -DWITH_LUA_JIT_2_1"' build/lua.m4
sed -i '117i AC_SUBST(LUA_CFLAGS)' build/lua.m4

#
# As of Alpine v3.23.0, building ModSecurity fails with:
#
# headers/modsecurity/collection/collection.h:x:x: error: 'int32_t' has not been declared
# headers/modsecurity/collection/collection.h:x:x: note: 'int32_t' is defined in header '<cstdint>'; this is probably fixable by adding '#include <cstdint>'
#
# Sadly this has not been fixed upstream, yet, so we manually patch it here.
#
sed -i '24i #include <cstdint>' headers/modsecurity/collection/collection.h

./configure \
  --disable-doxygen-doc \
  --disable-doxygen-html \
  --disable-examples

make
make install

mkdir -p /etc/nginx/modsecurity
cp modsecurity.conf-recommended /etc/nginx/modsecurity/modsecurity.conf
cp unicode.mapping /etc/nginx/modsecurity/unicode.mapping

# Replace serial logging with concurrent
sed -i 's|SecAuditLogType Serial|SecAuditLogType Concurrent|g' /etc/nginx/modsecurity/modsecurity.conf

# Concurrent logging implies the log is stored in several files
echo "SecAuditLogStorageDir /var/log/audit/" >> /etc/nginx/modsecurity/modsecurity.conf

# Download owasp modsecurity crs
cd /etc/nginx/

git clone -b $OWASP_MODSECURITY_CRS_VERSION https://github.com/coreruleset/coreruleset
mv coreruleset owasp-modsecurity-crs
cd owasp-modsecurity-crs

mv crs-setup.conf.example crs-setup.conf
mv rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
mv rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf
cd ..

# OWASP CRS v4 rules
echo "
Include /etc/nginx/owasp-modsecurity-crs/crs-setup.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-901-INITIALIZATION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-905-COMMON-EXCEPTIONS.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-911-METHOD-ENFORCEMENT.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-913-SCANNER-DETECTION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-920-PROTOCOL-ENFORCEMENT.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-921-PROTOCOL-ATTACK.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-922-MULTIPART-ATTACK.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-930-APPLICATION-ATTACK-LFI.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-931-APPLICATION-ATTACK-RFI.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-932-APPLICATION-ATTACK-RCE.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-933-APPLICATION-ATTACK-PHP.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-934-APPLICATION-ATTACK-GENERIC.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-941-APPLICATION-ATTACK-XSS.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-942-APPLICATION-ATTACK-SQLI.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-943-APPLICATION-ATTACK-SESSION-FIXATION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-944-APPLICATION-ATTACK-JAVA.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/REQUEST-949-BLOCKING-EVALUATION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-950-DATA-LEAKAGES.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-951-DATA-LEAKAGES-SQL.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-952-DATA-LEAKAGES-JAVA.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-953-DATA-LEAKAGES-PHP.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-954-DATA-LEAKAGES-IIS.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-955-WEB-SHELLS.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-959-BLOCKING-EVALUATION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-980-CORRELATION.conf
Include /etc/nginx/owasp-modsecurity-crs/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf
" > /etc/nginx/owasp-modsecurity-crs/nginx-modsecurity.conf

# build nginx
cd "$BUILD_PATH/nginx-$NGINX_VERSION"

# apply nginx patches
for PATCH in `ls /patches`;do
  echo "Patch: $PATCH"
  if [[ "$PATCH" == *.txt ]]; then
    patch -p0 < /patches/$PATCH
  else
    patch -p1 < /patches/$PATCH
  fi
done

WITH_FLAGS="--with-debug \
  --with-compat \
  --with-pcre-jit \
  --with-http_ssl_module \
  --with-http_stub_status_module \
  --with-http_realip_module \
  --with-http_auth_request_module \
  --with-http_addition_module \
  --with-http_gzip_static_module \
  --with-http_sub_module \
  --with-http_v2_module \
  --with-http_v3_module \
  --with-stream \
  --with-stream_ssl_module \
  --with-stream_realip_module \
  --with-stream_ssl_preread_module \
  --with-threads \
  --with-http_secure_link_module \
  --with-http_gunzip_module"

# "Combining -flto with -g is currently experimental and expected to produce unexpected results."
# https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html
CC_OPT="-g -O2 -fPIE -fstack-protector-strong \
  -Wformat \
  -Werror=format-security \
  -Wno-deprecated-declarations \
  -fno-strict-aliasing \
  -D_FORTIFY_SOURCE=2 \
  --param=ssp-buffer-size=4 \
  -DTCP_FASTOPEN=23 \
  -fPIC \
  -Wno-cast-function-type"

LD_OPT="-fPIE -fPIC -pie -Wl,-z,relro -Wl,-z,now"

if [[ ${ARCH} != "aarch64" ]]; then
  WITH_FLAGS+=" --with-file-aio"
fi

if [[ ${ARCH} == "x86_64" ]]; then
  CC_OPT+=' -m64 -mtune=generic'
fi

WITH_MODULES=" \
  --add-module=$BUILD_PATH/ngx_devel_kit \
  --add-module=$BUILD_PATH/set-misc-nginx-module \
  --add-module=$BUILD_PATH/headers-more-nginx-module \
  --add-module=$BUILD_PATH/lua-nginx-module \
  --add-module=$BUILD_PATH/stream-lua-nginx-module \
  --add-module=$BUILD_PATH/lua-upstream-nginx-module \
  --add-dynamic-module=$BUILD_PATH/nginx-http-auth-digest \
  --add-dynamic-module=$BUILD_PATH/ModSecurity-nginx \
  --add-dynamic-module=$BUILD_PATH/ngx_http_geoip2_module \
  --add-dynamic-module=$BUILD_PATH/ngx_brotli \
  --add-dynamic-module=$BUILD_PATH/njs/nginx"

./configure \
  --prefix=/usr/local/nginx \
  --conf-path=/etc/nginx/nginx.conf \
  --modules-path=/etc/nginx/modules \
  --http-log-path=/var/log/nginx/access.log \
  --error-log-path=/var/log/nginx/error.log \
  --lock-path=/var/lock/nginx.lock \
  --pid-path=/run/nginx.pid \
  --http-client-body-temp-path=/var/lib/nginx/body \
  --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
  --http-proxy-temp-path=/var/lib/nginx/proxy \
  --http-scgi-temp-path=/var/lib/nginx/scgi \
  --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
  ${WITH_FLAGS} \
  --without-mail_pop3_module \
  --without-mail_smtp_module \
  --without-mail_imap_module \
  --without-http_uwsgi_module \
  --without-http_scgi_module \
  --with-cc-opt="${CC_OPT}" \
  --with-ld-opt="${LD_OPT}" \
  --user=www-data \
  --group=www-data \
  ${WITH_MODULES}

make
make modules
make install

# Check for recent changes: https://github.com/open-telemetry/opentelemetry-cpp-contrib/compare/8933841f0a7f8737f61404cf0a64acf6b079c8a5...main
export OPENTELEMETRY_CONTRIB_COMMIT=8933841f0a7f8737f61404cf0a64acf6b079c8a5
cd "$BUILD_PATH"

git clone https://github.com/open-telemetry/opentelemetry-cpp-contrib.git opentelemetry-cpp-contrib-${OPENTELEMETRY_CONTRIB_COMMIT}

cd ${BUILD_PATH}/opentelemetry-cpp-contrib-${OPENTELEMETRY_CONTRIB_COMMIT}
git reset --hard ${OPENTELEMETRY_CONTRIB_COMMIT}

export OTEL_TEMP_INSTALL=/tmp/otel
mkdir -p ${OTEL_TEMP_INSTALL}

cd ${BUILD_PATH}/opentelemetry-cpp-contrib-${OPENTELEMETRY_CONTRIB_COMMIT}/instrumentation/nginx
mkdir -p build
cd build
cmake -DCMAKE_BUILD_TYPE=Release \
        -G Ninja \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_INSTALL_PREFIX=${OTEL_TEMP_INSTALL} \
        -DBUILD_SHARED_LIBS=ON \
        -DNGINX_VERSION=${NGINX_VERSION} \
        ..
cmake --build . -j ${CORES} --target install

mkdir -p /etc/nginx/modules
cp ${OTEL_TEMP_INSTALL}/otel_ngx_module.so /etc/nginx/modules/otel_ngx_module.so


cd "$BUILD_PATH/lua-resty-core"
make install

cd "$BUILD_PATH/lua-resty-balancer"
make all
make install

export LUA_INCLUDE_DIR=/usr/local/include/luajit-2.1
ln -s $LUA_INCLUDE_DIR /usr/include/lua5.1

cd "$BUILD_PATH/lua-cjson"
make all
make install

cd "$BUILD_PATH/lua-resty-cookie"
make all
make install

cd "$BUILD_PATH/lua-resty-lrucache"
make install

cd "$BUILD_PATH/lua-resty-dns"
make install

cd "$BUILD_PATH/lua-resty-lock"
make install

# required for OCSP verification
cd "$BUILD_PATH/lua-resty-http"
make install

cd "$BUILD_PATH/lua-resty-upload"
make install

cd "$BUILD_PATH/lua-resty-string"
make install

cd "$BUILD_PATH/lua-resty-memcached"
make install

cd "$BUILD_PATH/lua-resty-redis"
make install

cd "$BUILD_PATH/lua-resty-ipmatcher"
INST_LUADIR=/usr/local/lib/lua make install

cd "$BUILD_PATH/mimalloc"
mkdir -p out/release
cd out/release

# See this issue for why we disable architecture specific optimizations: https://github.com/kubernetes/ingress-nginx/issues/13608.
cmake -DMI_NO_OPT_ARCH=ON ../..

make
make install

# update image permissions
writeDirs=( \
  /etc/nginx \
  /usr/local/nginx \
  /opt/modsecurity/var/log \
  /opt/modsecurity/var/upload \
  /opt/modsecurity/var/audit \
  /var/log/audit \
  /var/log/nginx \
);

adduser -S -D -H -u 101 -h /usr/local/nginx -s /sbin/nologin -G www-data -g www-data www-data

for dir in "${writeDirs[@]}"; do
  mkdir -p ${dir};
  chown -R www-data:www-data ${dir};
done

rm -rf /etc/nginx/owasp-modsecurity-crs/.git
rm -rf /etc/nginx/owasp-modsecurity-crs/tests

# remove .a files
find /usr/local -name "*.a" -print | xargs /bin/rm
