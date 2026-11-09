# tegra124-udi-tk1-iqyi-base-a02 —— 主线风格设备树（tegra124-platforms/ 分文件结构）

由设备原厂 DTB（`dtb-baseline-ok.bin`，41774 字节 / 396 节点）反编译后**重写**成
可读的 DTS 源码。原始来源是
`arch/arm/boot/dts/tegra124-tn8-p1761-1470-a00.dts`（boardid `1761:1470:0`）。

> **节点名保持原厂形态**（`/pinmux`、`/clock`、`/host1x`、`/i2c@7000d000/tps65913`），
> 不补 `@unit-address`。原因是 Tegra cboot 按固定路径读节点，改名会直接 boot loop
> —— 详见下文「为什么节点名必须保持原厂形态」。

文件组织照**小米平板1（mocha）那套 NVIDIA 下游内核的分法**：

```
tegra124-udi-tk1-iqyi-base-a02.dts              板级入口：model/compatible/aliases/chosen/memory
tegra124.dtsi                       SoC 通用部分
tegra124-platforms/
    tegra124-udi-tk1-iqyi-base-a02-pinmux.dtsi          引脚复用三张表
    tegra124-udi-tk1-iqyi-base-a02-gpio-default.dtsi    GPIO 上电初值
    tegra124-udi-tk1-iqyi-base-a02-power-tree.dtsi      电源树 / palmas PMIC / bq2419x
    tegra124-udi-tk1-iqyi-base-a02-comms.dtsi           UART / i2c0·i2c3 / spi / xusb
    tegra124-udi-tk1-iqyi-base-a02-sensor.dtsi          传感器（本板为空，见文件内说明）
    tegra124-udi-tk1-iqyi-base-a02-hdmi.dtsi            HDMI
    tegra124-udi-tk1-iqyi-base-a02-sd.dtsi              SD / eMMC（本板为空，见文件内说明）
    tegra124-udi-tk1-iqyi-base-a02-keys.dtsi            按键
    tegra124-udi-tk1-iqyi-base-a02-misc.dtsi            pwm / 灯 / 蜂鸣器 / 风扇
```

换板子时复制一份 `tegra124-platforms/` 目录改名即可，`tegra124.dtsi` 直接复用。

## 产物

| 文件 | 说明 |
|---|---|
| `tegra124-udi-tk1-iqyi-base-a02.dts` | 板级入口，80 行（model/compatible/aliases/chosen/memory + 9 个 `#include`） |
| `tegra124.dtsi` | SoC 通用部分，350 行（gic/lic/armv7-timer/gpio/se/car/apbdma/pinmux 控制器/serial/i2c/pwm/spi/pmc/clocks/nvtimer/rtc/host1x 及子模块/xusb/mipical） |
| `tegra124-platforms/*.dtsi` | 板级 9 个分文件，合计约 2500 行（见上表） |
| `tegra124-ardbeg-tv.dts.bak-before-platforms` | 拆成 tegra124-platforms 之前的板级单文件版，2579 行，留档 |
| `tegra124-ardbeg-tv.dts.bak-before-split` | 最初的完全单文件版本，2837 行，留档 |
| `tegra124-udi-tk1-iqyi-base-a02.dtb` | 回编译产物，41092 字节，与原厂 DTB **语义完全一致**，已于 2026-11-09 刷入设备验证（25 秒启动） |
| `dtb-flash-platforms-4M.bin` | 4 MB 刷机镜像（DTB + 零填充），md5 `f78c0268beea0a815304f1a63dd326e8`，同上已验证 |
| `tegra124-udi-tk1-iqyi-base-a02-compat.dts` | **单文件**版本，2818 行，节点名与原厂一致；`dtb2mainline.py --keep-node-names` 直接产出，用于对照/回退 |
| `tegra124-udi-tk1-iqyi-base-a02-compat.dtb` | 单文件版编译产物，41243 字节，语义与原厂一致 |
| `dtb-baseline-ok.bin` | 设备原厂 DTB 分区 dump（4 MB），**基准**，所有比对都对着它做 |
| `tegra124-ardbeg-tv.dts.map.json` | 旧节点路径 → 新节点路径 映射表 |
| `dtb2mainline.py` | DTB → 主线风格 DTS 生成器 |
| `compare_dtb.py` | 语义等价性校验工具 |
| `build.sh` | 一键编译（自动挑预处理器和 dtc，见下节） |
| `preprocess.py` | 专用 C 预处理器，无 gcc/clang 时替代 cpp |
| `tools/dtc` + `tools/lib/libyaml-0.so.2` | 随包附带的 dtc 1.8.1，不依赖系统 |
| `dtbinds/` | `dt-bindings/` 头文件副本 |

## 三层怎么分工

| `tegra124.dtsi`（芯片侧） | `tegra124-platforms/*`（板级） |
|---|---|
| `compatible` / `reg` / `interrupts` / `#xxx-cells` / `clocks` / `ranges` | `status`（SoC 侧默认 `disabled`，板级打开） |
| `nvidia,dma-request-selector`、`nvidia,memory-clients` | `clock-frequency`、`spi-max-frequency`、`scl-gpio`/`sda-gpio` |
| `reg-shift`、host1x 及其子模块 | pinmux 三张表、`gpio-init-*` / `gpio_default` |
| pinmux 控制器本体（无 pin 组） | palmas PMIC 子树、bq2419x、`regulators`、`gpio-keys`、`pwm-*` |
| — | xusb 的 portmap 与 supply 映射 |

`tegra124-udi-tk1-iqyi-base-a02.dts` 里只剩板子身份：`model` / `compatible` / `aliases` /
`chosen` / `memory`，以及 9 个 `#include`。

归属约定：**谁拥有器件，谁拥有那条总线** —— i2c1（充电器）、i2c4（PMIC）整个
节点写在 `-power-tree.dtsi`，其余总线在 `-comms.dtsi`。同一个节点被两个 dtsi
同时覆盖也可以（dtc 会合并），只是不利于阅读，尽量别这么干。

注意 `tegra124.dtsi` **不是** `arch/arm/boot/dts/tegra124.dtsi`：主线那份用
`dmas`/`resets`/`clocks` 新 binding 且节点挂在 `/soc` 下（路径不同），喂给 3.10
内核会全崩。本文件刻意保持 3.10 下游 binding 与扁平节点路径。

`&label` 覆盖写法是 mainline 的做法，NVIDIA 下游原版用的是 `/ { i2c@7000c000 { ... } }`
这种路径写法。两者编译结果一样；这里用 label，是因为节点改名时 dtc 会直接报错，
路径写法会静默新建一个节点。

## 刷入与校验

`dtb-flash-platforms-4M.bin` = DTB 放 offset 0 + 零填充到 4194304 字节（DTB 分区
大小），和 `dtb-flash*-4M.bin` 那批同构。

```sh
cd "/home/dy/WorkBuddy AI/k1flash"
sudo bash flash-dtb-platforms.sh            # 刷 + 校验一条龙
sudo bash flash-dtb-platforms.sh ./dtb-flash-ch3-4M.bin   # 回滚到已验证版本
```

脚本流程：查镜像（大小 / magic `d00dfeed`）→ 等 APX（`0955:xxxx`，240s）→
`nvflash --bct --bl --download 15 --go` → 等 adb 回来 → 回读 `/proc/device-tree`
逐项比对（model / 节点总数 397 / pinmux `common` 121 组 / `drive` 3 组 /
regulators 7 个 / gpio-keys 2 个 / palmas 15 路 regulator / smps6=vdd-core /
hdmi=okay）→ 抓 dmesg 里的 pinmux / palmas / not found 报错。

进 APX：设备断电 → 按住【音量+】→ 插 USB → 保持 3 秒后松开，`lsusb` 应见 `0955:7f40`。

**必须自己开终端跑 sudo**：本机没有 `0955` 的 udev 规则，`nvflash` 需要 root 才能
访问 usbfs；AI 沙箱里没有 usbfs（会 SIGSYS 被杀）。

## 构建方法

**一条命令，解压即可编译：**

```sh
./build.sh
```

不需要装 gcc/clang/dtc —— 全部随包附带：

| 依赖 | 来源 |
|---|---|
| `dtc` 1.8.1 | `tools/dtc`（164 KB，x86-64）+ `tools/lib/libyaml-0.so.2` |
| C 预处理器 | 有 `cc`/`gcc`/`clang`/`zig` 就用；**都没有则用 `preprocess.py`**（只要 python3） |
| `dt-bindings/` 头文件 | `dtbinds/` |

脚本三级回退，顺序是：`$CC` → `cc`/`gcc`/`clang`/`zig` → `python3 preprocess.py`。

### 为什么必须两段式

`dtc` 自带的预处理器不支持**函数式宏**。本 DTS 里有 4 种、共 65 处：

| 宏 | 出现次数 | 展开成 |
|---|---|---|
| `TEGRA_GPIO(bank, off)` | 58 | `((TEGRA_GPIO_BANK_ID_##bank * 8) + off)` |
| `GIC_CPU_MASK_SIMPLE(n)` | 3 | `(((1 << (n)) - 1) << 8)` |
| `GIC_CPU_MASK_RAW(x)` | 2 | `((x) << 8)` |
| `MATRIX_KEY(r, c, code)` | 2 | `(((r & 0xFF) << 24) \| ((c & 0xFF) << 16) \| (code & 0xFFFF))` |

直接 `dtc -I dts` 会在 `TEGRA_GPIO(` 处报 `syntax error`。

### preprocess.py 是什么

一个 200 行的专用预处理器，只实现 DTS 真正用到的那一小撮特性：

```
#include "file"   #include <file>   #define 对象宏/函数宏(含 ## 拼接)
#ifndef / #endif（仅 include guard）    其它 # 开头的行原样输出
```

最后一条很关键：`#address-cells` / `#size-cells` / `#gpio-cells` 这些 **dtc 属性名**
也以 `#` 开头，必须原样保留。gcc 在 `-x assembler-with-cpp` 模式下正是这么做的
（不认识的 `#` 行保留），所以这里行为一致。

**正确性已验证**：用 `zig cc -E`（真 cpp）和 `preprocess.py` 分别预处理同一份
DTS，归一化空白与行标记后 **2463 行逐字符相同，diff 为空**；两者编出的 DTB
md5 都是 `c89abe263e6bcd134fc7e2c6d6a015a1`。

### 想用自己内核树的头文件

把 `-Idtbinds` 换成内核的 `include` 目录即可：

```sh
CC=gcc ./build.sh                       # 强制用真 cpp
DTC=/usr/bin/dtc ./build.sh             # 强制用系统 dtc
```

手动两步（等价于 build.sh 干的事）：

```sh
cpp -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp \
    -I. -Idtbinds -o /tmp/pre.dts tegra124-udi-tk1-iqyi-base-a02.dts
dtc -I dts -O dtb -o tegra124-udi-tk1-iqyi-base-a02.dtb /tmp/pre.dts
```

（`dtbinds/dt-bindings/` 是工作区里备好的一份头文件副本，等价于内核的
`include/dt-bindings/`。`<overlay>` 需要放一个 `dt-bindings/input/linux-event-codes.h`，
本机 3.10 内核树只有旧名字 `dt-bindings/input/input.h`，内容一样，`KEY_POWER`=116。）

### 关于 dtc 的警告

编译会刷一屏 `unit_address_vs_reg` 和 `alias_paths` 警告，**全部是刻意保留的**，
原因见下一节。只关心有没有真正失败，看最后的 md5 即可。

## 转换规则

| 原写法 | 新写法 |
|---|---|
| `interrupt-parent = <0x01>` | `<&gic>` |
| `pinctrl-0 = <0x03>` | `<&pinmux_default>` |
| `gpios = <0x07 0x80 0x01>` | `<&gpio TEGRA_GPIO(Q, 0) GPIO_ACTIVE_LOW>` |
| `interrupts = <0x00 0x4b 0x04>` | `<GIC_SPI 75 IRQ_TYPE_LEVEL_HIGH>` |
| `interrupts = <0x01 0x0d 0xf04>` | `<GIC_PPI 13 (GIC_CPU_MASK_SIMPLE(4) \| IRQ_TYPE_LEVEL_HIGH)>` |
| `nvidia,enable-input = <0x00>` | `<TEGRA_PIN_DISABLE>` |
| `nvidia,pull = <0x01>` | `<TEGRA_PIN_PULL_DOWN>` |
| `nvidia,low-power-mode = <0x03>` | `<TEGRA_PIN_LP_DRIVE_DIV_1>` |
| `linux,code = <0x74>` | `<KEY_POWER>` |
| `clocks = <0x0f 0x105 0x10>` | `<&tegra_car 261>, <&clk32k_in>` |
| `nvidia,dma-request-selector = <0x06 0x08>` | `<&apbdma 8>` |
| `phandle = <0x07>` | 删除（改由 label 引用，dtc 自动分配） |

其他整理：属性按 `dts-coding-style` 排序（`compatible` → `reg` → 总线/中断/时钟 →
其余字母序 → `status` 置末）；`reg` 按 `#address-cells + #size-cells` 成对分行；
`interrupts` 每条一行；`nvidia,dtsfilename` / `nvidia,boardids` 丢弃。

## 为什么节点名必须保持原厂形态（不要补 unit-address）

**2026-11-09 实测教训**：把节点名按主线规范补成 `@unit-address` 后刷入，设备直接
boot loop，USB 完全不枚举（kernel 根本没起来）。

原因：Tegra 的 cboot 在拉起内核**之前**就按固定路径读设备树 ——

- `/pinmux` —— 用来配引脚（改了名字它就找不到）
- `/clock` —— 时钟
- `nvidia,boardids`（`1761:1470:0`）—— 用来匹配板子

三者任一被破坏都会卡死。所以下面这些操作**都不能做**：

| 不能做 | 后果 |
|---|---|
| 给节点补 `@unit-address` | cboot 找不到 `/pinmux`、`/clock` |
| 套 `RENAME`（`tps65913`→`pmic@58`、`/memory`→`/memory@0` 等） | 同上 |
| 丢掉 `nvidia,boardids` / `nvidia,dtsfilename` | cboot 无法匹配板子 |

`dtb2mainline.py` 的 **`--keep-node-names`** 开关就是为此加的：节点名一律用 DTB
原名、不补地址、只丢 `phandle`（保留 boardids）。重新生成 DTS 时务必带上它：

```sh
python3 dtb2mainline.py --keep-node-names <in.dtb> <out.dts>
```

配套校验方法也要改：必须用**恒等映射**比对（节点路径集合 `a == b` 为 True），
不能用 map.json 映射 —— 后者路径变了也能"对上"，正是它漏掉了这个问题。

## 刻意保留的下游 binding

这些属性主线没有对应实现，改成主线写法会直接打断现有 3.10 驱动，故原样保留：

- `nvidia,dma-request-selector`（主线是 `dmas` + `dma-names`）
- `nvidia,memory-clients`
- `gpio-init-names` / `gpio-init-N`（tegra_gpio_init 专用）
- `nvidia,require-cldvfs-clock`、`nvidia,bit-banging-xfer-after-shutdown`
- `consumers` / `regulator-consumer-supply` / `regulator-consumer-device`
- `pwm-beeper` 的 `max_volume`、`pwm-fan` 的 `max_speed`（主线没有）

时钟 / 复位 ID 保持数字，因为本机没有 `include/dt-bindings/clock/tegra124-car.h`，
换成 `TEGRA124_CLK_*` 有写错的风险。实际用到的只有：`RTC=4`、`TIMER=5`、`PCLK=261`。

## 校验结果

最终版本对着**设备原厂 DTB**（`dtb-baseline-ok.bin`，从设备 `mmcblk0p8` 直接 dump）
做恒等映射比对：

```
原厂节点 396   新版节点 396
只在原厂: []    只在新版: []
路径完全一致: True

nodes: orig=396 new=396   props compared=1548
OK: 语义完全一致
```

| 对比 | 结果 |
|---|---|
| `tegra124.dtsi` + `tegra124-platforms/` vs 设备原厂 DTB | 节点路径 396/396 完全相同，1548 条属性逐条一致 |
| `tegra124-udi-tk1-iqyi-base-a02-compat.dts`（单文件）vs 设备原厂 DTB | 396/396，1550 条属性一致 |
| 拆分版 vs 单文件版 | 节点集合相同（拆分版少 2 条根属性，见下） |

两者 dtc 产物分别为 41092 / 41243 字节（原厂 41774）。字节层面不是逐字节相同：
属性在节点内的顺序跟着源文件顺序走，字符串表顺序随之变化，但节点路径与属性值
全部相同 —— 对内核没有任何影响。

**刷入验证（2026-11-09）**：拆分版镜像 `f78c0268…` 写入 `mmcblk0p8` → 回读 md5 一致
→ reboot → **25 秒 adb 回来**，`/proc/device-tree/model` = `NVIDIA Tegra124 TN8 FFD`，
`/pinmux`（common 122 / drive 5 / unused_lowpower 72）、`/clock`、`/host1x`、`/pmc`、
`/rtc`、`/mipical`、`/regulators`、`/gpio-keys`、`/memory` 全部在，dmesg 无新增错误。

原始 v8c → 单文件版的历史校验结果（phandle 数字变了不算差异）：

```
nodes: orig=396 new=396   props compared=1547
OK: 语义完全一致
```

`compare_dtb.py` 逐节点逐属性比对两个 DTB，phandle 数字变了不算差异（只要指向的
节点路径一致），其余任何一个字节不同都会报错。

dtc 只剩 3 类警告，都是原 DTB 自带的：

- `alias_paths` ×7 —— `i2c2`/`i2c5`/`serial3`/`spi1`/`spi2`/`spi4`/`spi5` 指向的
  节点在裁剪时已删除。**故意保留**：Tegra i2c/spi 驱动靠 aliases 名字分配总线号，
  删掉会导致 `/dev/i2c-N` 编号整体前移。
- `interrupt_provider` ×1 + `interrupt_map` ×1 —— LIC（`interrupt-controller@60004000`）
  原本就没有 `#interrupt-cells`，原样保留。

## 还没做的

结构上已经是 `tegra124.dtsi` + `tegra124-platforms/` 分文件（小米平板1那套分法），
但**节点仍是扁平的、binding 仍是 3.10 下游的**，离真正 upstream 还差三步：

1. `tegra124.dtsi` 里的 SoC 节点要挂到 `/soc` 下（`simple-bus`，`ranges` 映射），
   这会改节点路径，`aliases` 里的绝对路径和 `of_find_node_by_path()` 都要跟着改；
2. binding 换成主线：`clocks`/`resets` 用 `TEGRA124_CLK_*`（需要
   `include/dt-bindings/clock/tegra124-car.h`）、`nvidia,dma-request-selector`
   → `dmas`/`dma-names`、`nvidia,memory-clients`/`gpio-init-*`/`consumers` 等
   下游私有属性全部删除；
3. 最后才是把驱动也换成主线版本 —— 只改 DTS 不改驱动，3.10 内核会直接不认。

换句话说：现在这份是「结构可复用」，但还**不能**直接 upstream。

## 关于 therm_est probe 失败（-22）

这条**不是设备树问题，改 DTS 改不掉**，详见 `therm_est-zone-name-fix.patch`。要点：

- `therm_est` 是板级代码 `platform_device_register()` 注册的静态设备，
  `/sys/devices/platform/therm_est/of_node` 不存在，probe 全程不读 DT。
- 失败原因是 `tn8ffd_skin_devs[]` 里的热区名 `"Tdiode"/"Tboard"` 与实际热区
  `Tdiode_tegra/Tboard_tegra` 对不上，而 `therm_est_subdev_match()` 是 `strcmp` 精确比较。
- `generic-adc-thermal` 驱动没有 `of_match_table`，只能由 board 代码带
  `platform_data`（含函数指针 `adc_to_temp`）实例化，DTS 无法创建它。
- 真正的修复是改 `board-ardbeg-sensors.c` 两行字符串后重编内核；当前设备跑的是
  原厂 `3.10.24-g1fc624e`，工作区没有对应源码树，暂不可编。
- 影响面仅限 skin 温度估算节流；soctherm 四区 + nct72 两区 + pwm-fan 均正常。
