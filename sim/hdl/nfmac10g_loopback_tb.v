//
// Copyright (c) 2016 University of Cambridge All rights reserved.
//
// Author: Marco Forconesi
//
// This software was developed with the support of 
// Prof. Gustavo Sutter and Prof. Sergio Lopez-Buedo and
// University of Cambridge Computer Laboratory NetFPGA team.
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed to NetFPGA C.I.C. (NetFPGA) under one or more
// contributor license agreements.  See the NOTICE file distributed with this
// work for additional information regarding copyright ownership.  NetFPGA
// licenses this file to you under the NetFPGA Hardware-Software License,
// Version 1.0 (the "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@

//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 100ps
//`default_nettype none

module nfmac10g_loopback_tb (

    );

    // localparam
    localparam CLK_PERIOD = 6.4;
    localparam RST_ASSERTED = CLK_PERIOD * 20;
    localparam TX_AXIS_ARESETN_ASSERTED = CLK_PERIOD * 20;
    localparam RX_AXIS_ARESETN_ASSERTED = CLK_PERIOD * 20;
    localparam TX_DCM_LOCKED_ASSERTED = CLK_PERIOD * 20;
    localparam RX_DCM_LOCKED_ASSERTED = CLK_PERIOD * 20;

    //-------------------------------------------------------
    // Local clk
    //-------------------------------------------------------
    reg                      clk;
    reg                      rst;
    reg                      tx_dcm_locked;
    reg                      rx_dcm_locked;
    reg                      tx_axis_aresetn;
    reg                      rx_axis_aresetn;

    //-------------------------------------------------------
    // Local nfmac10g
    //-------------------------------------------------------
    // AXIs Tx
    wire         [63:0]      tx_axis_tdata;
    wire         [7:0]       tx_axis_tkeep;
    wire                     tx_axis_tvalid;
    wire                     tx_axis_tready;
    wire                     tx_axis_tlast;
    wire         [0:0]       tx_axis_tuser;
    // AXIs Rx
    wire         [63:0]      rx_axis_tdata;
    wire         [7:0]       rx_axis_tkeep;
    wire                     rx_axis_tvalid;
    wire                     rx_axis_tlast;
    wire         [0:0]       rx_axis_tuser;
    // XGMII
    wire         [63:0]      xgmii_txd;
    wire         [7:0]       xgmii_txc;
    wire         [63:0]      xgmii_rxd;
    wire         [7:0]       xgmii_rxc;

    //-------------------------------------------------------
    // Local stim_axis_tx
    //-------------------------------------------------------
    wire                     input_pkts_done;
    wire         [63:0]      aborted_pkts;
    wire         [63:0]      pushed_pkts;

    //-------------------------------------------------------
    // MY FIFO SIGNALS
    //-------------------------------------------------------  
    wire         [63:0]      fifo_oc_tdata;
    wire         [7:0]       fifo_oc_tkeep;
    wire                     fifo_oc_tvalid;
//    wire                     fifo_oc_tready;
    wire                     fifo_oc_tlast;
    //wire         [0:0]       fifo_oc_tuser;
     //-------------------------------------------------------
    // PARSER SIGNALS
    //-------------------------------------------------------   
    
    wire        [2**4-1:0]   ov_prt_bitmap;
    reg         [334-1:0]    din_a;
    reg         [4-1:0]      addr_a;
    reg                      write_enable;
    wire        [4-1:0]      this_prt_addr;
//    reg         [8-1:0]      metadata;
    
//    -------------------------------------------------------
    //-------------------------------------------------------
    // Local xgmii_connect
    //-------------------------------------------------------
    wire         [63:0]      xgmii_pkts_detected;
    wire         [63:0]      xgmii_corrupted_pkts;

    //-------------------------------------------------------
    // nfmac10g
    //-------------------------------------------------------
    nfmac10g nfmac10g_mod (
        // Clks and resets
        .tx_clk0(clk),                                         // I
        .rx_clk0(clk),                                         // I
        .reset(rst),                                           // I
        .tx_dcm_locked(tx_dcm_locked),                         // I
        .rx_dcm_locked(rx_dcm_locked),                         // I
        // Flow control
        .tx_ifg_delay(8'b0),                                   // I
        .pause_val(16'b0),                                     // I
        .pause_req(1'b0),                                      // I
        // Conf vectors
        .tx_configuration_vector({69'b0,1'b1,8'b0,2'b10}),     // I
        .rx_configuration_vector({78'b0,2'b10}),               // I
        // XGMII
        .xgmii_txd(xgmii_txd),                                 // O [63:0]
        .xgmii_txc(xgmii_txc),                                 // O [7:0]
        .xgmii_rxd(xgmii_rxd),                                 // I [63:0]
        .xgmii_rxc(xgmii_rxc),                                 // I [7:0]
        // Tx AXIS
        .tx_axis_aresetn(tx_axis_aresetn),                     // I
        .tx_axis_tdata(tx_axis_tdata),                         // I [63:0]
        .tx_axis_tkeep(tx_axis_tkeep),                         // I [7:0]
        .tx_axis_tvalid(tx_axis_tvalid),                       // I
        .tx_axis_tready(tx_axis_tready),                       // O
        .tx_axis_tlast(tx_axis_tlast),                         // I
        .tx_axis_tuser(tx_axis_tuser),                         // I [0:0]
        // Rx AXIS
        .rx_axis_aresetn(rx_axis_aresetn),                     // I
        .rx_axis_tdata(rx_axis_tdata),                         // O [63:0]
        .rx_axis_tkeep(rx_axis_tkeep),                         // O [7:0]
        .rx_axis_tvalid(rx_axis_tvalid),                       // O
        .rx_axis_tlast(rx_axis_tlast),                         // O
        .rx_axis_tuser(rx_axis_tuser)                          // O [0:0]
        );

    //-------------------------------------------------------
    // stim_axis_tx
    //-------------------------------------------------------
    stim_axis_tx stim_axis_tx_mod (
        // Clks and resets
        .clk(clk),                                             // I
        .reset(rst),                                           // I
        .tx_dcm_locked(tx_dcm_locked),                         // I
        .rx_dcm_locked(rx_dcm_locked),                         // I
        // Tx AXIS
        .tx_axis_aresetn(tx_axis_aresetn),                     // I
        .tx_axis_tdata(tx_axis_tdata),                         // O [63:0]
        .tx_axis_tkeep(tx_axis_tkeep),                         // O [7:0]
        .tx_axis_tvalid(tx_axis_tvalid),                       // O
        .tx_axis_tready(tx_axis_tready),                       // I
        .tx_axis_tlast(tx_axis_tlast),                         // O
        .tx_axis_tuser(tx_axis_tuser),                         // O [0:0]
        // Sim info
        .input_pkts_done(input_pkts_done),                     // O
        .aborted_pkts(aborted_pkts),                           // O [63:0]
        .pushed_pkts(pushed_pkts)                              // O [63:0]
        );

    //-------------------------------------------------------
    // xgmii_connect
    //-------------------------------------------------------
    xgmii_connect xgmii_connect_mod (
        // Clks and resets
        .clk(clk),                                             // I
        .reset(rst),                                           // I
        .tx_dcm_locked(tx_dcm_locked),                         // I
        .rx_dcm_locked(rx_dcm_locked),                         // I
        // XGMII
        .xgmii_txd(xgmii_txd),                                 // I [63:0]
        .xgmii_txc(xgmii_txc),                                 // I [7:0]
        .xgmii_rxd(xgmii_rxd),                                 // O [63:0]
        .xgmii_rxc(xgmii_rxc),                                 // O [7:0]
        // Sim info
        .pkts_detected(xgmii_pkts_detected),                   // O [63:0]
        .corrupted_pkts(xgmii_corrupted_pkts)                  // O [63:0]
        );
    //-------------------------------------------------------
    // MY FIFO
    //-------------------------------------------------------
//    entity AXI_stream is
//  generic (
//    reset_polarity : std_logic := '0';   --! reset polartity
//    data_width     : natural   := 128;   --! width of the data bus in bits
//    depth          : natural   := 512);  --! fifo depth 

//  port (
//    clk               : in  std_logic;  -- axi clk
//    reset_n           : in  std_logic;  -- asynchronous reset (active low)
//    -- master interface
//    stream_out_tready : in  std_logic;  --! slave ready
//    stream_out_tlast  : out std_logic;  --! TLAST
//    stream_out_tvalid : out std_logic;  --! indicate the transfer is valid
//    stream_out_tdata  : out std_logic_vector(data_width - 1 downto 0);  --! master data
//    stream_out_tkeep  : out std_logic_vector(data_width/8 - 1 downto 0);
//    -- slave interface
//    stream_in_tvalid  : in  std_logic;  --! master output is valid
//    stream_in_tlast   : in  std_logic;  --! TLAST
//    stream_in_tready  : out std_logic;  --! ready to receive
//    stream_in_tdata   : in  std_logic_vector(data_width - 1 downto 0);  --! slave data
//    stream_in_tkeep   : in  std_logic_vector(data_width/8 - 1 downto 0)
//    );
//end entity;
//    AXI_stream fifo(
//    .clk(clk),
//    .reset_n(~rst), 
    
//    .stream_out_tready(1'b1),
//    .stream_out_tlast(fifo_oc_tlast),
//    .stream_out_tvalid(fifo_oc_tvalid),
//    .stream_out_tdata(fifo_oc_tdata),
//    .stream_out_tkeep(fifo_oc_tkeep),
    
//    .stream_in_tvalid(rx_axis_tvalid),
//    .stream_in_tlast(rx_axis_tlast),
//    .stream_in_tready(rx_axis_tready),
//    .stream_in_tdata(rx_axis_tdata),
//    .stream_in_tkeep(rx_axis_tkeep)
//    );

//-------------------------------------------------------
//     Parser + axi
//-------------------------------------------------------   
    parser_top parser(
        .ib_clk(clk),
        .ib_rst(rst),
        .iv_din_a(din_a),
        .iv_addr_a(addr_a),
        .ib_write_enable(write_enable),
//        -- iv_data                 : in std_logic_vector(NUM_INPUT_PKT_BITS-1 downto 0);
//        .iv_metadata(metadata),
        
        .ib_start_frame(ib_start_frame),
        .ib_end_frame(rx_axis_tlast),
        
        .ov_this_prt_addr(this_prt_addr),
//        ov_PHV_data0            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
//        ov_PHV_data1            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
//        ov_PHV_data2            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
//        ov_PHV_data3            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
//        ov_PHV_data4            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
//        ov_PHV_data5            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
//        ov_PHV_data6            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
//        ov_PHV_data7            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
//        ov_PHV_data8            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
//        ov_PHV_data9            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
//        ov_PHV_data10           : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
//        ov_PHV_data11           : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
//        ov_PHV_data12           : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
//        ov_PHV_data13           : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
//        ov_PHV_data14           : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
//        ov_PHV_data15           : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
      .ov_prt_bitmap(ov_prt_bitmap),

//    ---------------------------------AXI INTERFACES---------------------------------    
//    -- clk               : in  std_logic;  -- axi clk
//    -- reset_n           : in  std_logic;  -- asynchronous reset (active low)
//    -- master interface
    .stream_out_tready(1'b1),
    .stream_out_tlast(fifo_oc_tlast),
    .stream_out_tvalid(fifo_oc_tvalid),
    .stream_out_tdata(fifo_oc_tdata),
    .stream_out_tkeep(fifo_oc_tkeep),
 
//     .stream_out_tready(1'b1),
//    .stream_out_tlast(tx_axis_tlast),
//    .stream_out_tvalid(tx_axis_tvalid),
//    .stream_out_tdata(tx_axis_tdata),
//    .stream_out_tkeep(tx_axis_tkeep),
       
//        .tx_axis_aresetn(tx_axis_aresetn),                     // I
//        .tx_axis_tdata(tx_axis_tdata),                         // I [63:0]
//        .tx_axis_tkeep(tx_axis_tkeep),                         // I [7:0]
//        .tx_axis_tvalid(tx_axis_tvalid),                       // I
//        .tx_axis_tready(tx_axis_tready),                       // O
//        .tx_axis_tlast(tx_axis_tlast),                         // I
//        .tx_axis_tuser(tx_axis_tuser),                         // I [0:0]
        
//    -- slave interface
    .stream_in_tvalid(rx_axis_tvalid),
    .stream_in_tlast(rx_axis_tlast),
    .stream_in_tready(rx_axis_tready),
    .stream_in_tdata(rx_axis_tdata),
    .stream_in_tkeep(rx_axis_tkeep)
   );
///////////////////start/////////////////////
    edge_detector ed(
    .ib_clk(clk),
    .ib_rst(rst),
    .signal_in(rx_axis_tvalid),
    .signal_out(ib_start_frame)
    );
    //-------------------------------------------------------
    // out_chk_rx
    //-------------------------------------------------------
    out_chk_rx out_chk_rx_mod (
        // Clks and resets
        .clk(clk),                                             // I
        .reset(rst),                                           // I
        .tx_dcm_locked(tx_dcm_locked),                         // I
        .rx_dcm_locked(rx_dcm_locked),                         // I
        // Tx AXIS
//        .rx_axis_aresetn(tx_axis_aresetn),                     // I
//        .rx_axis_tdata(rx_axis_tdata),                         // I [63:0]
//        .rx_axis_tkeep(rx_axis_tkeep),                         // I [7:0]
//        .rx_axis_tvalid(rx_axis_tvalid),                       // I
//        .rx_axis_tlast(rx_axis_tlast),                         // I
//        .rx_axis_tuser(rx_axis_tuser),                         // I [0:0]

        .rx_axis_aresetn(tx_axis_aresetn),                     // I
        .rx_axis_tdata(fifo_oc_tdata),                         // I [63:0]
        .rx_axis_tkeep(fifo_oc_tkeep),                         // I [7:0]
        .rx_axis_tvalid(fifo_oc_tvalid),                       // I
        .rx_axis_tlast(fifo_oc_tlast),                         // I
        .rx_axis_tuser(rx_axis_tuser),                         // I [0:0]
                
//            .stream_out_tready(1'b1),
//    .stream_out_tlast(fifo_oc_tlast),
//    .stream_out_tvalid(fifo_oc_tvalid),
//    .stream_out_tdata(fifo_oc_tdata),
//    .stream_out_tkeep(fifo_oc_tkeep),
    
        // Sim info, stim_axis_tx
        .input_pkts_done(input_pkts_done),                     // I
        .aborted_pkts(aborted_pkts),                           // I [63:0]
        .pushed_pkts(pushed_pkts),                             // I [63:0]
        // Sim info, xgmii_connect
        .pkts_detected(xgmii_pkts_detected),                   // I [63:0]
        .corrupted_pkts(xgmii_corrupted_pkts)                  // I [63:0]
        );

    //-------------------------------------------------------
    // Test
    //-------------------------------------------------------
    initial begin
        clk = 0;
        rst = 1;
        tx_dcm_locked = 0;
        rx_dcm_locked = 0;
        tx_axis_aresetn = 0;
        rx_axis_aresetn = 0;

//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////       
   //----------------------FILL THE MEMORY------------------------
        #15;
        write_enable <=1'b1;
//        -------------------------------------------------------------------------------------------------
//        -----------------------------------------FILL THE MEMORY-----------------------------------------
//        --#1--ethernet
        addr_a<=4'b0001;
//                    --keyvalue&nextprotocolids--  -shift-mask-   -KEYLOC- -HDRLRN- -ISBYTE-  -theDoubleprt-IDcon1,2,3,4- -nxtIsDouble- -IamDouble- 
        din_a<={334'b0000100000000000011010000001000000000011100100010000000000101000100001000111010010000110110111010111000011111111000000000000110000000000000011101001000110000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000};
//        din_a<={100'h08006_81003_91002_88474_86dd7, 4'h0, 8'hFF, 16'h000c, 16'h000e , 1'b1 ,4'h2, 4'h3,4'h0,4'h0,4'h0, 1'b1,1'b0, 167'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000};
//                  -------------100bits-----------------------44bits-------------1bit---------------20bits----------------------2bits-------     -----------------mem_data of the first connection--------------------------------------------------------------------------------------------------------------------------
//                  -------------------------------------------------------------------167-----------------------------------------------------------
        #10;
        
//        --#2--vlan
        addr_a<=4'b0010;
        din_a<={100'h81003_FFFF0_FFFF0_FFFF0_FFFF0, 44'h0FF00020004, 1'b1,   20'h23000,      2'b01,   100'h0800686dd7FFFF0FFFF0FFFF0, 44'h0FF00020004, 1'b1,     20'hFFFFF,  2'b00};
        #10;
        
//        --#3--vlan
        addr_a<=4'b0011;
        din_a<={100'h08006_86dd7_FFFF0_FFFF0_FFFF0, 44'h0FF00020004, 1'b1,   20'hFFFFF,    2'b00,   167'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000};
        #10; 
         
//        --#4--mpls--does not work for packet 2&3
        addr_a<=4'b0100;
        din_a<={100'h00005_FFFF0_FFFF0_FFFF0_FFFF0, 44'h10700020004, 1'b0,   20'hFFFFF,     2'b00,   167'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000};
        #10;

//        --#5--mpls--does not work for packet 2&3
        addr_a<=4'b0101;
        din_a<={100'hFFFF0_FFFF0_FFFF0_FFFF0_FFFF0, 44'h10700020004, 1'b0,   20'hFFFFF,   2'b00,      167'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000};
        #10;  

//        --#6--ipv4
        addr_a<=4'b0110;
        din_a<={100'h0100C_1100A_0600B_FFFF0_FFFF0, 44'h0FF00090020, 1'b0,   20'hFFFFF,    2'b00,      167'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000};
        #10;
                              
//        --#7--ipv6
        addr_a<=4'b0111;
        din_a<={100'h00008_3A00C_1100A_0600B_FFFF0, 44'h0FF00060028, 1'b0,   20'hFFFFF,    2'b00,      167'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000};
        #10;
        
//        --#8--ext1
        addr_a<=4'b1000;
        din_a<={100'h1100A_0600B_3A00C_3C009_FFFF0, 44'h0FF00000008, 1'b0,   20'hFFFFF,    2'b00,      167'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000};
        #10;
        
//        --#9--ext2
        addr_a<=4'b1001;
        din_a<={100'h1100A_0600B_3A00C_FFFF0_FFFF0, 44'h0FF00000008, 1'b0,   20'hFFFFF,    2'b00,      167'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000};
        #10;
        write_enable <=1'b0;
//        metadata<=8'b00000000;
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////   

    end
    
    always
        #(CLK_PERIOD/2) clk = ~clk;

    always
        #RST_ASSERTED rst = 0;

    always
        #TX_DCM_LOCKED_ASSERTED tx_dcm_locked = 1;

    always
        #RX_DCM_LOCKED_ASSERTED rx_dcm_locked = 1;

    always
        #TX_AXIS_ARESETN_ASSERTED tx_axis_aresetn = 1;

    always
        #RX_AXIS_ARESETN_ASSERTED rx_axis_aresetn = 1;

endmodule // nfmac10g_loopback_tb

//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////





//     //-------------------------------------------------------
    // Parser + axi
    //-------------------------------------------------------   
    
//    parser_top parser(
//        .ib_clk(clk),
//        .ib_rst(rst),
//        .iv_din_a(din_a),
//        .iv_addr_a(addr_a),
//        .ib_write_enable(write_enable),
////        -- iv_data                 : in std_logic_vector(NUM_INPUT_PKT_BITS-1 downto 0);
//        .iv_metadata(iv_metadata),
//        .ov_this_prt_addr(this_prt_addr),
////        ov_PHV_data0            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
////        ov_PHV_data1            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
////        ov_PHV_data2            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
////        ov_PHV_data3            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
////        ov_PHV_data4            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
////        ov_PHV_data5            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
////        ov_PHV_data6            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
////        ov_PHV_data7            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
////        ov_PHV_data8            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
////        ov_PHV_data9            : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
////        ov_PHV_data10           : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
////        ov_PHV_data11           : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
////        ov_PHV_data12           : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
////        ov_PHV_data13           : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
////        ov_PHV_data14           : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
////        ov_PHV_data15           : out std_logic_vector(PHV_MEM_WIDTH-1 downto 0);
//      .ov_prt_bitmap(ov_prt_bitmap),

////    ---------------------------------AXI INTERFACES---------------------------------    
////    -- clk               : in  std_logic;  -- axi clk
////    -- reset_n           : in  std_logic;  -- asynchronous reset (active low)
////    -- master interface
//    .stream_out_tready(1'b1),
//    .stream_out_tlast(fifo_oc_tlast),
//    .stream_out_tvalid(fifo_oc_tvalid),
//    .stream_out_tdata(fifo_oc_tdata),
//    .stream_out_tkeep(fifo_oc_tkeep),
////    -- slave interface
//    .stream_in_tvalid(rx_axis_tvalid),
//    .stream_in_tlast(rx_axis_tlast),
//    .stream_in_tready(rx_axis_tready),
//    .stream_in_tdata(rx_axis_tdata),
//    .stream_in_tkeep(rx_axis_tkeep)
//   );
   //-------------------------------------------------------
    // Start signal
    //-------------------------------------------------------
//  entity edge_detector is
//    port (
//        signal_in : in  std_logic;
//        signal_out : out std_logic
//    );
//end entity;
//    edge_detector ed(
//    .ib_clk(clk),
//    .ib_rst(rst),
//    .signal_in(rx_axis_tvalid),
//    .signal_last_in(rx_axis_tlast),
//    .signal_out(iv_metadata)
//    );


   //-------------------------------------------------------
    // Start signal
    //-------------------------------------------------------
//  entity edge_detector is
//    port (
//        signal_in : in  std_logic;
//        signal_out : out std_logic
//    );
//end entity;
//    edge_detector ed(
//    .ib_clk(clk),
//    .ib_rst(rst),
//    .signal_in(rx_axis_tvalid),
//    .signal_last_in(rx_axis_tlast),
//    .signal_out(iv_metadata)
//    );
    //-------------------------------------------------------