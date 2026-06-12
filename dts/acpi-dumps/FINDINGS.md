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

## PEP 테이블 분석 (1차)

PEP 블록은 DSL에서 사람이 읽을 수 있는 Package 구조다
(`"TLMMGPIO"/"PMICGPIO"/"PMICVREGVOTE"/"CLOCK"` 엔트리).

### PCIe 전원/GPIO (라인 51194~54440 부근, 디바이스별 블록)

| 블록 | 발견 항목 | 해석 |
|------|-----------|------|
| \_SB.PCI1 | TLMMGPIO 0xB0(176) | pcie1 핀 (미사용 포트) |
| \_SB.PCI2 (**NVMe**) | **PMICGPIO: PMIC#2, GPIO 10**, digital output (ON=1/OFF=0) | SSD 전원 스위치 또는 PERST — TLMM 핀 없음 |
| \_SB.PCI2 | **PMICVREGVOTE: LDO3_C @0x124F80(≈1.2V), LDO5_E @0xD6D80(≈0.88V)** | pcie2_phy 레일 = `vreg_l3c_1p2` + `vreg_l5e_0p88` **확정** ✅ |
| \_SB.PCI3 | TLMMGPIO 0xB3(179) | pcie3 핀 (Flex 5G의 clkreq 179와 일치) |

### 디스플레이 블록

TLMMGPIO 0x0A(10) = eDP HPD (DTS의 `edp_hot` gpio10과 일치 ✅), 0x82(130),
PMICGPIO(PMIC#2, GPIO 9, digital input).

## 미해결

백라이트 PWM 채널, lid GPIO, PMIC 인덱스↔라벨 매핑(#2 = pmc8180c 추정),
reserved-memory 실주소(리눅스 부팅 후 efi memmap으로 확정).
