1) Version History
	
	
	version efx_ti60f225_oob_v3_1 data: 2023/02/10

	a) SD host Clock speed changed to 10Mhz.
	b) IP Updated 
	   i) Hyperram Controller  -> V2.4
	   ii)sd host Controller  -> V1.3
	   iii) sapphire Soc -> V2.2.3
	c) Updated SOC application to Efinity RISC-V IDE (preserved Legacy folder)  

	version efx_ti60f225_oob_v3 data: 2022/12/29
	a) Updated MIPI dsi controller which was provided by IPM.
	b) IP Updated 
	   i) SD host Controller  -> V1.2
	   ii)DMA Controller  -> V1.3
	   iii) apb3 to axi4 lite -> V1.2
	   iv) csi RX controller -> V2.1
	   v) sapphire Soc -> V2.2.2
	c) Registers on apb3_salve was fixed to "registers" Mode ramstyle.   
	
	
	version efx_ti60f225_oob_v2_3 data: 2022/08/15
	a) add the include file "hyperram_controller_define.vh" in the source top_soc_oob.v .

	version efx_ti60f225_oob_v2_2 data: 2022/07/05
    a) remark the include file "hyperram_controller_define.vh" in the source top_soc_oob.v which is already defined the project .

	version efx_ti60f225_oob_v2_1 data: 2021/12/9
	a)Updated the DMA_controller(IPM) to V1.1

	version efx_ti60f225_oob_v2_0 data: 2021/12/6
	a) Updated the Sapphire SOC to V2.0
	b) Updated the HyperRam to V2.0
	c) Firmware Updated for using riscv_sdk V1.4
	d) Updated Project Files hierarchy  

 	version efx_ti60f225_oob_v1_4 data: 2021/11/8
	a) Build for TI60f225 RevA Development Board
	b) updated the file name of FX3 biniary to TI60F225_OOB_UVC.img

    version efx_ti60f225_oob_v1_3A data: 2021/11/4
	a) Build for TI60f225 RevA Development Board
	b) Added UVC binary for the FX3 Usb3.0 Controller
	c) Update Hyper Controller IP

    version efx_ti60f225_oob_v1_3 data: 2021/11/4
	a) Added UVC binary for the FX3 Usb3.0 Controller
	b) Update Hyper Controller IP

    version efx_ti60f225_oob_v1_2A data: 2021/10/25
	a) Build for TI60f225 RevA Development Board
	b) Fixed SOC FW SD Card Error Indication

    version efx_ti60f225_oob_v1_1A data: 2021/10/11
	a) Build for TI60f225 RevA Development Board
	b) Code optimized

    version efx_ti60f225_oob_v1_1 data: 2021/10/20
	a) Code optimized

    version efx_ti60f225_oob_v1_0A data: 2021/10/11
	a) RTL Build by Efinity 2021.1.165.3.18
	b) Build for TI60f225 RevA Development Board
	c) Firmware build by RISC-V SDK	v1.3

    version efx_ti60f225_oob_v1_0 data: 2021/09/24
	a) Inital Release 
	b) RTL Build by Efinity 2021.1.165.3.9
	c) Firmware build by RISC-V SDK	v1.3

2) Hardware design Project folder:
	\
   Hardware Bitstream for spi flash programming at Address 0x000000
	\ti60f225_oob.hex
   Hardware Bitstream for jtag
	\ti60f225_oob.bin

3) Software workspace folder:
	\embedded_sw\sapphire_soc
   Software Project folder:
	\embedded_sw\sapphire_soc\software\standalone\ti60f225_oob
   Software Bitstream for spi flash programming at Address 0x380000
	\embedded_sw\bin\EFX_HEX_ti60f225_oob.hex 
   Software Debug file 
	\embedded_sw\bin\ti60f225_oob.elf

4) Demo operation
  i)    For download the bitstream of the example 
	a) open the Efinity programmer form Efinity software.  
	b) select the RTL bitstream of the following path
		\ti60f225_oob.hex
	c) select Programming Mode to spi active mode. 
	d) confirm the Starting flash Address is 0x000000
	e) click start program.
	f) when the programming was done, you can download the binary of the SOC Firmware.
	g)  select the FW binary of the following path.
		\embedded_sw\bin\EFX_HEX_ti60f225_oob.hex 
	h) select Programming Mode to spi active mode.
	i) Change the Starting flash Address to 0x380000
	k) click start program.

  ii)	Please read the opeartion of the example demo form the document "Titanium Ti60 F225 Development Kit User Guide" form our website. 
    https://www.efinixinc.com/docs/ti60f225-devkit-ug-v1.0.pdf

5) For running FW on Eclipse
	a) Please read the sapphire soc user gudie document frmom our website. 
	https://www.efinixinc.com/docs/riscv-sapphire-ug-v2.0.pdf
	b) For loading the example FW. 
	   i) we suggest workspace folder is 
		\embedded_sw\sapphire_soc
	   ii) create a new project with markfile form following folder. 
		\embedded_sw\sapphire_soc\software\standalone\ti60f225_oob



