# AYANEO Pocket S 2K

## Identity

- Archneo identifier: `ayaneo-pocket-s-2k`
- SoC/platform: Qualcomm SM8550
- Bring-up priority: deferred after the initial remote tests
- Current Archneo status: direct-root image assembly passed, but Archneo has
  not reached a confirmed console; the profile remains buildable while local
  Pocket EVO bring-up is active

This page describes the original AYANEO Pocket S with the 2K display. It does
not describe the AYANEO Pocket S2, which uses SM8650.

## ROCKNIX hardware source

The initial hardware description will be derived from ROCKNIX's
`qcs8550-ayaneo-pockets2k.dts`, which includes the shared
`qcs8550-ayaneo-pocket-common.dtsi` platform description.

At the revision recorded below, the device tree describes:

- a dual-DSI `ayaneo,wt0600-2k` display panel;
- SGM3804 panel regulators;
- a SY7758 backlight controller; and
- a Goodix GT911 touchscreen with a 1440 by 2560 logical size.

Source:
[ROCKNIX Pocket S 2K device tree](https://github.com/ROCKNIX/distribution/blob/13e18947d2d41b17015f5df18405adefc4dfb2f5/projects/ROCKNIX/devices/SM8550/linux/dts/qcom/qcs8550-ayaneo-pockets2k.dts)

This revision remains the S 2K profile baseline. The build scripts record it
with the Linux source checksum and selected DTB in each artifact manifest.

## Bring-up record

The following evidence is required before changing the status from `untested`:

| Area | Status | Evidence |
| --- | --- | --- |
| Kernel/DTB compile | Passed | GitHub Actions run [`33063572182`](https://github.com/mrdidit/Archneo/actions/runs/33063572182), commit `c51aabe928b731370450c5f096c1fedd16311c29` |
| Android boot wrapper | Passed (dummy ramdisk only) | Artifact `archneo-ayaneo-pocket-s-2k-c51aabe928b731370450c5f096c1fedd16311c29` |
| Complete image assembly | Passed | Latest tested diagnostic image: GitHub Actions run [`33193171460`](https://github.com/mrdidit/Archneo/actions/runs/33193171460), commit `ce5478e7e1519afe1135210205ce0aa23340b42f` |
| External boot reference | Reported booting | Collaborator reports Pocknix SM8550 boots after selecting Pocket S 2K in ABL; exact image and ABL versions still required |
| ABL prerequisite | Not recorded | Working ROCKNIX-ABL version required |
| ROCKNIX baseline | Not captured | Pending |
| ABL boot | Payload selected; kernel entry not proven | First removable-media test appeared to load `/KERNEL`; exact ABL version still required |
| Root/userspace | Failed to produce evidence | The built-in-initramfs diagnostic image also left `/var/log/journal` and `/var/lib/archneo` empty after forced power-off |
| Diagnostic console | Failed | No visible console; UART not captured |
| Display/backlight | Black screen | Whether the panel backlight was electrically on was not recorded |
| Touchscreen | Not tested | Pending |
| Storage/USB | Not tested | Pending |
| Controls/rumble | Startup vibration observed | Source of vibration not yet attributed to ABL, firmware, or Linux |
| GPU | Not tested | Pending |
| Audio | Archneo not tested | Pocknix reference reportedly has no audio; Pocket S 2K DTS card model is `SM8550-APS` |
| Wi-Fi/Bluetooth | Not tested | Pending |
| Battery/charging/fan | Not tested | Pending |
| Shutdown/suspend | Not tested | Pending |

Test logs must identify the image build, source revisions, device hardware
revision, test procedure, and observed result.

### First hardware attempt

- Date: 2026-08-27
- Image build: GitHub Actions run `33089290964`, commit `787ef0d`
- Write method: balenaEtcher to removable media
- Verified media state: GPT plus `ROCKNIX`, `ARCHNEO_ROOT`, and
  `ARCHNEO_HOME`; expected filesystem UUIDs matched the build profile
- Observation: ABL appeared to load the payload, the display showed no usable
  output, the device remained running, and shutdown required a hard power-off
- Post-test evidence: no persistent journal files and no Archneo first-boot
  marker; `/home` expansion had not completed
- Unknowns still to record: hardware revision, ROCKNIX-ABL version, whether
  the backlight was lit, and a known-good ROCKNIX comparison on the same unit

This result did not establish kernel entry. The follow-up moved Archneo's
archive into Linux and returned the Android ramdisk to ROCKNIX's literal
`dummy`.

### Built-in-initramfs diagnostic attempt

- Date reported: 2026-08-28
- Image build: GitHub Actions run `33193171460`, commit `ce5478e7`
- Verified payload SHA-256:
  `551c256fc8a83f6547bd8a77b7ed8dfcbde399d46267ed8388774860ab385d82`
- FAT manifest: built-in initramfs and DRM debugging command line confirmed
- Observation: the display remains black, with no visible console or kernel
  panic output; a vibration occurs during startup
- Post-test evidence: no systemd journal and no file below
  `/var/lib/archneo`; the systemd diagnostic capture service did not run
- Interpretation: the display path remains the primary visible symptom, but
  the evidence cannot yet distinguish kernel entry, initramfs execution, root
  mounting, or display initialization

The follow-up diagnostic image and evidence-recovery procedure are documented
in [Pocket S 2K black-screen diagnostics](../diagnostics/pocket-s-2k-display.md).

### Direct-root ABL-parity attempt

- Date prepared: 2026-08-28
- Trigger: collaborator report that the Pocknix SM8550 family image can select
  and boot Pocket S 2K in ROCKNIX-ABL, although audio does not work
- Boot envelope: GPT boot name `system`, FAT label `ROCKNIX`, `KERNEL.md5`,
  complete pinned ROCKNIX SM8550 DTB set, valid empty Android ramdisk, and
  direct ext4 `root=PARTUUID=…`
- Userspace target: `multi-user.target`; `tty1` asks separately for the `root`
  and `deck` passwords before the login prompt
- Networking: NetworkManager plus `wpa_supplicant`, installed from the official
  rolling Arch Linux ARM repositories with no connection preconfigured
- Unchanged: installed ABL, ext4 `/` and `/home`, filesystem-UUID `fstab`, and
  Archneo's own userspace/package policy
- CI result: GitHub Actions run
  [`33206667662`](https://github.com/mrdidit/Archneo/actions/runs/33206667662)
  completed the direct-root payload, image, verification, and artifact upload
  at commit `a935356b941f3b92b91347262ff39bb2677b6152`
- Hardware status: deferred; this direct-root image was not locally tested
