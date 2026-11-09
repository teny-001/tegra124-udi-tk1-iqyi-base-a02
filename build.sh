#!/bin/sh
# 编译 tegra124-udi-tk1-iqyi-base-a02.dts -> .dtb
#
# 解压即可编译，不依赖系统装任何东西：
#   - dtc          随包附带  tools/dtc + tools/lib/libyaml-0.so.2
#   - C 预处理器   有 cc/gcc/clang/zig 就用；没有则用包内 preprocess.py（需 python3）
#
# 用法：
#   ./build.sh
#   CC=gcc ./build.sh
#   CC="zig cc" DTC=/usr/bin/dtc ./build.sh
#
# 为什么必须两段式：dtc 自带的预处理器不支持 TEGRA_GPIO() 这类函数式宏，
# 必须先过 C 预处理展开，再交给 dtc。
set -e
NEW=tegra124-udi-tk1-iqyi-base-a02
DIR=$(cd "$(dirname "$0")" && pwd)
cd "$DIR"

# ---------- 1) 选 C 预处理器 ----------
# PRE_KIND: cpp = 用真实 C 编译器；py = 用包内 preprocess.py
PRE_KIND=
PRE_CMD=
if [ -n "$CC" ]; then
    PRE_KIND=cpp; PRE_CMD="$CC"
elif command -v cc >/dev/null 2>&1; then
    PRE_KIND=cpp; PRE_CMD=cc
elif command -v gcc >/dev/null 2>&1; then
    PRE_KIND=cpp; PRE_CMD=gcc
elif command -v clang >/dev/null 2>&1; then
    PRE_KIND=cpp; PRE_CMD=clang
elif command -v zig >/dev/null 2>&1; then
    PRE_KIND=cpp; PRE_CMD="zig cc"
elif command -v python3 >/dev/null 2>&1 && [ -f "$DIR/preprocess.py" ]; then
    PRE_KIND=py
else
    echo "错误：既没有 C 编译器（cc/gcc/clang/zig），也没有 python3 + preprocess.py。"
    echo "      装其中任意一个，或用 CC=/path/to/cc ./build.sh 指定。"
    exit 1
fi

# ---------- 2) 选 dtc：优先用包里自带的 ----------
if [ -z "$DTC" ]; then
    if [ -x "$DIR/tools/dtc" ]; then
        DTC="$DIR/tools/dtc"
        export LD_LIBRARY_PATH="$DIR/tools/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    elif command -v dtc >/dev/null 2>&1; then
        DTC=dtc
    else
        echo "错误：包里没有 tools/dtc，系统也没有 dtc。"
        exit 1
    fi
fi

# ---------- 3) 两段式编译 ----------
TMP=$(mktemp -d 2>/dev/null || echo /tmp)
trap 'rm -rf "$TMP"' EXIT
PRE_DTS="$TMP/$NEW.pre.dts"

if [ "$PRE_KIND" = py ]; then
    echo "[1/2] 预处理   (内置 preprocess.py)"
    python3 "$DIR/preprocess.py" -I. -Idtbinds -o "$PRE_DTS" "$NEW.dts"
else
    echo "[1/2] 预处理   (cpp: $PRE_CMD)"
    # 注意：$PRE_CMD 故意不加引号，好让 "zig cc" 拆成两个词
    $PRE_CMD -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
        -I. -Idtbinds -o "$PRE_DTS" "$NEW.dts"
fi

echo "[2/2] dtc 编译 ($DTC)"
"$DTC" -I dts -O dtb -o $NEW.dtb "$PRE_DTS"

SIZE=$(wc -c < $NEW.dtb)
MD5=$(md5sum $NEW.dtb | cut -d' ' -f1)
echo
echo "完成: $NEW.dtb  $SIZE 字节  md5=$MD5"
echo "注：dtc 会报若干 unit_address_vs_reg 警告，这是刻意保留的 —— 补上 @地址会让"
echo "    Tegra cboot 找不到 /pinmux、/clock，设备直接起不来。详见 README。"
