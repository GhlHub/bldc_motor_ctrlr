set script_dir [file normalize [file dirname [info script]]]
set repo_root  [file normalize [file join $script_dir ..]]

set staging_dir [file join $script_dir .staging_src]
set build_dir   [file join $script_dir .build]
set ip_root     [file join $script_dir bldc_axi_controller_1_0]
set product_guide_src [file join $script_dir bldc_axi_controller_product_guide.htm]

proc choose_packaging_part {} {
    set preferred_parts [list \
        xc7s25csga225-1 \
        xc7a35tcsg324-1 \
        xc7z010clg400-1 \
    ]

    foreach part_name $preferred_parts {
        set parts [get_parts -quiet $part_name]
        if {[llength $parts] > 0} {
            return [lindex $parts 0]
        }
    }

    set fallback_parts [get_parts -quiet xc7*]
    if {[llength $fallback_parts] > 0} {
        return [lindex $fallback_parts 0]
    }

    error "No suitable Xilinx 7-series part found for IP packaging."
}

proc recreate_dir {path} {
    if {[file exists $path]} {
        file delete -force $path
    }
    file mkdir $path
}

proc write_staged_source {src_path dst_path strip_include_lines} {
    set in_fh [open $src_path r]
    set data [read $in_fh]
    close $in_fh

    if {$strip_include_lines} {
        set filtered_lines [list]
        foreach line [split $data "\n"] {
            if {[string match {`include "rtl/*} $line]} {
                continue
            }
            lappend filtered_lines $line
        }
        set data [join $filtered_lines "\n"]
    }

    set out_fh [open $dst_path w]
    puts -nonewline $out_fh $data
    close $out_fh
}

proc add_signal_clock_interface {core if_name physical_port associated_busif associated_reset freq_hz} {
    set busif [ipx::add_bus_interface $if_name $core]
    set_property abstraction_type_vlnv xilinx.com:signal:clock_rtl:1.0 $busif
    set_property bus_type_vlnv xilinx.com:signal:clock:1.0 $busif

    set portmap [ipx::add_port_map CLK $busif]
    set_property physical_name $physical_port $portmap

    if {$associated_busif ne ""} {
        set busif_param [ipx::add_bus_parameter ASSOCIATED_BUSIF $busif]
        set_property value $associated_busif $busif_param
    }

    if {$associated_reset ne ""} {
        set reset_param [ipx::add_bus_parameter ASSOCIATED_RESET $busif]
        set_property value $associated_reset $reset_param
    }

    if {$freq_hz ne ""} {
        set freq_param [ipx::add_bus_parameter FREQ_HZ $busif]
        set_property value $freq_hz $freq_param
    }
}

proc add_signal_reset_interface {core if_name physical_port polarity} {
    set busif [ipx::add_bus_interface $if_name $core]
    set_property abstraction_type_vlnv xilinx.com:signal:reset_rtl:1.0 $busif
    set_property bus_type_vlnv xilinx.com:signal:reset:1.0 $busif

    set portmap [ipx::add_port_map RST $busif]
    set_property physical_name $physical_port $portmap

    set pol_param [ipx::add_bus_parameter POLARITY $busif]
    set_property value $polarity $pol_param
}

recreate_dir $staging_dir
recreate_dir $build_dir
recreate_dir $ip_root

foreach rtl_file [list \
    bldc_axi_controller.sv \
    bldc_axi_slave.sv \
    bldc_motor_ctrl_domain.sv \
    bldc_motor_core.sv \
] {
    set src_path [file join $repo_root rtl $rtl_file]
    set dst_path [file join $staging_dir $rtl_file]
    write_staged_source $src_path $dst_path [expr {$rtl_file eq "bldc_axi_controller.sv"}]
}

set part_name [choose_packaging_part]
create_project -force bldc_axi_controller_ip $build_dir -part $part_name

add_files -norecurse [list \
    [file join $staging_dir bldc_axi_slave.sv] \
    [file join $staging_dir bldc_motor_core.sv] \
    [file join $staging_dir bldc_motor_ctrl_domain.sv] \
    [file join $staging_dir bldc_axi_controller.sv] \
]
set_property top bldc_axi_controller [current_fileset]
update_compile_order -fileset sources_1

ipx::package_project -root_dir $ip_root -vendor ghlhub.com -library user -taxonomy /UserIP -import_files

set core [ipx::current_core]
set_property name bldc_axi_controller $core
set_property display_name {BLDC AXI Controller} $core
set_property description {BLDC motor controller with AXI-Lite register interface and dual-clock motor-control core.} $core
set_property vendor_display_name {GhlHub} $core
set_property version 1.0 $core
set_property core_revision 1 $core

catch {ipx::remove_bus_interface CLK_AXI $core}
catch {ipx::remove_bus_interface CLK_MOTOR $core}
catch {ipx::remove_bus_interface RST_AXI_N $core}
catch {ipx::remove_bus_interface RST_MOTOR_N $core}

add_signal_reset_interface $core RST_AXI_N rst_axi_n ACTIVE_LOW
add_signal_reset_interface $core RST_MOTOR_N rst_motor_n ACTIVE_LOW
add_signal_clock_interface $core CLK_AXI clk_axi s_axil rst_axi_n 60000000
add_signal_clock_interface $core CLK_MOTOR clk_motor "" rst_motor_n 100000000

file mkdir [file join $ip_root doc]
file copy -force $product_guide_src [file join $ip_root doc [file tail $product_guide_src]]

set product_guide_fg [ipx::get_file_groups -quiet xilinx_product_guide -of $core]
if {$product_guide_fg eq ""} {
    set product_guide_fg [ipx::add_file_group xilinx_product_guide $core]
}
ipx::add_file [file join doc [file tail $product_guide_src]] $product_guide_fg

ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity -quiet $core
ipx::save_core $core

close_project

if {[file exists $staging_dir]} {
    file delete -force $staging_dir
}

if {[file exists $build_dir]} {
    file delete -force $build_dir
}

puts "Packaged IP written to: $ip_root"
