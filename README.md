# Custom Trex for Dev.

The custom trex implementation for developers to test vswitch on a single board.

The original cisco trex traffic generator details can be found in the following
link.

```
    https://trex-tgn.cisco.com/
```
The test setup uses v2.30 trex in the repo itself for the testing. I don't
expect any problem for anyone who wanted to use a different trex version
because the customization is mainly made on the trex configuration.

The test setup only need one server board to run the vswitch(OVS) and trex traffic
generator. The Trex and OVS connected back to back as shown in the following
figure.

```

            Host
            +---------------------------------------------------+
            |                                                   |
            | +----------------------+ +----------------------+ |
            | | +-----------------+  | | +-----------------+  | |
            | | |        OVS-DPDK |  | | |             Trex|  | |
            | | |                 |  | | |                 |  | |
            | | |                 |  | | |                 |  | |
            | | |                 |  | | |                 |  | |
            | | |                 |  | | |                 |  | |
            | | +----|--------|---+  | | +----|--------|---+  | |
            | |      |        |Sock:0| |      |        |Sock:1| |
            | +------|--------|------+ +------|--------|------+ |
            |        |        |               |        |        |
            +--------|--------|---------------|--------|--------+
                     |        +---------------+        |
                     |                                 |
                     +---------------------------------+

```

On a multi socket machine(I am using 2 socket intel server for my testing) ,
run vswitch on one socket(on one numa node) and trex on other numa node(socket).

The test setup is shown in the above figure.

## How to run a test.
This document doesnt cover the platform setup for the testing. The assumption is
the host is ready with all the relevant configuration to run OVS/OVS-DPDK and
Trex.

The following steps explains how a vxlan encap/decap can be tested on OVS-DPDK
using Trex.

*  OVS-DPDK need to modify to whitelist the NICs to make it working. Once the
whitelist support is added in OVS, this diff is not needed anymore.
The PCI-IDs 0000:05:00.0 and 0000:05:00.1 are the PCI IDs of DPDK ports in OVS.

```
$ git diff
diff --git a/lib/dpdk.c b/lib/dpdk.c
index 8da6c3244..e4ae29edb 100644
--- a/lib/dpdk.c
+++ b/lib/dpdk.c
@@ -388,6 +388,12 @@ dpdk_init__(const struct smap *ovs_other_config)
         }
     }

+    argv = grow_argv(&argv, argc, 2);
+    argv[argc++] = xstrdup("-w");
+    argv[argc++] = xasprintf("0000:05:00.0");
+    argv = grow_argv(&argv, argc, 2);
+    argv[argc++] = xstrdup("-w");
+    argv[argc++] = xasprintf("0000:05:00.1");
     argv = grow_argv(&argv, argc, 1);
     argv[argc] = NULL;

```

* Update the `run-traffic-gen.sh` with PCI-ID and directory information.

* Start the trex traffic gen with

```
  ./run-traffic-gen.sh
```

* On another terminal start the OVS-DPDK with the DPDK ports(These ports are
connected back to back with Trex as in the figure.)

* Start the trex-console to initiate the traffic over the ports.

```
  $cd v2.30/

  $./trex-console

```

* Start the UDP traffic for encap.

```
  trex>portattr -a --prom on

  Applying attributes on port(s) [0, 1]:                       [SUCCESS]

  trex>

  trex>   start -f stl/udp_vxlan-encap.py --total -m 15mpps --port 0 --force

  Removing all streams from port(s) [0]:                       [SUCCESS]


  Attaching 1 streams to port(s) [0]:                          [SUCCESS]


  Starting traffic on port(s) [0]:                             [SUCCESS]

  25.99 [ms]

  trex>

```

* Start the VxLAN traffic for decap.

```
  trex>start -f stl/udp_vxlan-decap.py --total -m 15mpps --port 1 --force

  Removing all streams from port(s) [1]:                       [SUCCESS]


  Attaching 1 streams to port(s) [1]:                          [SUCCESS]


  Starting traffic on port(s) [1]:                             [SUCCESS]

  8.81 [ms]

  trex>

```

## Misc

* use vfio-pci driver for Trex and OVS-DPDK. I found issues when using the
igb-uio driver in OVS-DPDK.

* Trex can generate traffic from a pcap file. Refer `stl/udp_vxlan-decap.py` for
how trex generates a vxlan packet from a pcap file.
A useful tool so called `wireedit` can be used to edit any packet to create a
custom packet as user want.
wireedit can be downloaded from the following link

```
    https://wireedit.com/
```

* How I created vxlan traffic profile in the test example?

    Start OVS-DPDK with a tunnel configuration. Send a normal traffic to OVS,
    OVS does the encap and provide the vxlan packet to the user.

    Use TCPDUMP to collect the packet and create a pcap file out of it. OR
    Use standard traffic generators such as IXIA to generate pcap file for
    different traffic profile.

NOTE :: Suggestions and changes are welcome. Please feel free to contribute
with different traffic profile and changes in the scripts to make it running.

