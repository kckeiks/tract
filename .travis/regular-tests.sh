#!/bin/sh

if [ -e /proc/cpuinfo ]
then
    grep "^flags" /proc/cpuinfo | head -1 | \
        grep --color=always '\(s\?sse[0-9_]*\|fma\|f16c\|avx[^ ]*\)'
fi

set -ex

which rustup || curl https://sh.rustup.rs -sSf | sh -s -- -y
rustup update

PATH=$PATH:$HOME/.cargo/bin

if [ ${RUST_VERSION:=stable} != "stable" ]
then
    rustup toolchain add $RUST_VERSION
fi
export RUSTUP_TOOLCHAIN=$RUST_VERSION

rustc --version

if [ `uname` = "Darwin" ]
then
    sysctl -n machdep.cpu.brand_string
    brew install coreutils
    PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
else
    sudo apt-get install -y llvm 
fi

if [ -z "$CACHEDIR" ]
then
    CACHEDIR=$(realpath `dirname $0`/../.cached)
fi

export CACHEDIR

if [ `arch` = "x86_64" -a "$RUST_VERSION" = "stable" ]
then
    ALL_FEATURES=--all-features
fi

for c in data linalg core nnef hir onnx pulse onnx-opl pulse-opl rs proxy
do
    cargo -q test $CARGO_EXTRA -q -p tract-$c
done

for c in test-rt/test*
do
    (cd $c; cargo test -q $CARGO_EXTRA)
done

# doc test are not finding libtensorflow.so
if ! cargo -q test $CARGO_EXTRA -q -p tract-tensorflow --lib $ALL_FEATURES
then
    # this crate triggers an incremental bug on nightly.
    cargo clean -p tract-tensorflow
    cargo -q test $CARGO_EXTRA -q -p tract-tensorflow --lib $ALL_FEATURES
fi

if [ -n "$SHORT" ]
then
    exit 0
fi

# if [ -n "$GITHUB_ACTIONS" ]
# then
#     CLEANUP="rm -rf $CACHEDIR/*"
# else
     CLEANUP=true
# fi

$CLEANUP
cargo -q test $CARGO_EXTRA -q -p tract-rs
$CLEANUP
cargo -q test $CARGO_EXTRA -q --profile opt-no-lto -p core-proptest-pulse $ALL_FEATURES
$CLEANUP
cargo -q test $CARGO_EXTRA -q --profile opt-no-lto -p lstm-proptest-onnx-vs-tf $ALL_FEATURES
$CLEANUP
cargo -q test $CARGO_EXTRA -q --profile opt-no-lto -p nnef-inceptionv3 $ALL_FEATURES
$CLEANUP
cargo -q test $CARGO_EXTRA -q --profile opt-no-lto -p tf-inceptionv3 $ALL_FEATURES
$CLEANUP
cargo -q test $CARGO_EXTRA -q --profile opt-no-lto -p tf-mobilenet-v2 $ALL_FEATURES
$CLEANUP
cargo -q test $CARGO_EXTRA -q --profile opt-no-lto -p tf-moz-deepspeech $ALL_FEATURES
CACHEDIR=$OLD_CACHEDIR
