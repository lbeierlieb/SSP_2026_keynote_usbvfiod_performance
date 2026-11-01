---
theme: default
title: 'usbvfiod: Insights into the Performance Aspects of USB Passthrough'
info: |
  ## usbvfiod: Insights into the Performance Aspects of USB Passthrough — SSP 2026
drawings:
  persist: false
transition: slide-left
mdc: true
layout: cover
---

# usbvfiod: Insights into the Performance Aspects of USB Passthrough

Lukas Beierlieb · Cyberus Technology

SSP 2026 · Würzburg, 11 Nov

---

## `$ whoami`

- Lukas Beierlieb
- 2020–2024: Research assistant at the University of Würzburg
- Frequent SSP attendee
  - 2018: Addressing Shortcomings of Existing DDoS Protection Software Using Software-Defined Networking 
  - 2019: Towards Testing the Performance Influence of Hypervisor Hypercall Interface Behavior
  - 2021: Measuring the Performance Impact of Branching Instructions
  - 2022: Comparison Between Polling- and Interrupt-based Packet Processing Regarding Performance
  - 2023: Comparing the Performance of Data Processing Implementations
- Ongoing: PhD student with Samuel Kounev

---

## `$ whoami`

- Since 2024: Software Engineer at Cyberus Technology
  - Virtualization
  - Nix/NixOS
  - Rust

---

## Cyberus Technology

- Founded 2017
- 36 employees
- Headquarters in Dresden
- Areas of expertise
  - KVM + cloud-hypervisor: The only BSI-accredited hypervisor for VS-NfD and NATO RESTRICTED
  - NixOS LTS
  - Hardware-in-the-loop testing
  - Virtualization in edge/embedded devices

<img src="/img/cyberus.svg" class="mx-auto max-h-115" />

---
class: compact
---

## <a href="https://github.com/cyberus-technology/usbvfiod">github:cyberus-technology/usbvfiod</a>

<img src="/img/usbvfiod_repo.png" class="mx-auto max-h-90" />

<img src="/img/usbvfiod-funding.png" class="mx-auto max-h-25" />

---

## usbvfiod

<img src="/diagrams/usbvfiod-basic.svg" class="mx-auto h-100" />

---

## usbvfiod Context: USB Passthrough with QEMU

- QEMU has a built-in USB-controller emulation
- QEMU can emulate connected USB devices
- The controller emulation can pass through real USB devices

<img src="/diagrams/qemu-usb-native.svg" class="mx-auto h-80" />

---

## usbvfiod Context: cloud-hypervisor and USB Devices

- cloud-hypervisor targets VMs running cloud workloads
  - virtio devices for network, storage, ...
  - no video output
  - no USB controller
- Missing features are a feature
  - smaller code base
  - device-emulation code is attack surface

---

## usbvfiod Context: cloud-hypervisor Outside The Cloud

- Security benefits of cloud-hypervisor's design are also attractive to fields outside the cloud

<figure class="mx-auto text-center">
  <img src="/img/secunet_edge.png" class="mx-auto max-h-70" />
  <figcaption class="text-sm text-gray-500 mt-1">
    Source: <a href="https://www.secunet.com/loesungen/secunet-edge">secunet.com/loesungen/secunet-edge</a>
  </figcaption>
</figure>

---

## usbvfiod Context: cloud-hypervisor Inside secunet edge

- Workloads might require USB devices
  - Serial/FTDI connection to sensors
  - Webcam
  - Passport scanner
- PCI Passthrough of USB controller possible, but not ideal


<img src="/diagrams/chv-pci-passthrough.svg" class="mx-auto h-65" />

---

## usbvfiod: USB Passthrough for cloud-hypervisor 

<img src="/diagrams/usbvfiod-chv.svg" class="mx-auto h-100" />

---

## USB-Passthrough Performance: Measurement Setup

<img src="/diagrams/usbvfiod-benchmark-setup.svg" class="mx-auto h-75" />

Run the measurements yourself (<a href="https://github.com/lbeierlieb/usbvfiod-performance-testing">GitHub repo</a>):

```bash
nix run github:lbeierlieb/usbvfiod-performance-testing
```

---

## USB-Passthrough Performance

<img src="/img/usbvfiod-performance.png" class="mx-auto max-h-100" />

---

## Read from USB Storage: Device View

<img src="/diagrams/usb-stick-read-device.svg" class="mx-auto h-40 mb-10" />

<div class="grid grid-cols-[auto_1fr] gap-x-6 gap-y-2">
  <b>OUT</b><span>31-byte CBW: read LBA 0, 100 blocks</span>
  <b>IN</b><span>51200 bytes of data</span>
  <b>IN</b><span>13-byte CSW: all good, everything transferred</span>
</div>

---

## Read from USB Storage: Driver View

OUT request:

<img src="/diagrams/usb-stick-read-driver-out.svg" class="mx-auto h-90" />

---

## Read from USB Storage: Driver View

IN request:

<img src="/diagrams/usb-stick-read-driver-in.svg" class="mx-auto h-90" />

---

## Read from USB Storage: usbvfiod's Initial Approach

Translate each TRB into a transfer to the real USB device:

<img src="/diagrams/usb-stick-read-usbvfiod-trb.svg" class="mx-auto h-90 mt-8" />

---

## Performance Jump 1: <a href="https://github.com/cyberus-technology/usbvfiod/pull/246">#246</a>

<img src="/img/usbvfiod-PR246.png" class="mx-auto max-h-100" />

---

## usbvfiod: Batching TRBs to TDs

<img src="/diagrams/usb-stick-read-usbvfiod-td.svg" class="mx-auto h-100" />

---

## Performance Jump 1: <a href="https://github.com/cyberus-technology/usbvfiod/pull/246">#246</a>

<img src="/img/performance_jump_1.png" class="mx-auto max-h-100" />

---

## Performance Jump 2: <a href="https://github.com/cyberus-technology/usbvfiod/pull/327">#327</a>

<img src="/img/usbvfiod-PR327.png" class="mx-auto max-h-100" />

---

## Default Bulk DMA Implementations

```rust
/// **Note:** The default implementation is not efficient and
/// should not be used where performance matters.
fn read_bulk(&self, offset: u64, data: &mut [u8]) {
    for (cur, value) in data.iter_mut().enumerate() {
        let cur_u64: u64 = cur.try_into().expect("Failed to convert to u64");

        let read_value = self.read(Request::new(
            offset.overflowing_add(cur_u64).0,
            RequestSize::Size1,
        ));

        *value = read_value as u8;
    }
}
```

- Single-byte accesses
- Bounds check for every access

---

## Optimized Bulk DMA Implementations

- `memcpy`? Undefined behavior!

- Check bounds once
- Use atomic 8-byte reads and writes
- Potentially smaller accesses at the start and end (alignment)

---

## Performance Jump 2: <a href="https://github.com/cyberus-technology/usbvfiod/pull/327">#327</a>

<img src="/img/performance_jump_2.png" class="mx-auto max-h-100" />

---
layout: center
---

<h1 class="text-6xl font-bold">Thank you for your attention!</h1>

<img src="/img/cyberus.svg" class="absolute bottom-10 left-1/2 -translate-x-1/2 h-20" />
