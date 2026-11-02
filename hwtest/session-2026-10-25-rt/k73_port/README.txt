ADI AD9361 / AXI ADC / AXI DDS driver port to Linux 7.3.0-rc7 (Pluto+), 2026-10-30
0001-adi-ad9361-axi-drivers-for-7.3-rc7.patch  applies with patch -p1 on a pristine v7.3-rc7 tree (checked with --dry-run on the touched files).
  new files copied from the ADI 6.12 tree (mbehn1976/linux 678c4de70fdf), with these changes for 7.x:
   - ad9361.c: stale <linux/of_gpio.h> include removed; clk round_rate -> determine_rate wrappers; bin_attribute callbacks take const
   - clk-adjustable-rate.c: round_rate -> determine_rate
   - cf_axi_adc_core.c: write_event_config takes bool; MODULE_IMPORT_NS("...") string syntax (also cf_axi_dds.c)
   - cf_axi_dds_buffer_stream.c: ADI dmaengine submit/abort hooks removed (only drive the PL DDR FIFO, not used on the Pluto+), mainline devm_iio_dmaengine_buffer_setup_ext
   - existing files extended: adi-axi-common.h (ADI_AXI_REG_ID etc.), iio/types.h + industrialio-core.c (IIO_CHAN_INFO_CALIBPHASE "calibphase")
  not included: the temporary debug prints in chipidea core.c, spi-nor core.c and spi-zynq-qspi.c.
k73_pluto_rt_adi.config  the kernel config of the booted image
zynq-plutoplus.dtsi.7.3  Pluto+ dtsi with the USB PHY fix (usb-nop-xceiv node, phys = <&usb_phy0>, reset-gpios flag 1)
Still needed outside this patch: ADI zynq.dtsi / zynq-7000.dtsi for the device tree, QSPI (>16 MiB flash) handling, libiio local buffer API check, TX and drop tests.
