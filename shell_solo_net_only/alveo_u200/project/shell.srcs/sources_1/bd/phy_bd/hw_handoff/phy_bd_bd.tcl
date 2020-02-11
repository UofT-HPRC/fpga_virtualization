
################################################################
# This is a generated script based on design: phy_bd
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2019.1
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_msg_id "BD_TCL-109" "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source phy_bd_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xcu200-fsgd2104-2-e
   set_property BOARD_PART xilinx.com:au200:part0:1.3 [current_project]
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name phy_bd

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_msg_id "BD_TCL-001" "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_msg_id "BD_TCL-002" "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_msg_id "BD_TCL-003" "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_msg_id "BD_TCL-004" "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_msg_id "BD_TCL-005" "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_msg_id "BD_TCL-114" "ERROR" $errMsg}
   return $nRet
}

##################################################################
# DESIGN PROCs
##################################################################


# Hierarchical cell: qsfp0
proc create_hier_cell_qsfp0 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_msg_id "BD_TCL-102" "ERROR" "create_hier_cell_qsfp0() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 axis_rx

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 axis_tx

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 qsfp0_156mhz_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 qsfp0_1x_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 refclk_300mhz


  # Create pins
  create_bd_pin -dir O aclk
  create_bd_pin -dir I -type rst aresetn_in
  create_bd_pin -dir O aresetn_out

  # Create instance: GT_clk_sel, and set properties
  set GT_clk_sel [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 GT_clk_sel ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {5} \
   CONFIG.CONST_WIDTH {3} \
 ] $GT_clk_sel

  # Create instance: GT_loopback, and set properties
  set GT_loopback [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 GT_loopback ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {0} \
   CONFIG.CONST_WIDTH {3} \
 ] $GT_loopback

  # Create instance: clk_wiz_0, and set properties
  set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
  set_property -dict [ list \
   CONFIG.CLKIN1_JITTER_PS {33.330000000000005} \
   CONFIG.CLKOUT1_DRIVES {BUFGCE} \
   CONFIG.CLKOUT1_JITTER {107.379} \
   CONFIG.CLKOUT1_PHASE_ERROR {77.836} \
   CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {75} \
   CONFIG.CLKOUT2_DRIVES {BUFGCE} \
   CONFIG.CLKOUT3_DRIVES {BUFGCE} \
   CONFIG.CLKOUT4_DRIVES {BUFGCE} \
   CONFIG.CLKOUT5_DRIVES {BUFGCE} \
   CONFIG.CLKOUT6_DRIVES {BUFGCE} \
   CONFIG.CLKOUT7_DRIVES {BUFGCE} \
   CONFIG.CLK_IN1_BOARD_INTERFACE {default_300mhz_clk0} \
   CONFIG.FEEDBACK_SOURCE {FDBK_AUTO} \
   CONFIG.MMCM_CLKFBOUT_MULT_F {4.000} \
   CONFIG.MMCM_CLKIN1_PERIOD {3.333} \
   CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
   CONFIG.MMCM_CLKOUT0_DIVIDE_F {16.000} \
   CONFIG.PRIM_SOURCE {Differential_clock_capable_pin} \
   CONFIG.RESET_PORT {reset} \
   CONFIG.RESET_TYPE {ACTIVE_HIGH} \
   CONFIG.USE_LOCKED {false} \
   CONFIG.USE_RESET {false} \
   CONFIG.USE_SAFE_CLOCK_STARTUP {true} \
 ] $clk_wiz_0

  # Create instance: ethernet_link_up, and set properties
  set ethernet_link_up [ create_bd_cell -type ip -vlnv xilinx.com:ip:vio:3.0 ethernet_link_up ]
  set_property -dict [ list \
   CONFIG.C_NUM_PROBE_OUT {1} \
   CONFIG.C_PROBE_OUT0_INIT_VAL {0x1} \
 ] $ethernet_link_up

  # Create instance: ipg_value, and set properties
  set ipg_value [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 ipg_value ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {8} \
   CONFIG.CONST_WIDTH {4} \
 ] $ipg_value

  # Create instance: maxTU, and set properties
  set maxTU [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 maxTU ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {1500} \
   CONFIG.CONST_WIDTH {15} \
 ] $maxTU

  # Create instance: minTU, and set properties
  set minTU [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 minTU ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {64} \
   CONFIG.CONST_WIDTH {8} \
 ] $minTU

  # Create instance: one, and set properties
  set one [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 one ]

  # Create instance: preamble, and set properties
  set preamble [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 preamble ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {0} \
   CONFIG.CONST_WIDTH {56} \
 ] $preamble

  # Create instance: proc_sys_reset_0, and set properties
  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]
  set_property -dict [ list \
   CONFIG.C_AUX_RST_WIDTH {1} \
   CONFIG.C_EXT_RST_WIDTH {1} \
 ] $proc_sys_reset_0

  # Create instance: util_reduced_logic_0, and set properties
  set util_reduced_logic_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_reduced_logic:2.0 util_reduced_logic_0 ]
  set_property -dict [ list \
   CONFIG.C_SIZE {1} \
 ] $util_reduced_logic_0

  # Create instance: util_reduced_logic_1, and set properties
  set util_reduced_logic_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_reduced_logic:2.0 util_reduced_logic_1 ]
  set_property -dict [ list \
   CONFIG.C_SIZE {2} \
 ] $util_reduced_logic_1

  # Create instance: util_vector_logic_0, and set properties
  set util_vector_logic_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_0 ]
  set_property -dict [ list \
   CONFIG.C_OPERATION {not} \
   CONFIG.C_SIZE {1} \
   CONFIG.LOGO_FILE {data/sym_notgate.png} \
 ] $util_vector_logic_0

  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]

  # Create instance: xxv_ethernet_1, and set properties
  set xxv_ethernet_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xxv_ethernet:3.0 xxv_ethernet_1 ]
  set_property -dict [ list \
   CONFIG.BASE_R_KR {BASE-R} \
   CONFIG.DIFFCLK_BOARD_INTERFACE {qsfp0_156mhz} \
   CONFIG.ETHERNET_BOARD_INTERFACE {qsfp0_1x} \
   CONFIG.INCLUDE_AXI4_INTERFACE {0} \
   CONFIG.INCLUDE_STATISTICS_COUNTERS {0} \
   CONFIG.INCLUDE_USER_FIFO {1} \
   CONFIG.USE_BOARD_FLOW {true} \
 ] $xxv_ethernet_1

  # Create instance: zero, and set properties
  set zero [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 zero ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {0} \
 ] $zero

  # Create interface connections
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins qsfp0_1x_0] [get_bd_intf_pins xxv_ethernet_1/gt_serial_port]
  connect_bd_intf_net -intf_net Conn4 [get_bd_intf_pins qsfp0_156mhz_0] [get_bd_intf_pins xxv_ethernet_1/gt_ref_clk]
  connect_bd_intf_net -intf_net axis_tx_1 [get_bd_intf_pins axis_tx] [get_bd_intf_pins xxv_ethernet_1/axis_tx_0]
  connect_bd_intf_net -intf_net refclk_300M_1 [get_bd_intf_pins refclk_300mhz] [get_bd_intf_pins clk_wiz_0/CLK_IN1_D]
  connect_bd_intf_net -intf_net xxv_ethernet_1_axis_rx_0 [get_bd_intf_pins axis_rx] [get_bd_intf_pins xxv_ethernet_1/axis_rx_0]

  # Create port connections
  connect_bd_net -net GT_clk_sel_dout [get_bd_pins GT_clk_sel/dout] [get_bd_pins xxv_ethernet_1/rxoutclksel_in_0] [get_bd_pins xxv_ethernet_1/txoutclksel_in_0]
  connect_bd_net -net GT_loopback_dout [get_bd_pins GT_loopback/dout] [get_bd_pins xxv_ethernet_1/gt_loopback_in_0]
  connect_bd_net -net aresetn_in_1 [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins util_reduced_logic_0/Op1]
  connect_bd_net -net clk_wiz_0_clk_out1 [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins ethernet_link_up/clk] [get_bd_pins xxv_ethernet_1/dclk]
  connect_bd_net -net ethernet_link_up_vio [get_bd_pins ethernet_link_up/probe_in0] [get_bd_pins xxv_ethernet_1/stat_rx_status_0]
  connect_bd_net -net ethernet_resetn_vio [get_bd_pins ethernet_link_up/probe_out0] [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net ext_reset_in_1 [get_bd_pins aresetn_in] [get_bd_pins proc_sys_reset_0/ext_reset_in] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net ipg_value_dout [get_bd_pins ipg_value/dout] [get_bd_pins xxv_ethernet_1/ctl_tx_ipg_value_0]
  connect_bd_net -net maxTU_dout [get_bd_pins maxTU/dout] [get_bd_pins xxv_ethernet_1/ctl_rx_max_packet_len_0]
  connect_bd_net -net minTU_dout [get_bd_pins minTU/dout] [get_bd_pins xxv_ethernet_1/ctl_rx_min_packet_len_0]
  connect_bd_net -net one_dout1 [get_bd_pins one/dout] [get_bd_pins xxv_ethernet_1/ctl_rx_check_preamble_0] [get_bd_pins xxv_ethernet_1/ctl_rx_check_sfd_0] [get_bd_pins xxv_ethernet_1/ctl_rx_delete_fcs_0] [get_bd_pins xxv_ethernet_1/ctl_rx_enable_0] [get_bd_pins xxv_ethernet_1/ctl_rx_process_lfi_0] [get_bd_pins xxv_ethernet_1/ctl_tx_enable_0] [get_bd_pins xxv_ethernet_1/ctl_tx_fcs_ins_enable_0]
  connect_bd_net -net preamble_dout [get_bd_pins preamble/dout] [get_bd_pins xxv_ethernet_1/tx_preamblein_0]
  connect_bd_net -net util_reduced_logic_0_Res [get_bd_pins aresetn_out] [get_bd_pins util_reduced_logic_0/Res]
  connect_bd_net -net util_reduced_logic_1_Res [get_bd_pins util_reduced_logic_1/Res] [get_bd_pins util_vector_logic_0/Op1]
  connect_bd_net -net util_vector_logic_0_Res [get_bd_pins util_vector_logic_0/Res] [get_bd_pins xxv_ethernet_1/rx_reset_0] [get_bd_pins xxv_ethernet_1/sys_reset] [get_bd_pins xxv_ethernet_1/tx_reset_0]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins util_reduced_logic_1/Op1] [get_bd_pins xlconcat_0/dout]
  connect_bd_net -net xxv_ethernet_1_tx_clk_out_0 [get_bd_pins aclk] [get_bd_pins proc_sys_reset_0/slowest_sync_clk] [get_bd_pins xxv_ethernet_1/rx_core_clk_0] [get_bd_pins xxv_ethernet_1/tx_clk_out_0]
  connect_bd_net -net zero_dout1 [get_bd_pins xxv_ethernet_1/ctl_rx_custom_preamble_enable_0] [get_bd_pins xxv_ethernet_1/ctl_rx_data_pattern_select_0] [get_bd_pins xxv_ethernet_1/ctl_rx_force_resync_0] [get_bd_pins xxv_ethernet_1/ctl_rx_ignore_fcs_0] [get_bd_pins xxv_ethernet_1/ctl_rx_test_pattern_0] [get_bd_pins xxv_ethernet_1/ctl_rx_test_pattern_enable_0] [get_bd_pins xxv_ethernet_1/ctl_tx_custom_preamble_enable_0] [get_bd_pins xxv_ethernet_1/ctl_tx_data_pattern_select_0] [get_bd_pins xxv_ethernet_1/ctl_tx_ignore_fcs_0] [get_bd_pins xxv_ethernet_1/ctl_tx_send_idle_0] [get_bd_pins xxv_ethernet_1/ctl_tx_send_lfi_0] [get_bd_pins xxv_ethernet_1/ctl_tx_send_rfi_0] [get_bd_pins xxv_ethernet_1/ctl_tx_test_pattern_0] [get_bd_pins xxv_ethernet_1/ctl_tx_test_pattern_enable_0] [get_bd_pins xxv_ethernet_1/ctl_tx_test_pattern_select_0] [get_bd_pins xxv_ethernet_1/gtwiz_reset_rx_datapath_0] [get_bd_pins xxv_ethernet_1/gtwiz_reset_tx_datapath_0] [get_bd_pins zero/dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: pcie
proc create_hier_cell_pcie { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_msg_id "BD_TCL-102" "ERROR" "create_hier_cell_pcie() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_LITE

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pci_express_x1

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_refclk


  # Create pins
  create_bd_pin -dir O -type clk axi_aclk
  create_bd_pin -dir O axi_aresetn
  create_bd_pin -dir I -type rst pcie_perstn

  # Create instance: pcie_link_up_vio, and set properties
  set pcie_link_up_vio [ create_bd_cell -type ip -vlnv xilinx.com:ip:vio:3.0 pcie_link_up_vio ]
  set_property -dict [ list \
   CONFIG.C_NUM_PROBE_OUT {0} \
 ] $pcie_link_up_vio

  # Create instance: util_ds_buf_0, and set properties
  set util_ds_buf_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.1 util_ds_buf_0 ]
  set_property -dict [ list \
   CONFIG.C_BUF_TYPE {IBUFDSGTE} \
   CONFIG.DIFF_CLK_IN_BOARD_INTERFACE {pcie_refclk} \
 ] $util_ds_buf_0

  # Create instance: util_reduced_logic_0, and set properties
  set util_reduced_logic_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_reduced_logic:2.0 util_reduced_logic_0 ]
  set_property -dict [ list \
   CONFIG.C_SIZE {2} \
 ] $util_reduced_logic_0

  # Create instance: xdma_0, and set properties
  set xdma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xdma:4.1 xdma_0 ]
  set_property -dict [ list \
   CONFIG.PCIE_BOARD_INTERFACE {pci_express_x1} \
   CONFIG.PF0_DEVICE_ID_mqdma {9031} \
   CONFIG.PF2_DEVICE_ID_mqdma {9031} \
   CONFIG.PF3_DEVICE_ID_mqdma {9031} \
   CONFIG.SYS_RST_N_BOARD_INTERFACE {pcie_perstn} \
   CONFIG.axi_addr_width {64} \
   CONFIG.axi_data_width {64_bit} \
   CONFIG.axi_id_width {2} \
   CONFIG.axilite_master_en {true} \
   CONFIG.axilite_master_size {16} \
   CONFIG.axist_bypass_en {false} \
   CONFIG.axisten_freq {125} \
   CONFIG.cfg_ext_if {false} \
   CONFIG.cfg_mgmt_if {false} \
   CONFIG.coreclk_freq {250} \
   CONFIG.en_gt_selection {true} \
   CONFIG.enable_pcie_debug {False} \
   CONFIG.functional_mode {DMA} \
   CONFIG.mcap_enablement {None} \
   CONFIG.mode_selection {Advanced} \
   CONFIG.pf0_device_id {9031} \
   CONFIG.pf0_interrupt_pin {INTA} \
   CONFIG.pf0_msi_enabled {false} \
   CONFIG.pf0_msix_cap_pba_bir {BAR_1} \
   CONFIG.pf0_msix_cap_pba_offset {00000000} \
   CONFIG.pf0_msix_cap_table_bir {BAR_1} \
   CONFIG.pf0_msix_cap_table_offset {00000000} \
   CONFIG.pf0_msix_cap_table_size {000} \
   CONFIG.pf0_msix_enabled {false} \
   CONFIG.pf0_rbar_cap_bar0 {0x00000000fff0} \
   CONFIG.pf1_msix_cap_table_size {01F} \
   CONFIG.pf1_rbar_cap_bar0 {0x00000000fff0} \
   CONFIG.pf2_rbar_cap_bar0 {0x00000000fff0} \
   CONFIG.pf3_rbar_cap_bar0 {0x00000000fff0} \
   CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
   CONFIG.pl_link_cap_max_link_width {X1} \
   CONFIG.plltype {QPLL1} \
   CONFIG.xdma_axi_intf_mm {AXI_Memory_Mapped} \
   CONFIG.xdma_axilite_slave {false} \
   CONFIG.xdma_num_usr_irq {1} \
   CONFIG.xdma_rnum_chnl {2} \
   CONFIG.xdma_rnum_rids {4} \
   CONFIG.xdma_wnum_chnl {2} \
   CONFIG.xdma_wnum_rids {4} \
 ] $xdma_0

  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]

  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
  set_property -dict [ list \
   CONFIG.CONST_VAL {0} \
 ] $xlconstant_0

  # Create interface connections
  connect_bd_intf_net -intf_net pcie_refclk_1 [get_bd_intf_pins pcie_refclk] [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]
  connect_bd_intf_net -intf_net xdma_0_M_AXI [get_bd_intf_pins M_AXI] [get_bd_intf_pins xdma_0/M_AXI]
  connect_bd_intf_net -intf_net xdma_0_M_AXI_LITE [get_bd_intf_pins M_AXI_LITE] [get_bd_intf_pins xdma_0/M_AXI_LITE]
  connect_bd_intf_net -intf_net xdma_0_pcie_mgt [get_bd_intf_pins pci_express_x1] [get_bd_intf_pins xdma_0/pcie_mgt]

  # Create port connections
  connect_bd_net -net pcie_perstn_1 [get_bd_pins pcie_perstn] [get_bd_pins xdma_0/sys_rst_n]
  connect_bd_net -net pcie_user_lnk_up_vio [get_bd_pins pcie_link_up_vio/probe_in0] [get_bd_pins xdma_0/user_lnk_up] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net util_ds_buf_0_IBUF_DS_ODIV2 [get_bd_pins util_ds_buf_0/IBUF_DS_ODIV2] [get_bd_pins xdma_0/sys_clk]
  connect_bd_net -net util_ds_buf_0_IBUF_OUT [get_bd_pins util_ds_buf_0/IBUF_OUT] [get_bd_pins xdma_0/sys_clk_gt]
  connect_bd_net -net util_reduced_logic_0_Res [get_bd_pins axi_aresetn] [get_bd_pins util_reduced_logic_0/Res]
  connect_bd_net -net xdma_0_axi_aclk [get_bd_pins axi_aclk] [get_bd_pins pcie_link_up_vio/clk] [get_bd_pins xdma_0/axi_aclk]
  connect_bd_net -net xdma_0_axi_aresetn [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins util_reduced_logic_0/Op1] [get_bd_pins xlconcat_0/dout]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins xdma_0/usr_irq_req] [get_bd_pins xlconstant_0/dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: bram
proc create_hier_cell_bram { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_msg_id "BD_TCL-102" "ERROR" "create_hier_cell_bram() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI


  # Create pins
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn

  # Create instance: axi_bram_ctrl_0, and set properties
  set axi_bram_ctrl_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0 ]
  set_property -dict [ list \
   CONFIG.DATA_WIDTH {64} \
   CONFIG.ECC_TYPE {0} \
   CONFIG.SINGLE_PORT_BRAM {1} \
 ] $axi_bram_ctrl_0

  # Create instance: axi_bram_ctrl_0_bram, and set properties
  set axi_bram_ctrl_0_bram [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 axi_bram_ctrl_0_bram ]
  set_property -dict [ list \
   CONFIG.Read_Width_B {64} \
   CONFIG.Write_Width_B {64} \
 ] $axi_bram_ctrl_0_bram

  # Create interface connections
  connect_bd_intf_net -intf_net axi_bram_ctrl_0_BRAM_PORTA [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins axi_bram_ctrl_0_bram/BRAM_PORTA]
  connect_bd_intf_net -intf_net pcie_M_AXI [get_bd_intf_pins S_AXI] [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]

  # Create port connections
  connect_bd_net -net pcie_axi_aclk [get_bd_pins s_axi_aclk] [get_bd_pins axi_bram_ctrl_0/s_axi_aclk]
  connect_bd_net -net pcie_axi_aresetn [get_bd_pins s_axi_aresetn] [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn]

  # Restore current instance
  current_bd_instance $oldCurInst
}


# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set M_AXI_LITE [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_LITE ]
  set_property -dict [ list \
   CONFIG.ADDR_WIDTH {32} \
   CONFIG.DATA_WIDTH {32} \
   CONFIG.FREQ_HZ {125000000} \
   CONFIG.HAS_BURST {0} \
   CONFIG.HAS_CACHE {0} \
   CONFIG.HAS_LOCK {0} \
   CONFIG.HAS_QOS {0} \
   CONFIG.HAS_REGION {0} \
   CONFIG.PROTOCOL {AXI4LITE} \
   ] $M_AXI_LITE

  set axis_rx [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 axis_rx ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {156250000} \
   CONFIG.PHASE {0} \
   ] $axis_rx

  set axis_tx [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 axis_tx ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {156250000} \
   CONFIG.HAS_TKEEP {1} \
   CONFIG.HAS_TLAST {1} \
   CONFIG.HAS_TREADY {1} \
   CONFIG.HAS_TSTRB {0} \
   CONFIG.LAYERED_METADATA {undef} \
   CONFIG.PHASE {0} \
   CONFIG.TDATA_NUM_BYTES {8} \
   CONFIG.TDEST_WIDTH {0} \
   CONFIG.TID_WIDTH {0} \
   CONFIG.TUSER_WIDTH {1} \
   ] $axis_tx

  set pci_express_x1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pci_express_x1 ]

  set pcie_refclk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_refclk ]

  set qsfp0_156mhz [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 qsfp0_156mhz ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {156250000} \
   ] $qsfp0_156mhz

  set qsfp0_1x [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:gt_rtl:1.0 qsfp0_1x ]

  set refclk_300mhz [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 refclk_300mhz ]


  # Create ports
  set pcie_aclk [ create_bd_port -dir O -type clk pcie_aclk ]
  set pcie_aresetn [ create_bd_port -dir O pcie_aresetn ]
  set pcie_perstn [ create_bd_port -dir I -type rst pcie_perstn ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_LOW} \
 ] $pcie_perstn
  set qsfp0_aclk [ create_bd_port -dir O qsfp0_aclk ]
  set qsfp0_aresetn [ create_bd_port -dir O qsfp0_aresetn ]

  # Create instance: axi_register_slice_0, and set properties
  set axi_register_slice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_register_slice:2.1 axi_register_slice_0 ]
  set_property -dict [ list \
   CONFIG.NUM_SLR_CROSSINGS {0} \
   CONFIG.REG_AR {15} \
   CONFIG.REG_AW {15} \
   CONFIG.REG_B {15} \
   CONFIG.REG_R {15} \
   CONFIG.REG_W {15} \
   CONFIG.USE_AUTOPIPELINING {1} \
 ] $axi_register_slice_0

  # Create instance: bram
  create_hier_cell_bram [current_bd_instance .] bram

  # Create instance: pcie
  create_hier_cell_pcie [current_bd_instance .] pcie

  # Create instance: qsfp0
  create_hier_cell_qsfp0 [current_bd_instance .] qsfp0

  # Create interface connections
  connect_bd_intf_net -intf_net axi_register_slice_0_M_AXI [get_bd_intf_ports M_AXI_LITE] [get_bd_intf_pins axi_register_slice_0/M_AXI]
  connect_bd_intf_net -intf_net axis_tx_1 [get_bd_intf_ports axis_tx] [get_bd_intf_pins qsfp0/axis_tx]
  connect_bd_intf_net -intf_net pcie_M_AXI [get_bd_intf_pins bram/S_AXI] [get_bd_intf_pins pcie/M_AXI]
  connect_bd_intf_net -intf_net pcie_M_AXI_LITE [get_bd_intf_pins axi_register_slice_0/S_AXI] [get_bd_intf_pins pcie/M_AXI_LITE]
  connect_bd_intf_net -intf_net pcie_refclk_1 [get_bd_intf_ports pcie_refclk] [get_bd_intf_pins pcie/pcie_refclk]
  connect_bd_intf_net -intf_net qsfp0_156mhz_0_1 [get_bd_intf_ports qsfp0_156mhz] [get_bd_intf_pins qsfp0/qsfp0_156mhz_0]
  connect_bd_intf_net -intf_net qsfp0_axis_rx [get_bd_intf_ports axis_rx] [get_bd_intf_pins qsfp0/axis_rx]
  connect_bd_intf_net -intf_net qsfp0_qsfp0_1x_0 [get_bd_intf_ports qsfp0_1x] [get_bd_intf_pins qsfp0/qsfp0_1x_0]
  connect_bd_intf_net -intf_net refclk_300M_1 [get_bd_intf_ports refclk_300mhz] [get_bd_intf_pins qsfp0/refclk_300mhz]
  connect_bd_intf_net -intf_net xdma_0_pcie_mgt [get_bd_intf_ports pci_express_x1] [get_bd_intf_pins pcie/pci_express_x1]

  # Create port connections
  connect_bd_net -net pcie_axi_aclk [get_bd_ports pcie_aclk] [get_bd_pins axi_register_slice_0/aclk] [get_bd_pins bram/s_axi_aclk] [get_bd_pins pcie/axi_aclk]
  connect_bd_net -net pcie_axi_aresetn [get_bd_ports pcie_aresetn] [get_bd_pins axi_register_slice_0/aresetn] [get_bd_pins bram/s_axi_aresetn] [get_bd_pins pcie/axi_aresetn] [get_bd_pins qsfp0/aresetn_in]
  connect_bd_net -net pcie_perstn_1 [get_bd_ports pcie_perstn] [get_bd_pins pcie/pcie_perstn]
  connect_bd_net -net qsfp0_aclk [get_bd_ports qsfp0_aclk] [get_bd_pins qsfp0/aclk]
  connect_bd_net -net qsfp0_aresetn_out [get_bd_ports qsfp0_aresetn] [get_bd_pins qsfp0/aresetn_out]

  # Create address segments
  create_bd_addr_seg -range 0x01000000 -offset 0x00000000 [get_bd_addr_spaces pcie/xdma_0/M_AXI_LITE] [get_bd_addr_segs M_AXI_LITE/Reg] SEG_M_AXI_LITE_Reg
  create_bd_addr_seg -range 0x00004000 -offset 0xC0000000 [get_bd_addr_spaces pcie/xdma_0/M_AXI] [get_bd_addr_segs bram/axi_bram_ctrl_0/S_AXI/Mem0] SEG_axi_bram_ctrl_0_Mem0


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


