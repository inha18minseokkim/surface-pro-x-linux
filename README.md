# Surface Pro X (SQ2 / sc8180xp) Linux Porting

Microsoft Surface Pro X (SQ2)에서 Ubuntu ARM64를 구동하기 위한 커널 포팅 프로젝트.
셀룰러 모뎀(Snapdragon X24 LTE) 지원을 포함하는 것이 최종 목표다.

## 하드웨어

| 항목 | 내용 | 드라이버 경로 |
|------|------|---------------|
| SoC | Qualcomm SQ2 (sc8180xp, Snapdragon 8cx Gen 2) | `arch/arm64`, `drivers/soc/qcom` |
| GPU | Adreno 680 계열 (MS 브랜딩: Adreno 690) | `drivers/gpu/drm/msm` (freedreno) |
| Wi-Fi/BT | Qualcomm WCN3998 | `drivers/net/wireless/ath/ath10k` (SNOC) |
| 셀룰러 | Snapdragon X24 LTE (SDX24, PCIe) | `drivers/bus/mhi`, `drivers/net/wwan` |
| 스토리지 | NVMe (PCIe) | `drivers/nvme` + qcom PCIe quirk |
| 키보드 | Surface Type Cover | `drivers/hid`, Surface Aggregator |

## 핵심 제약

sc8180xp(Gen 2)는 **메인라인 커널에 DTS가 없다.**
- sc8180x (Gen 1, SQ1): 커널 6.0+ 메인라인 지원 → 베이스로 사용
- sc8280xp (Gen 3): 커널 6.5+ 지원 → 최신 qcom 드라이버 패턴 참고용

전략: **sc8180x DTS를 fork하여 sc8180xp 차이점(GPU 클럭, PMIC)을 반영**하고,
Surface 전용 보드 DTS를 작성한다. ACPI 부팅 경로(커널 5.14/5.15에서 성공 사례 있음)는
fallback으로 유지한다.

## 레포 구조

```
configs/    커널 config 프래그먼트
dts/        sc8180xp.dtsi / sc8180xp-microsoft-surface-pro-x.dts 작업 공간
patches/    메인라인/linux-surface 커널 대비 패치
scripts/    빌드 환경 세팅, 소스 fetch, 커널 빌드 스크립트
firmware/   firmware blob 확보 절차 (blob 자체는 커밋하지 않음)
docs/       전략 및 컴포넌트별 상세 문서
```

## 작업 현황 (이슈 트래킹)

| 이슈 | 컴포넌트 | 상태 |
|------|----------|------|
| #1 | 전체 개요 / 프로젝트 기반 | ✅ 완료 (이 레포) |
| #2 | 부팅 환경 (UEFI/GRUB/Secure Boot) | 🔧 문서·스크립트 완료, 실기기 검증 대기 |
| #3 | sc8180xp Device Tree | 🔧 v2 — 실기기 ACPI 덤프 반영 (`dts/acpi-dumps/FINDINGS.md`), PEP GPIO만 미해결 |
| #4 | NVMe PCIe quirk | 🔧 패치 완료, 실기기에서 consumer-window 구조 확인됨. NVMe는 **pcie2** |
| #5 | GPU (Adreno 680, freedreno) | zap firmware 추출 완료 (`qcdxkmsuc8180.mbn`) |
| #6 | Wi-Fi/BT (ath10k SNOC — 이슈의 ath11k는 오기) | firmware 추출 완료 (wlanmdsp/bdwlan, BT tlv) |
| #7 | 셀룰러 모뎀 (X24 = **내장 MPSS**, PCIe 아님) | 🔧 remoteproc+QRTR+IPA 경로 확정, firmware 추출 완료 |
| #8 | Type Cover (Surface Aggregator, **uart15** 4Mbaud) | SSH=MSHW0084 확인, SAM DT 바인딩 패치 필요 |
| #9 | 카메라/터치스크린/센서 | 터치=HID over SPI(spi1, IRQ 122) 확정. 카메라 Spectra 390 blocked |
| #10 | 빌드 환경 가이드 | ✅ scripts/ + configs/ 로 구현 |

## 빠른 시작 (x86_64 호스트에서 크로스 빌드)

```bash
./scripts/setup-build-env.sh   # 툴체인·의존성 설치
./scripts/fetch-sources.sh     # 커널·펌웨어·참고 레포 클론
./scripts/build-kernel.sh      # ARM64 커널 + DTB 빌드
```

## 참고 레포지터리

- [linux-surface/surface-pro-x](https://github.com/linux-surface/surface-pro-x) — 공식 트래킹
- [linux-surface/linux-surface](https://github.com/linux-surface/linux-surface) — 커널 패치
- [denysvitali/surface-pro-x-linux](https://github.com/denysvitali/surface-pro-x-linux) — spx-5.16 패치
- [linux-surface/aarch64-firmware](https://github.com/linux-surface/aarch64-firmware) — firmware
- [aarch64-laptops/build](https://github.com/aarch64-laptops/build) — sc8180x 빌드 참고
- [jhovold/linux](https://github.com/jhovold/linux) — Qualcomm laptop mainline 작업 (sc8280xp 패턴)
