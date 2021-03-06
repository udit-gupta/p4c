#include <core.p4>
#include <ebpf_model.p4>

@ethernetaddress typedef bit<48> EthernetAddress;
@ipv4address typedef bit<32> IPv4Address;
header Ethernet_h {
    EthernetAddress dstAddr;
    EthernetAddress srcAddr;
    bit<16>         etherType;
}

header IPv4_h {
    bit<4>      version;
    bit<4>      ihl;
    bit<8>      diffserv;
    bit<16>     totalLen;
    bit<16>     identification;
    bit<3>      flags;
    bit<13>     fragOffset;
    bit<8>      ttl;
    bit<8>      protocol;
    bit<16>     hdrChecksum;
    IPv4Address srcAddr;
    IPv4Address dstAddr;
}

struct Headers_t {
    Ethernet_h ethernet;
    IPv4_h     ipv4;
}

parser prs(packet_in p, out Headers_t headers) {
    state start {
        p.extract<Ethernet_h>(headers.ethernet);
        transition select(headers.ethernet.etherType) {
            16w0x800: ip;
            default: reject;
        }
    }
    state ip {
        p.extract<IPv4_h>(headers.ipv4);
        transition accept;
    }
}

control pipe(inout Headers_t headers, out bool pass) {
    bool tmp_0;
    bool hasReturned_0;
    @name("NoAction") action NoAction_0() {
    }
    @name("Reject") action Reject_0(IPv4Address add) {
        pass = false;
        headers.ipv4.srcAddr = add;
    }
    @name("Check_src_ip") table Check_src_ip {
        key = {
            headers.ipv4.srcAddr: exact @name("headers.ipv4.srcAddr") ;
        }
        actions = {
            Reject_0();
            NoAction_0();
        }
        implementation = hash_table(32w1024);
        const default_action = NoAction_0();
    }
    action act() {
        pass = false;
        hasReturned_0 = true;
    }
    action act_0() {
        hasReturned_0 = false;
        pass = true;
    }
    action act_1() {
        tmp_0 = true;
    }
    action act_2() {
        tmp_0 = false;
    }
    action act_3() {
        pass = pass;
    }
    table tbl_act {
        actions = {
            act_0();
        }
        const default_action = act_0();
    }
    table tbl_act_0 {
        actions = {
            act();
        }
        const default_action = act();
    }
    table tbl_act_1 {
        actions = {
            act_1();
        }
        const default_action = act_1();
    }
    table tbl_act_2 {
        actions = {
            act_2();
        }
        const default_action = act_2();
    }
    table tbl_act_3 {
        actions = {
            act_3();
        }
        const default_action = act_3();
    }
    apply {
        tbl_act.apply();
        if (!headers.ipv4.isValid()) {
            tbl_act_0.apply();
        }
        if (!hasReturned_0) {
            if (Check_src_ip.apply().hit) 
                tbl_act_1.apply();
            else 
                tbl_act_2.apply();
            if (tmp_0) 
                tbl_act_3.apply();
        }
    }
}

ebpfFilter<Headers_t>(prs(), pipe()) main;
