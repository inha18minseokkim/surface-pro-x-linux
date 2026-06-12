# ACPI 덤프 분석 결과 (2026-06-12, 실기기 Surface Pro X SQ2)

덤프 방법: 레지스트리 `HKLM\HARDWARE\ACPI` (DSDT/FADT/RSDT) +
`GetSystemFirmwareTable` Win32 API (나머지). 디컴파일: iasl 20260408.
DSDT: `QCOMM SDM8180` rev 3, 402KB → `DSDT-QCOMM_-SDM8180_-00000003.dsl`

## DMI (#4 quirk 매치 검증)

- Manufacturer: `Microsoft Corporation`
- Model: `Surface Pro X` (SKU `Surface_Pro_X_H_1876`)
- → `patches/0100` 의 DMI_MATCH 문자열과 정확히 일치 ✅

## PCIe (#3, #4)

ACPI PCI 호스트 브리지 ↔ 메인라인 DT 매핑 (32-bit Memory32Fixed 윈도우 기준):

| ACPI | 윈도우 | DT 노드 | 상태 | 자식 장치 |
|------|--------|---------|------|-----------|
| PCI0 (_UID 0) | 0x60200000+0x1DF0000 | pcie0 @0x1c00000 | 활성 | 없음 (빈 포트) |
| PCI1 (_UID 1) | 0x68200000+0x1DF0000 | pcie1 @0x1c10000 | 비활성 | — |
| PCI2 (_UID 2) | 0x70200000+0x1DF0000 | pcie2 @0x1c18000 | 활성 | **NVMe (SK hynix 1c5c:1327)** |
| PCI3 (_UID 3) | 0x40200000+0x1DF0000 | pcie3 @0x1c08000 | 활성 | 없음 (빈 포트) |

- _CRS가 실제로 Memory32Fixed(0x86) consumer 디스크립터 → #4 quirk 분석 실기기 검증 ✅
- 루트포트 PCI ID: 17cb:0109

## 셀룰러 (#7) — 아키텍처 정정

**X24는 PCIe 모뎀이 아니라 SoC 내장 MPSS다.**
- ACPI `QCOM041E` "Snapdragon (TM) X24 LTE Modem" (플랫폼 장치)
- 네트워크 인터페이스는 `QCMS\VEN_QCOM&DEV_0489` (Qualcomm 가상 버스)
- 보조 장치: IPA(QCOM0470), IPC Router(qcipcrouter8180), rmtfs(QCOM0417/048D),
  PIL(QCOM041B), MBB(surfaceprox_mbb), 모뎀 설정(surfaceprox_mcfg)
- → 리눅스 경로: remoteproc(Q6V5_PAS) + QRTR(SMD/glink) + IPA + rmtfs 데몬

## QUP 시리얼 장치 매핑 (#3, #8, #9)

| ACPI 장치 | 베이스 | DT 라벨 | 용도 |
|-----------|--------|---------|------|
| SPI2 (UID 2) | 0x00884000 | `spi1` | **터치스크린** MSHW0235, HID-over-SPI(PNP0C51), 25MHz, CS0, IRQ TLMM 122 |
| SPI4 (UID 4) | 0x0088C000 | `spi3` | 두 번째 SPI 장치 (디지타이저 보조?) |
| I2C2 (UID 2) | 0x00888000 | `i2c2` | 미상 |
| I2C5 (UID 5) | 0x00890000 | `i2c4` | 미상 |
| IC10 (UID 0xA) | (0x00894000?) | `i2c5`? | 미상 |
| UR14 | 0x00A94000 | `uart16` | COM 포트 (디버그 후보) |
| **UR16** | 0x00C94000 | `uart15` | **Surface Aggregator (SSH, MSHW0084), 4,000,000 baud**, RX wake GPIO 30 |
| **UR18** | 0x00C8C000 | `uart13` | **Bluetooth (QCOM0471)** — Flex 5G와 동일 ✅ |

## Surface 전용 ACPI 장치 (MSHW*)

| _HID | 장치 | 의미 |
|------|------|------|
| MSHW0084 | SSH | Surface Serial Hub (= Surface Aggregator, uart15) |
| MSHW0091 | SAN | Surface ACPI Notify |
| MSHW0153 | SHPS | Surface Hot-Plug System |
| MSHW0235 | GTCH | 터치스크린 (HID over SPI) |
| MSHW0040 | MSBT | Surface 버튼 |
| MSHW0115/0125/... | WSID/FINK 등 | 보조 장치 |

## Firmware (확정 파일명, `firmware-staging/`에 추출 완료)

| 용도 | 파일 | 출처 (DriverStore) |
|------|------|--------------------|
| ADSP | qcadsp8180.mbn | surfaceprox_subextadsp |
| CDSP | qccdsp8180.mbn | surfaceprox_subextcdsp |
| 모뎀(MPSS) | qcmpss8180.mbn / qcmpss8180_nm.mbn | surfaceprox_subextmpss |
| 센서(SLPI) | qcslpi8180.mbn | surfaceprox_subextscss |
| GPU zap | qcdxkmsuc8180.mbn | qcdx8180 |
| Venus(video) | qcvss8180.mbn | qcdx8180 |
| Wi-Fi | wlanmdsp.mbn + bdwlan.b* | qcwlan8180 |
| BT | crbtfw21.tlv + crnv21.b* | qcbtfmuart8180 |

## 카메라 (#9)

Spectra 390 ISP: QCOM0428(ISP), QCOM0435(platform), QCOM0436(JPEG),
QCOM04A4(MIPI CSI). 전면(CAMF)/후면(CAMS)/IR(CAMI) — 메인라인 CAMSS 지원 없음, blocked 유지.

## 미해결 (TODO(acpi-pep))

PCIe perst/clkreq/wake GPIO, 백라이트 PWM, lid GPIO, 전원 레일 시퀀스는
PEP 장치(QCOM0419, `surfaceprox_pep`)의 바이너리 테이블 안에 있어 추가 분석 필요.
DSL 파일에서 `\_SB.PEP0` 분석이 다음 단계.
