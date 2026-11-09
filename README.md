tegra124-udi-tk1-iqyi-base-a02 —— 主线风格设备树（tegra124-platforms/ 分文件结构）

由设备原厂 DTB（dtb-baseline-ok.bin，41774 字节 / 396 节点）反编译后重写成 可读的 DTS 源码。原始来源是 arch/arm/boot/dts/tegra124-tn8-p1761-1470-a00.dts（boardid 1761:1470:0）。

    节点名保持原厂形态（/pinmux、/clock、/host1x、/i2c@7000d000/tps65913）， 不补 @unit-address。原因是 Tegra cboot 按固定路径读节点，改名会直接 boot loop —— 详见下文「为什么节点名必须保持原厂形态」。
