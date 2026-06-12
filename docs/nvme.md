# NVMe PCIe (Issue #4)

## 증상

ACPI 부팅 시 `lspci`에는 NVMe가 보이지만 `/dev/nvme0`이 안 생긴다.
dmesg에 `BAR 0: failed to assign [mem size 0x00004000 64bit]` 류의 메시지.

## 근본 원인 (2026-06 메인라인 소스로 검증)

- Qualcomm WoA 펌웨어는 호스트 브리지 윈도우를 PNP0A03 `_CRS`의
  **Memory32Fixed "consumer"** 디스크립터로 기술한다 (producer가 아님).
- 커밋 `8fd4391ee717` ("arm64: PCI: Exclude ACPI consumer resources from
  host bridge windows", 2016)부터 커널은 non-window 리소스를 전부 제거한다.
- 현재 이 로직은 `drivers/pci/pci-acpi.c`의
  `pci_acpi_root_prepare_resources()`에 있으며, **2026년 메인라인에도
  여전히 무조건 제거한다** — Shawn Guo의 2023 quirk 제안은 머지되지 않았다.
- 결과: 브리지에 메모리 윈도우가 없음 → 하위 장치 BAR 할당 실패 → NVMe 미동작.

이슈 본문의 "커널 6.2+에서 수정됨"은 **부정확** — 소스 확인 결과 머지된 quirk 없음.

## 경로별 영향

| 부팅 경로 | 영향 | 조치 |
|-----------|------|------|
| Device Tree (#3) | 없음 — pcie-qcom 드라이버가 DT의 ranges 사용 | DTS의 `&pcie0` 노드로 충분 |
| ACPI (bring-up) | NVMe·Wi-Fi·WWAN 등 PCIe 전 장치 영향 | `patches/0100-*.patch` 적용 |

## 패치

`patches/0100-PCI-ACPI-keep-consumer-mem-resources-as-windows-on-W.patch`
— DMI 매치(`Microsoft Corporation` / `Surface Pro X`) 시 consumer 메모리
디스크립터를 제거하지 않고 `IORESOURCE_WINDOW`로 승격.

## 검증 (실기기)

```bash
lspci                      # NVMe 컨트롤러 표시 여부
ls /dev/nvme*              # 장치 파일 생성 여부
dmesg | grep -iE "nvme|BAR"  # BAR 할당 실패 메시지 사라졌는지
```

## Fallback

- `pcie_aspm=off` 커널 파라미터 — ASPM 관련 불안정 시도용이며 위 BAR 문제와는
  별개. BAR 할당이 실패하는 한 이것만으로는 NVMe가 살아나지 않는다.
- 패치 적용이 어려우면 USB rootfs로 운용 (#2의 기본 전략).
