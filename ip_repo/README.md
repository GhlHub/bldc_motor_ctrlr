# Vivado IP Repo

This directory contains the packaged-IP flow for `bldc_axi_controller`.

## Purpose

- package the checked-in RTL as a Vivado IP Integrator compatible IP
- keep the packaged IP reproducible from source
- avoid hand-editing generated `component.xml` metadata

## Contents

- `package_bldc_axi_controller_ip.tcl`: batch packaging script
- `bldc_axi_controller_product_guide.htm`: local product-guide stub that points to the GitHub repo
- `bldc_axi_controller_1_0/`: generated packaged IP output after the script is run

## Usage

Run from the repository root:

```sh
vivado -mode batch -source ip_repo/package_bldc_axi_controller_ip.tcl
```

The script:

- stages the RTL into a temporary packaging area
- strips the local `` `include `` lines from the staged top-level copy
- packages the core into `ip_repo/bldc_axi_controller_1_0`
- assigns AXI-Lite, dual clock, and dual reset interfaces for Vivado IP Integrator
- installs a product-guide document entry that points users to the GitHub repo

## Vivado Integration

In a Vivado project, add this repository path as an IP repository:

- repository path: `<repo>/ip_repo`

Then refresh the IP catalog. The packaged core appears as:

- vendor: `ghlhub.com`
- library: `user`
- name: `bldc_axi_controller`
- version: `1.0`

The packaged IP also includes a product-guide entry that redirects to:

- `https://github.com/GhlHub/bldc_motor_ctrlr`
