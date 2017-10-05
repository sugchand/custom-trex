#!/bin/bash -x
TREX_DIR=/home/sugeshch/repo/trex/v2.30
DPDK_DIR=/home/sugeshch/repo/dpdk_stable
DPDK_BINDTOOL=$DPDK_DIR/usertools/dpdk-devbind.py
# Ports for Trex traffic generator to use.
PORT1_PCI=0000:81:00.0
PORT2_PCI=0000:81:00.1
TREX_CFGFILE=/etc/trex_cfg.yaml
KERNEL_NIC_DRV=ixgbe

#Ports OVS is connected to.
OVS_PCI1=0000:05:00.0
OVS_PCI2=0000:05:00.1

if [[ $EUID -ne 0 ]]; then
    echo "The script must be run as a root user"
    exit 1
fi

echo "Insert igb_uio modules"
modprobe uio
#modprobe vfio-pci

# Bind the ports to kernel first and set it up before bind it to Trex.
$DPDK_BINDTOOL --bind $KERNEL_NIC_DRV $PORT1_PCI $PORT2_PCI
port1=$($DPDK_BINDTOOL --status |grep $PORT1_PCI | sed -n 's/.* if=\([a-zA-Z0-9_]\+\).*/\1/p')
port2=$($DPDK_BINDTOOL --status |grep $PORT2_PCI | sed -n 's/.* if=\([a-zA-Z0-9_]\+\).*/\1/p')
ip link set dev $port1 up
ip link set dev $port2 up

echo "Bind OVS test ports to kernel first..."
$DPDK_BINDTOOL --bind $KERNEL_NIC_DRV $OVS_PCI1 $OVS_PCI2
port1=$($DPDK_BINDTOOL --status |grep $OVS_PCI1 | sed -n 's/.* if=\([a-zA-Z0-9_]\+\).*/\1/p')
port2=$($DPDK_BINDTOOL --status |grep $OVS_PCI2 | sed -n 's/.* if=\([a-zA-Z0-9_]\+\).*/\1/p')
ip link set dev $port1 up
ip link set dev $port2 up

#rmmod igb_uio
#(cd $TREX_DIR/ko/src ; make)
#insmod $TREX_DIR/ko/src/igb_uio.ko 
#insmod $DPDK_DIR/x86_64-native-linuxapp-gcc/kmod/igb_uio.ko
#$DPDK_BINDTOOL --bind igb_uio $PORT1_PCI $PORT2_PCI

echo "Creating trex cfg file $TREX_CFGFILE using given config"
cat >$TREX_CFGFILE <<EOL
- port_limit      : 2
  version         : 2

# Use specific prefix trex
  prefix : setup1 #optional

  limit_memory : 6144
#List of interfaces. Change to suit your setup. Use ./dpdk_setup_ports.py -s to see available options
  interfaces    : ["$PORT1_PCI","$PORT2_PCI"]
#  port_info       :  # Port IPs. Change to suit your needs. In case of loopback, you can leave as is.
#          - ip         : 1.1.1.1
#            default_gw : 2.2.2.2
#          - ip         : 2.2.2.2
#            default_gw : 1.1.1.1
  platform :
        master_thread_id : 14
        latency_thread_id : 15
        dual_if :
        - socket : 1
          threads : [17, 18, 19, 20, 21, 22, 23, 24]
EOL

echo "starting trex traffic generator"
cd $TREX_DIR
#./t-rex-64 -i -c 1
./t-rex-64 -i -c 8 --no-watchdog
#./t-rex-64 -f cap2/dns.yaml -d 200 -l 1000 -c 1 -v 3
